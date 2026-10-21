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

# By default the web build leaves CanvasKit on Google's CDN: the page ships
# only an engine revision, and the loader turns that into a
# www.gstatic.com/flutter-canvaskit/<revision>/ URL it fetches at runtime.
# Nothing renders until that fetch lands, so any device that cannot reach
# gstatic -- a content blocker, a filtering DNS, a captive or corporate
# network, Lockdown Mode -- sits on the splash screen forever while the same
# build works fine on the developer's machine. The flag puts the same files
# under our own origin, which we already serve and already cache.
BUILD_ARGS=(--release)
# Tells the output check whether a local CanvasKit was actually asked for, so
# it can tell "this SDK is too old to know the flag", which is worth a warning
# and nothing more, apart from "the flag was passed and did not take", which
# is a regression and fails the build.
export SKYFINDER_EXPECT_LOCAL_CANVASKIT=1
# The help text spells a negatable flag '--[no-]web-resources-cdn', so looking
# for the literal '--no-web-resources-cdn' never matches and the build quietly
# decides the SDK is too old. Match the stem.
if flutter build web --help 2>&1 | grep -q -- 'web-resources-cdn'; then
  BUILD_ARGS+=(--no-web-resources-cdn)
  echo "==> CanvasKit will be served from our own origin (--no-web-resources-cdn)"
else
  # Fallback for an SDK without the flag. The tool only adds its own gstatic
  # FLUTTER_WEB_CANVASKIT_URL define when that define is not already set, so
  # setting it here keeps the engine pointed at the copy we ship.
  BUILD_ARGS+=(--dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/)
  echo "==> CanvasKit will be served from our own origin (dart-define)"
fi

flutter build web "${BUILD_ARGS[@]}"

# The output check is what actually guards the deploy: a web build succeeds
# whether or not the overlay landed and whether or not CanvasKit ended up
# local, so without this a broken page would ship green.
python3 tool/check_web_output.py build/web

echo "==> build/web is ready"
ls -la build/web | head -20
