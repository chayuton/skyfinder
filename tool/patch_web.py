#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Make the generated web page ours without breaking Flutter's bootstrap.

The page is patched rather than replaced: Flutter injects a loader script into
index.html that changes between SDK versions, and a hand-written replacement
goes stale the first time that changes.

The "already done" guard is a sentinel comment of our own. An earlier version
guarded on `apple-mobile-web-app-title`, which Flutter's own template already
emits, so the whole block was silently skipped and the page shipped without a
theme colour or a dark first paint.
"""
import re
import sys

SENTINEL = '<!-- skyfinder-web-overlay -->'

EXTRA = SENTINEL + '''
  <meta name="theme-color" content="#070A14">
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

# Tags Flutter's template may already carry; ours replace them rather than
# sitting alongside and leaving the browser to pick one.
SUPERSEDED = [
    r'[ \t]*<meta name="apple-mobile-web-app-title"[^>]*>\n?',
    r'[ \t]*<meta name="apple-mobile-web-app-capable"[^>]*>\n?',
    r'[ \t]*<meta name="mobile-web-app-capable"[^>]*>\n?',
    r'[ \t]*<meta name="apple-mobile-web-app-status-bar-style"[^>]*>\n?',
    r'[ \t]*<meta name="theme-color"[^>]*>\n?',
    r'[ \t]*<link rel="apple-touch-icon"[^>]*>\n?',
]


def main(path: str) -> None:
    with open(path, encoding='utf-8') as fh:
        s = fh.read()

    if SENTINEL in s:
        print('   already patched')
        return

    s = re.sub(r'<title>.*?</title>', '<title>ดาวนำทาง</title>', s, flags=re.S)
    s = re.sub(
        r'<meta name="description" content=".*?">',
        '<meta name="description" content="แอปดูดาวภาษาไทย '
        'ใช้พิกัดของเครื่องคำนวณตำแหน่งดาวแบบเรียลไทม์">',
        s, flags=re.S)
    s = re.sub(r'<html\b[^>]*>', '<html lang="th">', s, count=1)

    for pattern in SUPERSEDED:
        s = re.sub(pattern, '', s)

    if '</head>' not in s:
        raise SystemExit(f'{path}: no </head>, cannot add metadata')
    s = s.replace('</head>', '  ' + EXTRA + '</head>', 1)

    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(s)
    print('   index.html patched')


if __name__ == '__main__':
    main(sys.argv[1])
