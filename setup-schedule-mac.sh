#!/bin/bash
# Registers the hourly automation jobs as launchd user agents (macOS counterpart of
# setup-schedule.ps1).
#
#   Register:  ./setup-schedule-mac.sh            profile refresh only
#              ./setup-schedule-mac.sh --naukri   refresh + LIVE Naukri auto-apply
#              ./setup-schedule-mac.sh --all      refresh + LIVE Naukri and Wellfound auto-apply
#   Status:    ./setup-schedule-mac.sh --status
#   Remove:    ./setup-schedule-mac.sh --remove
#
# No sudo needed: these are agents in ~/Library/LaunchAgents and run as you.
#
# Why an Aqua agent rather than a daemon: Chrome cannot run headless here (Naukri's
# Akamai bot-check blocks headless browsers), so every run needs a logged-in desktop
# session to draw into. LimitLoadToSessionType=Aqua ties the jobs to that session.
#
# launchd never starts a second copy of a job while one is still running, which is
# the macOS equivalent of Task Scheduler's -MultipleInstances IgnoreNew. A Mac that
# is asleep at the top of the hour runs the missed interval once on wake.

set -u

repo="$(cd "$(dirname "$0")" && pwd)"
agents="$HOME/Library/LaunchAgents"
domain="gui/$(id -u)"

# label|interval seconds|arguments
#
# --when-away: a run does nothing unless the screen is locked or the Mac has been idle
# 10+ minutes (AWAY_IDLE_MINUTES), because Chrome cannot be kept fully off screen on
# macOS. The refresh checks every 15 minutes so it catches short breaks, and itself
# refreshes at most once an hour.
refresh_def="com.naukri-update.profile-refresh|900|naukri-profile-refresh.js --when-away"
naukri_def="com.naukri-update.naukri-apply|3600|auto-apply-runner.js naukri --live --scheduled --when-away"
wellfound_def="com.naukri-update.wellfound-apply|3600|auto-apply-runner.js wellfound --live --scheduled --when-away"
apply_defs=("$naukri_def" "$wellfound_def")
all_defs=("$refresh_def" "${apply_defs[@]}")

mode="register"
defs=("$refresh_def")
case "${1:-}" in
  --all)    defs=("${all_defs[@]}") ;;
  --naukri) defs=("$refresh_def" "$naukri_def") ;;
  --status) mode="status" ;;
  --remove) mode="remove" ;;
  "")       ;;
  *) echo "Unknown option: $1 (use --naukri, --all, --status or --remove)"; exit 1 ;;
esac

if [ "$mode" = "status" ]; then
  for d in "${all_defs[@]}"; do
    label="${d%%|*}"
    if ! launchctl print "$domain/$label" >/dev/null 2>&1; then
      printf "%-36s NOT REGISTERED\n" "$label"; continue
    fi
    info="$(launchctl print "$domain/$label")"
    state="$(awk -F' = ' '/^\tstate = /{print $2; exit}' <<<"$info")"
    last="$(awk -F' = ' '/^\tlast exit code = /{print $2; exit}' <<<"$info")"
    every="$(cut -d'|' -f2 <<<"$d")"
    printf "%-36s %-12s every=%sm last-exit=%s\n" "$label" "${state:-?}" "$((every / 60))" "${last:-never run}"
  done
  exit 0
fi

if [ "$mode" = "remove" ]; then
  for d in "${all_defs[@]}"; do
    label="${d%%|*}"
    plist="$agents/$label.plist"
    if [ -f "$plist" ] || launchctl print "$domain/$label" >/dev/null 2>&1; then
      launchctl bootout "$domain/$label" 2>/dev/null
      rm -f "$plist"
      echo "removed: $label"
    else
      echo "not present: $label"
    fi
  done
  exit 0
fi

# launchd starts jobs with a bare PATH, so pin the node this shell resolves.
node_bin="$(command -v node || true)"
if [ -z "$node_bin" ]; then
  echo "node not found on PATH - install Node.js 18+ first"; exit 1
fi

mkdir -p "$agents"
ok=0; bad=0
for d in "${defs[@]}"; do
  label="${d%%|*}"
  interval="$(cut -d'|' -f2 <<<"$d")"
  read -r -a args <<<"$(cut -d'|' -f3- <<<"$d")"
  plist="$agents/$label.plist"
  log="$repo/launchd-${label#com.naukri-update.}.log"

  {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$node_bin</string>
EOF
    for a in "${args[@]}"; do echo "    <string>$a</string>"; done
    cat <<EOF
  </array>
  <key>WorkingDirectory</key><string>$repo</string>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$(dirname "$node_bin"):/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>$interval</integer>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$log</string>
  <key>StandardErrorPath</key><string>$log</string>
</dict>
</plist>
EOF
  } >"$plist"

  launchctl bootout "$domain/$label" 2>/dev/null
  if ! plutil -lint -s "$plist"; then
    echo "  FAIL $label  (generated plist is invalid: $plist)"; bad=$((bad + 1)); continue
  fi
  launchctl bootstrap "$domain" "$plist" 2>/dev/null

  # Verify rather than assume (same lesson as setup-schedule.ps1).
  if launchctl print "$domain/$label" >/dev/null 2>&1; then
    echo "  OK   $label  (every $((interval / 60))m when away, and at login; log: ${log#$repo/})"; ok=$((ok + 1))
  else
    echo "  FAIL $label  (bootstrap reported no error but the job is not loaded)"; bad=$((bad + 1))
  fi
done

echo
echo "$ok registered, $bad failed."
if [ "$bad" -eq 0 ]; then
  echo "Verify:      ./setup-schedule-mac.sh --status"
  echo "Run one now: launchctl kickstart $domain/com.naukri-update.profile-refresh"
  echo "Remove all:  ./setup-schedule-mac.sh --remove"
else
  echo "Some jobs did not register - nothing will run on a schedule until that is fixed."
  exit 1
fi
