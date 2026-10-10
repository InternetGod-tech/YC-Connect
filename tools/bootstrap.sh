#!/usr/bin/env bash
set -euo pipefail
command -v flutter >/dev/null || { echo "Flutter not found on PATH"; exit 1; }
flutter create --platforms=windows,linux,macos,android,ios --org zw.mythosprime --project-name youthcare_connect .
flutter pub get
dart run flutter_launcher_icons
python3 tools/brand_platforms.py
echo "Done. Next: flutter test ; flutter run -d linux"
