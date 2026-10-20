#!/usr/bin/env bash
# Build the web app on Vercel.
#
# Vercel's build image has no Flutter, so the SDK is fetched here. The clone is
# shallow and pinned to a channel rather than a tag: pinning an exact version
# would break the build the day that tag is garbage-collected, and the test
# suite in CI is what actually guards against an SDK change breaking us.
set -euo pipefail

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
CHANNEL="${FLUTTER_CHANNEL:-stable}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "==> fetching the Flutter SDK ($CHANNEL)"
  rm -rf "$FLUTTER_HOME"
  git clone --depth 1 --branch "$CHANNEL" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
else
  echo "==> reusing the cached Flutter SDK"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
# Vercel runs the build as root in a container it throws away.
git config --global --add safe.directory "$FLUTTER_HOME" || true

flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true

./tool/prepare_platforms.sh web
flutter pub get
flutter build web --release

echo "==> build/web is ready"
ls -la build/web | head -20
