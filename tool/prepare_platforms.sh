#!/usr/bin/env bash
# Generate the platform folders and inject the permissions the app needs.
#
# `flutter create` writes a stock AndroidManifest and Info.plist with no
# location or sensor entries, so a freshly generated project builds fine and
# then silently fails to find the sky. This script closes that gap and is run
# both by CI and by anyone building locally, so the two never drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORMS="${1:-android,ios,web}"
echo "==> flutter create --platforms=$PLATFORMS"
flutter create --org th.skyfinder --project-name skyfinder --platforms="$PLATFORMS" .

# ---------------------------------------------------------------- Android
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ] && ! grep -q ACCESS_FINE_LOCATION "$MANIFEST"; then
  echo "==> adding Android permissions"
  python3 - "$MANIFEST" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
perms = '''
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- required=false keeps the Play Store from hiding the app from phones
         without a compass: the manual aim sliders still work there. -->
    <uses-feature android:name="android.hardware.sensor.compass" android:required="false" />
    <uses-feature android:name="android.hardware.sensor.accelerometer" android:required="false" />
    <uses-feature android:name="android.hardware.location.gps" android:required="false" />
'''
s = s.replace('<application', perms + '    <application', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
fi

# ------------------------------------------------------------------- iOS
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSLocationWhenInUseUsageDescription "$PLIST"; then
  echo "==> adding iOS usage descriptions"
  python3 - "$PLIST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
keys = '''	<key>NSLocationWhenInUseUsageDescription</key>
	<string>ใช้พิกัดของคุณเพื่อคำนวณว่าดาวแต่ละดวงอยู่ตรงไหนบนท้องฟ้าจากจุดที่คุณยืน</string>
	<key>NSMotionUsageDescription</key>
	<string>ใช้เข็มทิศและเซ็นเซอร์เอียงเพื่อบอกว่าคุณกำลังเล็งมือถือไปที่ดาวดวงใด</string>
'''
i = s.rindex('</dict>')
s = s[:i] + keys + s[i:]
open(p, 'w', encoding='utf-8').write(s)
PY
fi

echo "==> platforms ready"
