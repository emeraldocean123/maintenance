# Maintenance Journal

## 2025-08-27 00:00:00 +0000 - Centralization and Launchers
- Moved toolkit to `Documents/dev/maintenance`.
- Added launcher wrappers (`bin/maintenance.ps1` and `.cmd`).
- Added installer to put launcher on PATH and Start Menu.
- Added dev scripts indexer to catalog scripts under `Documents/dev`.
 - Added `scripts/First-Run.ps1` for a one-command dry-run + summary.

## 2025-08-27 00:00:00 +0000 - Log Retention
- Added configurable log retention (`logging.retentionDays`, `logging.maxFiles`).
- Purges old `.log`/`.jsonl` files after each run.

## 2025-08-27 00:00:00 +0000 - Scheduling Enhancements
 - First-Run supports `-SetupSchedule` (weekly DryRun) and `-DailyApply` (optional daily Apply).
 - `Register-MaintenanceTask.ps1` improved: distinct task names, Apply vs DryRun modes.
 - Scheduled runs now use `scripts/Scheduled-Run.ps1` and can include tests via `-WithTests`.

## 2025-08-27 00:00:00 +0000 - Notifications
- Added `modules/Notifications.psm1` and integrated with scheduled runs.
- Toast notifications for failures or apply mode; optional email with logs.
 - DryRun emails embed last N journal bullet lines for quick context.
 - Emails include a compact digest of the latest log with selected levels.

## 2025-08-27 00:00:00 +0000 - Email Test Script
- Added `scripts/Test-Email.ps1` to preview or send a sample email.
- Supports including journal snippet, log digest, and latest logs as attachments.

## 2025-08-27 00:00:00 +0000 - Verify Setup
- Added `scripts/Verify-Setup.ps1` to chain health, tests, and an email preview.
- Can optionally send a real test email and register scheduled tasks.

## 2025-08-27 00:00:00 +0000 - Health Check
- Added `modules/Health.psm1` and `scripts/Check-Health.ps1`.
- Maintenance run writes scheduled task status lines into the journal.
 - Added launcher health (PATH, command resolution, Start Menu shortcut).

## 2025-08-27 00:00:00 +0000 - Self-Test
- Added `scripts/Self-Test.ps1` and `Test-LauncherExecution`.
- Runs the launcher in dry-run mode and records outcome + latest log.

## 2025-08-27 00:00:00 +0000 - Tests Added
- Added Pester tests under `tests/` for Logging, Health, SecureStore, WindowsProfile, NixTools, GitHubCleanup.
- Added `scripts/Run-Tests.ps1` to install Pester if needed and run the suite.

## 2025-08-27 00:00:00 +0000 - Secure GitHub Token
- Added secure secrets store (DPAPI) and helper script.
- Updated orchestrator to read token from env or secrets.
- Prefilled GitHub owner in config to `emeraldocean123`.

## 2025-08-27 00:00:00 +0000 - Summaries and Scheduling
- Added run summaries to orchestrator and journal entries.
- Introduced log summarizer (`scripts/Summarize-Logs.ps1`).
- Added scheduled task registrar (`scripts/Register-MaintenanceTask.ps1`).

## 2025-08-27 00:00:00 +0000 - Toolkit Scaffolded
- Added maintenance toolkit (PowerShell modules, orchestrator, Nix script).
- Configured structured logging to `maintenance/logs` and this journal.
- Implemented Windows profile tasks (flatten Downloads, remove cleanup reports/OBS_Backups, restore Mouse Without Borders) with dry-run safety.
- Implemented GitHub cleanup functions (close issues, disable workflows) using `GITHUB_TOKEN`.
- Added Nix/WSL script to run statix/deadnix/treefmt with logging.
- Added README and default config with safe settings.

## 2025-08-27 00:00:00 +0000 - Prior Work Recorded (per session notes)
- Profile reviewed; Google Drive/Mylio preserved; Downloads flattened to files only.
- Mouse Without Borders captures restored to Desktop path.
- Installed apps inventory captured; temp cleanup reports and OBS_Backups removed.
- GitHub Actions disabled across owned repos; open issues closed where applicable.
- WSL-friendly Nix tool workflow prepared; automatic fixes for unused/duplicate keys planned.

## 2025-08-27 00:00:00 +0000 - Reports and Uninstall
- Added disk usage reports (`modules/Reports.psm1`) and export script (`scripts/Export-Report.ps1`).
- Scheduled runs attach disk usage snapshot when enabled in config.
- Added `scripts/Uninstall-Toolkit.ps1` for clean removal (tasks, PATH, shortcut, logs, secrets).
 - Scheduled emails now attach a bundled ZIP report when enabled.

## 2025-08-27 00:00:00 +0000 - Analysis and Status
- Added PSScriptAnalyzer runner (`scripts/Run-Analyzer.ps1`) and config (`pssa` section).
- Scheduled runs can include analysis with `-WithAnalysis`.
- Added `scripts/Status.ps1` for a quick last-runs summary.
