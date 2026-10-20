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
    #skyfinder-loader {
      position: fixed;
      inset: 0;
      z-index: 9999;
      display: grid;
      place-items: center;
      background: radial-gradient(circle at top, #0b1530 0%, #070A14 48%, #02060d 100%);
      transition: opacity 220ms ease, visibility 220ms ease;
    }
    #skyfinder-loader.hidden {
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
    }
    .skyfinder-loader-shell {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 10px;
      color: #dfe7ff;
      text-align: center;
      user-select: none;
    }
    .skyfinder-loader-orbit {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      border: 1px solid rgba(255,255,255,0.12);
      box-shadow: inset 0 0 12px rgba(152, 188, 255, 0.22), 0 0 32px rgba(111, 143, 255, 0.18);
      position: relative;
      animation: skyfinder-spin 1.6s linear infinite;
    }
    .skyfinder-loader-orbit::before,
    .skyfinder-loader-orbit::after {
      content: "";
      position: absolute;
      border-radius: 50%;
      background: #f8d36f;
      box-shadow: 0 0 24px rgba(248, 211, 111, 0.9);
    }
    .skyfinder-loader-orbit::before {
      width: 10px;
      height: 10px;
      top: 8px;
      left: 16px;
    }
    .skyfinder-loader-orbit::after {
      width: 8px;
      height: 8px;
      right: 14px;
      bottom: 12px;
    }
    @keyframes skyfinder-spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .skyfinder-loader-title {
      font-size: 15px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-weight: 700;
      color: #f2f6ff;
    }
    .skyfinder-loader-sub {
      font-size: 11px;
      color: rgba(223, 231, 255, 0.74);
      letter-spacing: 0.06em;
    }
  </style>
  <div id="skyfinder-loader" aria-live="polite" aria-busy="true">
    <div class="skyfinder-loader-shell">
      <div class="skyfinder-loader-orbit"></div>
      <div class="skyfinder-loader-title">ดาวนำทาง</div>
      <div class="skyfinder-loader-sub">กำลังโหลดท้องฟ้า…</div>
    </div>
  </div>
  <script>
    (() => {
      const loader = document.getElementById('skyfinder-loader');
      if (!loader) return;

      const hideLoader = () => {
        if (loader.classList.contains('hidden')) return;
        loader.classList.add('hidden');
        window.setTimeout(() => loader.remove(), 260);
      };

      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        hideLoader();
        return;
      }

      if (document.readyState === 'complete') {
        window.setTimeout(hideLoader, 220);
      } else {
        window.addEventListener('load', () => window.setTimeout(hideLoader, 220), { once: true });
      }

      window.addEventListener('flutter-first-frame', hideLoader, { once: true });
    })();
  </script>
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
