# YouthCare Connect
**Youth Health Referral & Continuity Platform** · engineering codename PROJECT-CORE · MYTHOSPRIME · HackLab Category 1

A native Flutter application (Windows, Linux, macOS, Android, iOS) that lets a young person find a service, send a referral request, and see who has to act next until follow-up is recorded and the referral closes. Support workers, providers and programme administrators work from the same record.

Everything runs on the device with a local SQLite database. No server, no account, no hosting cost.

## Status (read this first)
This repository was written without access to a Flutter SDK, so **it has not yet been compiled or run**. What has and has not been checked:

| Item | State |
|---|---|
| Referral engine, schema, seed data, tests (`test/engine_test.dart`) | Written. **Not yet run.** The earlier Python prototype's 13 tests passed; this Dart port is new. |
| Screens, navigation, themes, Settings, About, Admin | Written. **Not yet compiled.** Expect a few analyzer errors on first run. |
| Widget tests (`test/app_test.dart`) | Written. **Not yet run.** |
| Windows / Linux / macOS / Android / iOS builds | Build workflow written (`.github/workflows/build.yml`). **No platform has been built.** |
| Screen reader, keyboard, contrast checks | Built in by design, **not yet tested on a device**. See `docs/ACCESSIBILITY.md`. |

First job: run the commands below, then send me the analyzer/test output so I can fix whatever fails.

## Quick start (Windows, VS Code)
1. Install Flutter (stable, 3.27 or newer): https://docs.flutter.dev/get-started/install/windows/desktop. Run `flutter doctor` and fix what it flags.
   - For the Windows desktop build you need **Visual Studio 2022 Community (free)** with the *Desktop development with C++* workload.
2. Install VS Code extensions **Dart** and **Flutter** (suggested automatically).
3. Open this folder in VS Code, open a terminal and run:
   ```powershell
   .\tools\bootstrap.ps1
   flutter analyze
   flutter test
   flutter run -d windows
   ```
   `bootstrap.ps1` creates the platform folders, generates launcher icons from `assets/brand/app_icon.png`, and sets the display name.
4. If PowerShell blocks the script: run `powershell -ExecutionPolicy Bypass -File .\tools\bootstrap.ps1` (affects that one run only).

**`flutter test` on Windows** needs `sqlite3.dll` on the path. Download the 64-bit DLL from https://sqlite.org/download.html and put it in the project root. If you would rather not, push to GitHub and let the workflow run the tests on Linux.

## Free distribution
1. Create a **public** GitHub repository and push this folder (free Actions minutes apply to public repos; check GitHub's current terms).
2. Every push runs tests and builds all platforms. Download the artifacts from the *Actions* tab.
3. Tag a release (`git tag v1.0.0 && git push --tags`) to publish the files on the repository's *Releases* page.

| Platform | Output | Install | Signing |
|---|---|---|---|
| Android | `app-release.apk` | Copy to phone, allow install from this source | Debug-signed, for testing. Play Store needs your own keystore. |
| Windows | `YouthCareConnect-windows.zip` | Unzip, run `youthcare_connect.exe` | Unsigned: SmartScreen shows a warning. |
| Linux | `.tar.gz` bundle | Extract, run `./youthcare_connect` | n/a |
| macOS | `…-macos-unsigned.zip` | Right-click → Open | Unsigned. Notarised distribution needs a paid Apple Developer account. |
| iOS | Built with `--no-codesign` only | Cannot be installed | Needs a paid Apple Developer account. |

## Loading your verified directory
Edit `assets/data/directory.json` (format explained inside the file). Set a service to `"verified"` only after the provider has confirmed it. The file is read when the database is first created or when an administrator resets data. Existing installs keep their data until reset; use **Data → Reset** (after a backup).
Admins can also add and edit services inside the app (Directory).

## How the app is organised
```
lib/domain   models.dart, engine.dart   all referral rules: state machine, roles, validation, audit, dashboard
lib/data     app_db.dart                SQLite connection, schema, versioning, backup/restore
lib/core     theme.dart, controller.dart design tokens, settings, active role
lib/ui       one file per area           screens call the engine; they never write SQL
assets       brand/, data/directory.json
test         engine_test.dart, app_test.dart
```
Lifecycle: `pending → accepted | rerouted | declined → attended / missed → follow_up_due → completed`. Invalid moves and wrong-role actions throw `DomainError` and change nothing. Every change writes an audit record in the same transaction.

## Roles
Sign-in is not enabled. Use **Switch role** (top bar) or Settings. Production sign-in (OpenID Connect) is a later milestone; the engine already checks the role on every action, so a server can reuse the same rules.

| Role | Can |
|---|---|
| Young person | Find services, request, follow own referrals |
| Support worker | Create requests for a young person code, complete follow-up on their referrals |
| Service provider | Accept, pass on, decline, record attendance, complete follow-up for their facility only |
| Programme administrator | Counts, directory edits, activity log, backup/restore/reset. No personal details, no referral actions |

## Backup, restore, reset
Admin → **Data**. Backups are `.db` files in `Documents/YouthCareConnect-backups`. Restore validates the file first. Reset asks for confirmation and states what it deletes.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `flutter: command not found` | Add Flutter's `bin` folder to PATH, reopen VS Code. |
| `Unable to find suitable Visual Studio toolchain` | Install VS 2022 with *Desktop development with C++*, then `flutter doctor`. |
| `running scripts is disabled on this system` | Use the `-ExecutionPolicy Bypass -File` form above. |
| `Failed to load dynamic library 'sqlite3.dll'` (tests) | Put `sqlite3.dll` in the project root. |
| `Target of URI doesn't exist … youthcare_connect/...` | Run `flutter pub get`; check the folder name has no spaces. |
| `Error: No pubspec.yaml file found` | Open the project folder itself in VS Code. |
| `database is locked` | Close other running copies of the app, then reopen. |
| Port or device not found | `flutter devices`; enable Windows desktop with `flutter config --enable-windows-desktop`. |

## Known limitations
- Local, single-device data. No sync, no server, no sign-in yet.
- Audit log is a table on the device, not tamper-proof.
- Facility-level administrator is not a separate role yet; the administrator is programme-wide.
- No push notifications. Language packs are not implemented (text is English, in one place per screen).
- Launcher icon is cropped from a 580 px logo image and will look soft at large sizes; supply a higher-resolution original.
- Unreviewed by clinicians, safeguarding leads or a data-protection adviser. Do not load real patient information until those reviews and a hosting decision are done.
