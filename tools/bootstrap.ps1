# Creates the platform folders (android, ios, windows, linux, macos), generates icons and fetches packages.
# Run from the project root in the VS Code terminal:  .\tools\bootstrap.ps1
$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Write-Error 'Flutter was not found on PATH. See README, "Install Flutter".'; exit 1 }
flutter create --platforms=windows,linux,macos,android,ios --org zw.mythosprime --project-name youthcare_connect .
flutter pub get
dart run flutter_launcher_icons
python tools/brand_platforms.py
Write-Host 'Done. Next: flutter test ; flutter run -d windows'
