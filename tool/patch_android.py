#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Add the location and sensor entries to a freshly generated AndroidManifest."""
import sys

PERMS = '''
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- required="false" keeps the Play Store from hiding the app from phones
         without a compass: the manual aim sliders still work there. -->
    <uses-feature android:name="android.hardware.sensor.compass" android:required="false" />
    <uses-feature android:name="android.hardware.sensor.accelerometer" android:required="false" />
    <uses-feature android:name="android.hardware.location.gps" android:required="false" />
'''


def main(path: str) -> None:
    with open(path, encoding='utf-8') as fh:
        s = fh.read()
    if 'ACCESS_FINE_LOCATION' in s:
        print('   already present')
        return
    if '<application' not in s:
        raise SystemExit(f'{path}: no <application> tag, cannot place permissions')
    s = s.replace('<application', PERMS + '    <application', 1)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(s)
    print('   AndroidManifest patched')


if __name__ == '__main__':
    main(sys.argv[1])
