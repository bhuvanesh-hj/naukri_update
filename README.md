# Auto-Apply

Job-application automation for **Naukri**, **Wellfound** and **Indeed**, plus an
hourly **Naukri profile refresh** that keeps your profile at the top of recruiter
searches. Everything runs locally in Chrome via Playwright, and every personal
detail lives in `.env` — nothing is hard-coded in the scripts.

| What | Entry point |
|---|---|
| Keep the Naukri profile "recently updated" (hourly) | `node naukri-profile-refresh.js` |
| Auto-apply on Naukri | `node auto-apply-runner.js naukri` |
| Auto-apply on Wellfound | `node auto-apply-runner.js wellfound` |
| Auto-apply on Indeed | `node auto-apply-runner.js indeed` |

The apply runners start in **DRY RUN** mode — they fill everything but never press
Send — so you can watch them work before adding `--live`.

## Quick reference (macOS)

Run everything from the repo folder. Windows users can use the same `node` commands.
For scheduling on Windows, see the Task Scheduler sections below.

**Setup and checks**

| Command | What it does |
|---|---|
| `npm install` | Install dependencies (once) |
| `cp .env.example .env` | Create your config, then fill it in (once) |
| `node check-setup.js` | Checks the setup and prints pass/fail. Read-only: opens Chrome but changes nothing |
| `node check-setup.js --quick` | Same checks without opening a browser |

**Profile refresh**

| Command | What it does |
|---|---|
| `node naukri-profile-refresh.js login` | One-time Google sign-in in a visible window; approve 2-step verification if asked |
| `node naukri-profile-refresh.js` | Refresh now. Chrome hides after about 1 second |
| `node naukri-profile-refresh.js --show` | Refresh with the window left on screen, to watch it or debug |
| `node naukri-profile-refresh.js --minimize` | Refresh with the window minimised to the Dock |
| `node naukri-profile-refresh.js --force-cv` | Refresh and re-upload the resume even if it was uploaded today (use after swapping the PDF) |
| `node naukri-profile-refresh.js --when-away` | Refresh only if the screen is locked or the Mac has been idle 10+ min, at most once an hour. The scheduled job uses this |

**Hourly schedule (launchd)**

| Command | What it does |
|---|---|
| `./setup-schedule-mac.sh` | Register the refresh job: checks every 15 min, refreshes only while you're away |
| `./setup-schedule-mac.sh --naukri` | Refresh plus **live** Naukri auto-apply: hourly, 09:00–23:00, only while you're away |
| `./setup-schedule-mac.sh --all` | Also register the **live** Naukri and Wellfound auto-apply jobs |
| `./setup-schedule-mac.sh --status` | Show which jobs are registered and their last exit code |
| `launchctl kickstart gui/$(id -u)/com.naukri-update.profile-refresh` | Trigger the scheduled job now (still applies the away check) |
| `./setup-schedule-mac.sh --remove` | Remove all scheduled jobs |

**Windows and logs**

| Command | What it does |
|---|---|
| `node show-windows.js` | Bring hidden automation Chrome windows back and pause auto-hiding |
| `node show-windows.js --hide` | Hide them again and resume auto-hiding |
| `tail -20 launchd-profile-refresh.log` | Scheduled-job output, including `skip: ...` lines |
| `tail -20 naukri-refresh.log` | History of refreshes that actually ran (`OK:` / `ERROR:`) |
| `open naukri-refresh-error-*.png` | Screenshot of what the browser saw when a run failed |
| `rm .last-refresh` | Clear the once-an-hour limit so the next `--when-away` run can refresh |

**Auto-apply**

| Command | What it does |
|---|---|
| `cp -R .naukri-chrome-profile .naukri-apply-profile && rm -f .naukri-apply-profile/Singleton*` | Give auto-apply a logged-in Naukri session by copying the refresh's. Use this instead of `naukri login`, which Google often blocks. Repeat if apply runs show as logged out (`rm -rf .naukri-apply-profile` first) |
| `node auto-apply-runner.js naukri --plan` | Show the searches and numbers a run would use, then exit. Opens no browser |
| `node auto-apply-runner.js naukri --show` | Dry run with the window visible: fills everything, never submits |
| `node auto-apply-runner.js naukri --live --show` | Apply for real and watch it |
| `node auto-apply-runner.js naukri --live --max 5` | Apply for real, at most 5 this run |
| `node auto-apply-runner.js naukri --live --max 30 --daily 40` | Raise today's cap for this run too (the per-run number never exceeds what's left of the day) |
| `rm apply-state-naukri.json` | Reset today's application count |
| `open applications.csv` | Everything submitted, plus every "Apply on company site" job and its link |

**Daily checks**

```bash
tail -5 launchd-naukri-apply.log        # what today's scheduled apply runs did
tail -3 naukri-refresh.log              # last profile refreshes
node auto-apply-runner.js naukri --plan # today's count, and which search runs next (→)
./setup-schedule-mac.sh --status        # are both scheduled jobs registered?
```

**Settings in `.env`:**

| Setting | Default | What it does |
|---|---|---|
| `NAUKRI_ROLES` | java backend developer, java full stack developer, full stack developer, node js developer, backend developer, java developer, spring boot developer, software engineer | Searches run, in this order |
| `NAUKRI_LOCATION` | `bangalore` | City filter for every search. Leave blank for anywhere |
| `NAUKRI_EXPERIENCE` | `3` | Years of experience the searches filter by |
| `NAUKRI_PER_RUN` | `10` | Applications per run (`--max` overrides it) |
| `NAUKRI_DAILY_CAP` | `20` | Applications per day across all runs (`--daily` overrides it) |
| `NAUKRI_PER_SEARCH` | `2` | Applications from one search before moving to the next, so a run covers every role. `0` stays on a search until it runs out of jobs |
| `AWAY_IDLE_MINUTES` | `10` | Idle minutes that count as "away" for scheduled runs |
| `REMOTE_ANSWER` / `RELOCATE_ANSWER` | open to both | Text answers to remote-work and relocation questions |
| `RELOCATE_OK` | `yes` | `no` picks the "No" option on Yes/No relocation questions about other cities (Bengaluru ones still get Yes) |

**`applications.csv`** gets a row for each job a live run handles, with the date and
time. For Naukri jobs, Company, CTC/Salary (when the listing shows one) and Skills come
from the job's search card. Job Description holds its experience range, location and
posting date, for example `Exp 3-6 Yrs · Bengaluru · posted Today`.

- **Naukri one-click applies:** Verified is `one-click applied`. (On Wellfound it's
  `verified`, `missing` or `unknown`, checked against Wellfound's applied list.)
- **"Apply on company site" jobs:** Job Link is the Naukri listing and Company Site Link
  is the employer page it led to. Verified says what happened: `external: applied`,
  `external: skipped — needs an account … — apply manually`, or `external: not attempted
  (run ended) — apply manually`. Filter on "apply manually" for the jobs to apply to by
  hand.
- **My Status** is left blank for you to fill in, for example "applied" or "not
  interested".

**When rows are written:** one at a time, while the run is going, not all at the end.

- A Naukri one-click apply is written straight after it's submitted. On Wellfound it's
  written 10–40 seconds later, after the applied-list check.
- A company-site job is written as soon as the run has tried it (applied, skipped or
  failed).
- Company-site jobs found but not reached yet are written when the run ends, or straight
  away if you stop it with Ctrl+C.

So `applications.csv` is always up to date to within a minute or so. Each Naukri listing
is written only once, even if it turns up again in a later search or on a later day. Dry
runs write nothing to the CSV.

**Working through the CSV by hand:** open it in Excel, filter Verified for "apply
manually", apply, and set My Status. Save it as **CSV UTF-8**, and only while no apply
run is going (no second Chrome icon in the Dock). A run appends rows to the file, and
Excel saving over it at the same moment would lose those rows.

**Testing the away check:** run `sleep 20; node naukri-profile-refresh.js --when-away`
and lock the screen straight away with **Ctrl + Cmd + Q**. After you unlock, the output
should show `Running while away (screen locked)` followed by an `OK:` line.

## How the automation works

**What runs on its own (launchd).** After `./setup-schedule-mac.sh`, only the
**profile refresh** runs automatically. `--all` also schedules live Naukri and
Wellfound auto-apply (`--naukri` for Naukri only). Every scheduled run first checks whether you're away (screen
locked or idle `AWAY_IDLE_MINUTES`) and exits quietly if you aren't.

| Job | How often | What one run does |
|---|---|---|
| Profile refresh | Checks every 15 min, refreshes at most hourly | Opens your Naukri profile and cycles a trailing dot on the resume headline (".", "..", none), which counts as a profile update. Reloads to confirm the save, and re-uploads the resume if its "Uploaded on" date isn't today. About 1–2 minutes |
| Naukri auto-apply (`--all`) | Hourly, 09:00–23:00 only, after a random 0–14 min delay | Applies to up to `NAUKRI_PER_RUN` jobs, stopping at `NAUKRI_DAILY_CAP` for the day. Up to 100 minutes |
| Wellfound auto-apply (`--all`) | Same | Same, for Wellfound (up to 50/day) |

**Inside one Naukri apply run** (`auto-apply-runner.js` + `naukri-auto-apply.js`):

1. Opens Chrome with `.naukri-apply-profile` and loads the first search URL, built from
   `NAUKRI_ROLES` + `NAUKRI_LOCATION` + `NAUKRI_EXPERIENCE` (check with `--plan`).
2. Goes through the job cards. It skips titles that don't match the keyword list in
   `naukri-auto-apply.js`, titles on the blocklist (lead, manager, QA, DevOps, frontend,
   .NET, …), and jobs you've already applied to.
3. **One-click "Apply" jobs:** clicks Apply. If Naukri's chatbot asks screening
   questions, it answers from your `.env` (notice period, CTC, years, location) and from
   resume-based answers about your skills. Questions it has no answer for go to Gemini
   (if `GEMINI_KEY` is set) or get a short generic answer. Afterwards it checks that the
   job appears in your Naukri applied list.
4. **"Apply on company site" jobs** (most Naukri listings): Node follows the link to the
   employer's site (`external-apply.js`). On a plain form, such as Greenhouse or Lever,
   it fills in your details, attaches the resume and submits. If the site needs an
   account (Workday and others) or there's no form, it skips the job. Either way, the
   link goes in `applications.csv`.
5. Waits 45–120 seconds between applications. After `NAUKRI_PER_SEARCH` applications it
   moves to the next search. A search with no jobs left is dropped. The run ends when it
   reaches its target, the daily cap, 100 minutes, or runs out of jobs. The next run
   starts at the search where this one stopped, so every role gets its turn over the day.
   `--plan` marks that search with `→`.
6. If the browser gets stuck (no progress for 3 cycles), it closes and reopens Chrome,
   up to 8 times per run.

**Dry run vs live.** Without `--live`, everything happens except the final click: no
application is sent, nothing is counted against the daily cap, and nothing is written
to the CSV.

**Files a run reads and writes:** `.env` (your details and settings), `Resume/…pdf`
(attached to applications), `apply-state-naukri.json` (today's count),
`applications.csv` (results). Error screenshots are saved as `blocked-step-naukri.png`.

**Git remotes:** `origin` is your fork and `upstream` is the original repo. To pull in
upstream changes, run `git fetch upstream && git merge upstream/main`.

---

# Part 1 — Naukri profile refresh

Keeps your Naukri profile "recently updated" — recruiters see fresh profiles first.
Every run it cycles trailing dots on your **resume headline** ("" -> "." -> ".." -> ""),
which counts as a profile update on Naukri, and re-uploads your resume PDF whenever
the profile's "Uploaded on" date is not today. Schedule it hourly and forget about it.

- Logs in automatically with your **Google account** (session is saved after the first login).
- Runs in an off-screen Chrome window (Naukri blocks headless browsers).
- Verifies the save actually stuck on the server before reporting success.
- Re-uploads the resume daily; pass `--force-cv` to re-upload even when the date is already today.
- All personal data lives in `.env` — nothing sensitive is in the code.

## Requirements

- Windows 10/11 (uses Task Scheduler for the hourly run)
- [Node.js](https://nodejs.org/) 18+
- Google Chrome installed
- A Naukri account that signs in with Google

## Setup

**1. Clone and install:**

```powershell
git clone https://github.com/ankitbaghel01/naukri_update.git
cd naukri_update
npm install
```

**2. Create your `.env`:**

```powershell
copy .env.example .env
```

Open `.env` and fill in at least:

| Variable | What it is |
|---|---|
| `GOOGLE_EMAIL` | The Google account your Naukri profile uses |
| `GOOGLE_PASSWORD` | Its password (used only for the automated sign-in) |
| `NAUKRI_PROFILE_URL` | Your Naukri profile page — the default `https://www.naukri.com/mnjuser/profile` works for every account |
| `RESUME_FILE` | Resume PDF re-uploaded to the profile daily — filename relative to this folder, or an absolute path |

`.env` is git-ignored, so your credentials never get pushed.

**3. First login (one time, visible browser):**

```powershell
node naukri-profile-refresh.js login
```

A Chrome window opens and signs in with Google. If Google asks for 2-step
verification, approve it once — the session is saved to `.naukri-chrome-profile/`
and reused by every later run.

**4. Test a silent run:**

```powershell
node naukri-profile-refresh.js
```

Check `naukri-refresh.log` — you should see a line like:

```
[27/7/2026, 1:05:12 pm] OK: headline dot 1 added (verified), cv up-to-date → "AI Full Stack Developer | ..."
```

## Run it hourly (Task Scheduler)

Run this once in PowerShell (adjust the path to where you cloned the repo):

```powershell
$repo = "C:\path\to\auto-apply"
$action  = New-ScheduledTaskAction -Execute "node.exe" -Argument "`"$repo\naukri-profile-refresh.js`"" -WorkingDirectory $repo
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "NaukriProfileRefresh" -Action $action -Trigger $trigger -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable)
```

That's it — the script now refreshes your profile every hour while your PC is on.

Useful commands:

```powershell
Get-ScheduledTask NaukriProfileRefresh            # check status
Start-ScheduledTask NaukriProfileRefresh          # run now
Disable-ScheduledTask NaukriProfileRefresh        # pause
Enable-ScheduledTask NaukriProfileRefresh         # resume
Unregister-ScheduledTask NaukriProfileRefresh     # remove
```

## Run it hourly on macOS (launchd)

Setup is the same as above (use `cp .env.example .env`). Then register a launchd
agent, which runs at login and every hour after that:

```bash
./setup-schedule-mac.sh            # hourly profile refresh
./setup-schedule-mac.sh --naukri   # also the LIVE Naukri auto-apply job
./setup-schedule-mac.sh --all      # also the LIVE Naukri + Wellfound auto-apply jobs
./setup-schedule-mac.sh --status   # check
launchctl kickstart gui/$(id -u)/com.naukri-update.profile-refresh   # run now
./setup-schedule-mac.sh --remove   # remove all
```

Output goes to `launchd-<job>.log` in the repo folder.

**Only while you're away.** Chrome can't be kept fully off screen on macOS, so the
scheduled jobs pass `--when-away`. A run does nothing unless your screen is locked or
the Mac has had no keyboard or mouse input for 10 minutes (set `AWAY_IDLE_MINUTES` in
`.env` to change this). The refresh checks every 15 minutes, so it catches meetings and
lunch breaks, and it refreshes at most once an hour. Skips show up as
`skip: in use (...)` in the launchd log. Manual runs ignore the check unless you pass
`--when-away` yourself.

**Hiding the window on macOS:** a hidden run hides the automation Chrome at the app level
(like Cmd+H) through System Events. Your personal Chrome is never touched. `--minimize`
and `node show-windows.js` work the same way as on Windows. On macOS the window shows
for about a second before it hides. macOS asks once for these permissions, for your
terminal and, for scheduled runs, for `node`:

- **Automation → System Events**, needed to hide
- **Accessibility**, needed to minimise and restore

If the repo is under `~/Desktop`, `~/Documents` or `~/Downloads`, a scheduled run also
needs folder access for `node`. Go to System Settings → Privacy & Security → Files and
Folders (or Full Disk Access). Moving the repo somewhere like `~/naukri_update` avoids
this.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Google login did not complete` in the log | Run `node naukri-profile-refresh.js login` and approve the 2-step verification prompt once manually. |
| `save did not stick` in the log | Naukri changed its headline editor — open an issue. |
| Any other error | Check `naukri-refresh-error-*.png` screenshots in the repo folder — they show exactly what the browser saw when it failed. |
| Want to start fresh | Delete the `.naukri-chrome-profile/` folder and run the `login` step again. |

## Files

| File | Purpose |
|---|---|
| `naukri-profile-refresh.js` | The refresh script |
| `config.js` | Loads `.env` (no dependencies) |
| `.env.example` | Template — copy to `.env` and fill in |
| `naukri-refresh.log` | Run history (git-ignored) |
| `.naukri-chrome-profile/` | Saved Chrome session (git-ignored) |
| `setup-schedule-mac.sh` | Registers the macOS launchd jobs |
| `window-utils.js` | Hides, minimises and restores the automation Chrome (Windows and macOS), and runs the away check |
| `launchd-*.log` | Output of the scheduled macOS jobs (git-ignored) |
| `.last-refresh` | Time of the last successful refresh; the once-an-hour limit reads it (git-ignored) |

## Disclaimer

Automating your own profile may be against Naukri's Terms of Service. It only
edits your own headline at a slow, human-like rate, but use at your own risk.

---

# Part 2 — Auto-apply (Wellfound / Indeed / Naukri)

Automatically applies to matching jobs on [Wellfound](https://wellfound.com) (ex-AngelList Talent).
A Playwright runner opens Chrome with your saved Wellfound session, injects the apply
script into the `/jobs` feed, and the script:

- scrolls the infinite feed and picks jobs whose **title matches your keywords** (and skips a blocklist),
- opens each job's "Apply to *Company*" panel,
- fills the **cover letter** (personalized per company/role from your `.env` data),
- answers extra questions from a built-in Q&A bank (optionally falls back to **Gemini** for unknown questions),
- handles location prompts ("I can relocate to…"), dropdowns, radios and checkboxes,
- submits, logs every application to `applications.csv`, and respects a **50/day cap**.

It starts in **DRY RUN** mode by default — it fills everything but never presses Send —
so you can watch it work before going live.

## Requirements

- Windows 10/11 (Task Scheduler used for automatic daily runs — manual runs work anywhere Node does)
- [Node.js](https://nodejs.org/) 18+
- Google Chrome
- A Wellfound account with your profile + resume completed

## Setup

**1. Clone and install:**

```powershell
git clone https://github.com/ankitbaghel01/wellfound_autoApply.git
cd wellfound_autoApply
npm install
```

**2. Create your `.env`:**

```powershell
copy .env.example .env
```

Open `.env` and fill in your details — name, contact, skills, highlights, salary
expectations, links, etc. Every application answer and cover letter is built from
these values; **nothing personal is hard-coded in the scripts**. `.env` is
git-ignored, so your data never gets pushed.

Optional: set `GEMINI_KEY` to a free Google Gemini API key — any application
question the built-in answer bank can't match gets answered by Gemini using your CV.

**3. Log in to Wellfound (one time, visible browser):**

```powershell
node auto-apply-runner.js wellfound login
```

A Chrome window opens — log in to wellfound.com, then close the window.
The session is saved to `.wellfound-chrome-profile/` and reused by every later run.

**4. Dry run (watch it, nothing is submitted):**

```powershell
node auto-apply-runner.js wellfound
```

Chrome opens on the jobs feed, and you'll see forms being filled. The log
(`auto-apply-wellfound.log`) shows lines like:

```
✍ cover letter filled
🔍 DRY_RUN — would click: Apply
==> 1/50 this run (1/50 today)
```

**5. Go live:**

```powershell
node auto-apply-runner.js wellfound --live
```

Same flow, but Send is actually clicked. Each application is appended to
`applications.csv` (Date, Site, Role, Company, Salary, Skills, Job Link, JD) and
counted in `apply-state-wellfound.json` toward the daily cap.

## Customizing which jobs it applies to

Edit the `CONFIG` block at the top of `wellfound-auto-apply.js`:

| Setting | What it does |
|---|---|
| `TITLE_KEYWORDS` | Apply only when the job title contains one of these (case-insensitive) |
| `TITLE_BLOCKLIST` | Skip when the title contains any of these (senior, manager, .net, …) |
| `MAX_APPLICATIONS` | Per-run cap (the runner overrides it with the daily cap remaining) |
| `MIN_DELAY_MS` / `MAX_DELAY_MS` | Wait between applications (default 60–150 s — human pace; going faster trips Wellfound's bot-check) |

**Locations:** the script applies to whatever your Wellfound search filters show on
`wellfound.com/jobs` — set your filters (remote / worldwide / a city) once in the
browser and it follows them. Jobs in other locations are still handled: when
Wellfound asks, it picks "I can relocate to…" and selects the job's offered location.
Jobs the company has location-blocked are detected and skipped. Jobs posted more than
14 days ago are skipped.

## Run it automatically every day (Task Scheduler)

```powershell
$repo = "C:\path\to\wellfound_autoApply"
$action  = New-ScheduledTaskAction -Execute "node.exe" -Argument "`"$repo\auto-apply-runner.js`" wellfound --live" -WorkingDirectory $repo
$trigger = New-ScheduledTaskTrigger -Daily -At 12:30
Register-ScheduledTask -TaskName "WellfoundAutoApply" -Action $action -Trigger $trigger -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable)
```

Useful commands:

```powershell
Start-ScheduledTask WellfoundAutoApply       # run now
Disable-ScheduledTask WellfoundAutoApply     # pause
Enable-ScheduledTask WellfoundAutoApply      # resume
Unregister-ScheduledTask WellfoundAutoApply  # remove
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `0 job cards found` on every page | Wellfound is showing a DataDome "Verification Required" captcha. Run `node auto-apply-runner.js wellfound login`, solve the slider once manually, close the window, re-run. |
| Session logged out | Delete `.wellfound-chrome-profile/` and repeat the `login` step. |
| `no apply modal found — skipping` | That job opened as a full page instead of the apply panel — it's skipped safely and not counted. |
| `no Send button found` on many jobs in a row | Usually the bot-check again (see first row). Keep delays at 60 s+. |
| Want today's counter reset | Delete `apply-state-wellfound.json`. |

## Files

| File | Purpose |
|---|---|
| `auto-apply-runner.js` | Playwright wrapper: opens Chrome, injects the site script, logs to CSV, enforces the daily cap |
| `wellfound-auto-apply.js` | The Wellfound apply logic (also pasteable directly into the DevTools console) |
| `config.js` | Tiny no-dependency `.env` loader |
| `.env.example` | Template — copy to `.env` and fill in |
| `applications.csv` | Every submitted application (git-ignored) |
| `apply-state-wellfound.json` | Today's application count for the 50/day cap (git-ignored) |
| `auto-apply-wellfound.log` | Run history (git-ignored) |
| `.wellfound-chrome-profile/` | Saved Chrome session (git-ignored) |

## Disclaimer

Auto-applying may violate Wellfound's Terms of Service and can get an
account rate-limited or banned. The delays are deliberately human-like and everything
runs on your own machine with your own account — use at your own risk, and review
the dry run before going live.


## If something goes wrong:
- "Looks logged-out": copy the profile again. Run rm -rf .naukri-apply-profile && cp -R .naukri-chrome-profile .naukri-apply-profile && rm -f .naukri-apply-profile/Singleton*.
- A stuck form: the run saves a blocked-step-naukri.png screenshot. Send me the terminal output and I'll look.