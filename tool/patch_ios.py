#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Add the usage descriptions iOS shows when it asks for permission.

Apple rejects an app whose descriptions are missing, and an app whose
descriptions are vague reads as evasive to the person being asked, so these
say exactly what the data is for.
"""
import sys

KEYS = '''\t<key>NSLocationWhenInUseUsageDescription</key>
\t<string>ใช้พิกัดของคุณเพื่อคำนวณว่าดาวแต่ละดวงอยู่ตรงไหนบนท้องฟ้าจากจุดที่คุณยืน</string>
\t<key>NSMotionUsageDescription</key>
\t<string>ใช้เข็มทิศและเซ็นเซอร์เอียงเพื่อบอกว่าคุณกำลังเล็งมือถือไปที่ดาวดวงใด</string>
'''


def main(path: str) -> None:
    with open(path, encoding='utf-8') as fh:
        s = fh.read()
    if 'NSLocationWhenInUseUsageDescription' in s:
        print('   already present')
        return
    i = s.rfind('</dict>')
    if i < 0:
        raise SystemExit(f'{path}: no closing </dict>, cannot place keys')
    s = s[:i] + KEYS + s[i:]
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(s)
    print('   Info.plist patched')


if __name__ == '__main__':
    main(sys.argv[1])
