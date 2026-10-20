#!/usr/bin/env bash
# Generate the platform folders and make them ours.
#
# `flutter create` writes a stock project: an AndroidManifest and Info.plist
# with no location or sensor entries, an English web page with Flutter's own
# icons, and a sample test that references a class this project does not have.
# A freshly generated project therefore builds fine and then silently fails to
# find the sky. This script closes every one of those gaps, and both CI and
# anyone building locally run it, so the two never drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORMS="${1:-android,ios,web}"
echo "==> flutter create --platforms=$PLATFORMS"
flutter create --org th.skyfinder --project-name skyfinder --platforms="$PLATFORMS" .

# ---------------------------------------------------------------- Android
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ] && ! grep -q ACCESS_FINE_LOCATION "$MANIFEST"; then
  echo "==> adding Android permissions"
  python3 tool/patch_android.py "$MANIFEST"
fi

# ------------------------------------------------------------------- iOS
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSLocationWhenInUseUsageDescription "$PLIST"; then
  echo "==> adding iOS usage descriptions"
  python3 tool/patch_ios.py "$PLIST"
fi

# ------------------------------------------------------------------- web
if [ -d web ] && [ -d web_overlay ]; then
  echo "==> applying the web overlay"
  cp -f web_overlay/manifest.json web/manifest.json
  cp -f web_overlay/favicon.png web/favicon.png
  mkdir -p web/icons
  cp -f web_overlay/icons/*.png web/icons/
  python3 tool/patch_web.py web/index.html
fi

# `flutter create` drops in a stock test that instantiates MyApp, a class this
# project does not have, so analysis fails until it is removed.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  echo "==> removing the generated widget_test.dart stub"
  rm -f test/widget_test.dart
fi

echo "==> platforms ready"
