"""Applies the YouthCare Connect display name to the platform folders created by `flutter create`.
Run from the project root after bootstrap:  python tools/brand_platforms.py
Safe to run more than once. Prints what it changed."""
import pathlib, re

NAME = "YouthCare Connect"
ROOT = pathlib.Path(__file__).resolve().parent.parent

def edit(rel, fn):
    p = ROOT / rel
    if not p.exists():
        print("skip (missing):", rel); return
    s = p.read_text(encoding="utf-8")
    t = fn(s)
    if t != s:
        p.write_text(t, encoding="utf-8"); print("updated:", rel)
    else:
        print("unchanged:", rel)

edit("android/app/src/main/AndroidManifest.xml", lambda s: re.sub(r'android:label="[^"]*"', f'android:label="{NAME}"', s, count=1))
edit("ios/Runner/Info.plist", lambda s: re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', rf'\g<1>{NAME}\g<2>', s))
edit("macos/Runner/Configs/AppInfo.xcconfig", lambda s: re.sub(r'(?m)^PRODUCT_NAME = .*$', f'PRODUCT_NAME = {NAME}', s))
edit("windows/runner/main.cpp", lambda s: s.replace('L"youthcare_connect"', f'L"{NAME}"'))
edit("linux/runner/my_application.cc", lambda s: s.replace('"youthcare_connect"', f'"{NAME}"'))

# `flutter create` adds a sample test that refers to a template app we do not use. Remove it if present.
sample = ROOT / "test" / "widget_test.dart"
if sample.exists() and "MyApp" in sample.read_text(encoding="utf-8"):
    sample.unlink(); print("removed template test: test/widget_test.dart")
