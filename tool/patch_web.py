#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Make the generated web page ours without breaking Flutter's bootstrap.

The page is patched rather than replaced: Flutter injects a loader script into
index.html that changes between SDK versions, and a hand-written replacement
goes stale the first time that changes.
"""
import re
import sys

EXTRA = '''  <meta name="theme-color" content="#070A14">
  <meta name="color-scheme" content="dark">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="ดาวนำทาง">
  <link rel="apple-touch-icon" href="icons/apple-touch-icon-180.png">
  <!-- The app paints its own night sky, so the page starts dark instead of
       flashing white between first paint and the engine starting. -->
  <style>
    html, body { margin: 0; padding: 0; background: #070A14; height: 100%; }
    body { overscroll-behavior-y: none; }
  </style>
'''


def main(path: str) -> None:
    with open(path, encoding='utf-8') as fh:
        s = fh.read()

    s = re.sub(r'<title>.*?</title>', '<title>ดาวนำทาง</title>', s, flags=re.S)
    s = re.sub(
        r'<meta name="description" content=".*?">',
        '<meta name="description" content="แอปดูดาวภาษาไทย '
        'ใช้พิกัดของเครื่องคำนวณตำแหน่งดาวแบบเรียลไทม์">',
        s, flags=re.S)
    s = re.sub(r'<html\b[^>]*>', '<html lang="th">', s, count=1)

    if 'apple-mobile-web-app-title' not in s:
        if '</head>' not in s:
            raise SystemExit(f'{path}: no </head>, cannot add metadata')
        s = s.replace('</head>', EXTRA + '</head>', 1)

    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(s)
    print('   index.html patched')


if __name__ == '__main__':
    main(sys.argv[1])
