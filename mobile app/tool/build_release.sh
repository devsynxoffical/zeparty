#!/usr/bin/env bash
# Release build for the Play Store / sideload testing.
#   tool/build_release.sh bundle   -> build/app/outputs/bundle/release/app-release.aab (upload this to Play)
#   tool/build_release.sh apk      -> one APK per ABI in build/app/outputs/flutter-apk/
# Both strip Dart symbols (--obfuscate --split-debug-info) and run R8 (see android/app/build.gradle.kts).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/check_assets.py
mode="${1:-bundle}"
sym="build/symbols"
case "$mode" in
  bundle) flutter build appbundle --release --obfuscate --split-debug-info="$sym" ;;
  apk)    flutter build apk --release --split-per-abi --obfuscate --split-debug-info="$sym" ;;
  *) echo "usage: $0 [bundle|apk]"; exit 2 ;;
esac
echo "Keep $sym/ with this version: it is needed to symbolicate crash reports."
