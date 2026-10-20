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
      transition: opacity 260ms ease, visibility 260ms ease;
      overflow: hidden;
    }
    #skyfinder-loader.hidden {
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
    }
    #skyfinder-loader canvas {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      display: block;
      background: transparent;
    }
    .skyfinder-loader-shell {
      position: relative;
      z-index: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 14px;
      color: #dfe7ff;
      text-align: center;
      user-select: none;
      transform: translateY(-6px);
    }
    .skyfinder-loader-orbit {
      width: 86px;
      height: 86px;
      border-radius: 50%;
      border: 1px solid rgba(255,255,255,0.14);
      box-shadow: inset 0 0 18px rgba(152, 188, 255, 0.22), 0 0 34px rgba(111, 143, 255, 0.18);
      position: relative;
      animation: skyfinder-spin 1.6s linear infinite;
    }
    .skyfinder-loader-orbit::before,
    .skyfinder-loader-orbit::after {
      content: "";
      position: absolute;
      border-radius: 50%;
      background: #f8d36f;
      box-shadow: 0 0 26px rgba(248, 211, 111, 0.9);
    }
    .skyfinder-loader-orbit::before {
      width: 12px;
      height: 12px;
      top: 8px;
      left: 18px;
    }
    .skyfinder-loader-orbit::after {
      width: 10px;
      height: 10px;
      right: 16px;
      bottom: 14px;
    }
    @keyframes skyfinder-spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .skyfinder-loader-title {
      font-size: 15px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-weight: 700;
      color: #f2f6ff;
    }
    .skyfinder-loader-sub {
      font-size: 11px;
      color: rgba(223, 231, 255, 0.76);
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .skyfinder-loader-progress-wrap {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      min-width: min(260px, 72vw);
    }
    .skyfinder-loader-progress-bar {
      width: min(240px, 70vw);
      height: 6px;
      border-radius: 999px;
      overflow: hidden;
      background: rgba(255,255,255,0.08);
      box-shadow: inset 0 0 0 1px rgba(255,255,255,0.05);
    }
    .skyfinder-loader-progress-fill {
      width: 0%;
      height: 100%;
      border-radius: inherit;
      background: linear-gradient(90deg, #90b8ff 0%, #7ec7ff 30%, #f0d98c 100%);
      box-shadow: 0 0 18px rgba(126, 199, 255, 0.8);
      transition: width 180ms ease-out;
    }
    .skyfinder-loader-progress-text {
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.1em;
      color: rgba(255,255,255,0.9);
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    }
    @media (max-width: 480px) {
      .skyfinder-loader-shell { gap: 12px; }
      .skyfinder-loader-orbit {
        width: 72px;
        height: 72px;
      }
      .skyfinder-loader-title {
        font-size: 13px;
      }
      .skyfinder-loader-sub {
        font-size: 10px;
      }
    }
  </style>
  <div id="skyfinder-loader" aria-live="polite" aria-busy="true">
    <canvas id="skyfinder-loader-canvas"></canvas>
    <div class="skyfinder-loader-shell">
      <div class="skyfinder-loader-orbit"></div>
      <div class="skyfinder-loader-title">ดาวนำทาง</div>
      <div class="skyfinder-loader-sub">กำลังโหลดท้องฟ้า…</div>
      <div class="skyfinder-loader-progress-wrap">
        <div class="skyfinder-loader-progress-bar" aria-hidden="true">
          <div id="skyfinder-loader-progress-fill" class="skyfinder-loader-progress-fill"></div>
        </div>
        <div id="skyfinder-loader-progress-text" class="skyfinder-loader-progress-text">8%</div>
      </div>
    </div>
  </div>
  <script>
    (() => {
      const loader = document.getElementById('skyfinder-loader');
      const fill = document.getElementById('skyfinder-loader-progress-fill');
      const text = document.getElementById('skyfinder-loader-progress-text');
      const canvas = document.getElementById('skyfinder-loader-canvas');
      if (!loader || !fill || !text || !canvas) return;

      const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
      const slowNetwork = connection && ['slow-2g', '2g', '3g'].includes(connection.effectiveType);
      const longDelay = slowNetwork || window.innerWidth < 420;
      const startDelay = longDelay ? 1600 : 600;
      const maxDelay = longDelay ? 11000 : 7000;

      const hideLoader = () => {
        if (loader.classList.contains('hidden')) return;
        loader.classList.add('hidden');
        window.setTimeout(() => loader.remove(), 280);
      };

      const drawStars = () => {
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const resize = () => {
          const ratio = window.devicePixelRatio || 1;
          canvas.width = Math.floor(window.innerWidth * ratio);
          canvas.height = Math.floor(window.innerHeight * ratio);
          canvas.style.width = window.innerWidth + 'px';
          canvas.style.height = window.innerHeight + 'px';
          ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
        };

        const stars = Array.from({ length: Math.min(120, Math.max(52, Math.round(window.innerWidth / 12))) }, () => ({
          x: Math.random() * window.innerWidth,
          y: Math.random() * window.innerHeight,
          r: Math.random() * 2.1 + 0.5,
          a: Math.random() * 0.9 + 0.15,
          drift: Math.random() * 0.6 + 0.2,
        }));

        const render = () => {
          ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
          for (const star of stars) {
            const alpha = star.a + Math.sin((performance.now() * 0.0013 + star.x) * star.drift) * 0.35;
            ctx.beginPath();
            ctx.fillStyle = 'rgba(255,255,255,' + Math.min(1, Math.max(0.15, alpha)) + ')';
            ctx.arc(star.x, star.y, star.r, 0, Math.PI * 2);
            ctx.fill();
            if (Math.random() < 0.009) {
              ctx.beginPath();
              ctx.strokeStyle = 'rgba(162, 194, 255, 0.28)';
              ctx.moveTo(star.x, star.y);
              ctx.lineTo(star.x + 18, star.y - 12);
              ctx.stroke();
            }
          }
          requestAnimationFrame(render);
        };

        resize();
        window.addEventListener('resize', resize, { passive: true });
        render();
      };

      if (!prefersReducedMotion) {
        drawStars();
      }

      const startAt = performance.now();
      const tick = (now) => {
        const elapsed = now - startAt;
        const ratio = Math.min(1, elapsed / maxDelay);
        const percent = Math.min(98, Math.max(8, Math.round(8 + ratio * 90)));
        fill.style.width = percent + '%';
        text.textContent = percent + '%';

        if (ratio < 1) {
          requestAnimationFrame(tick);
        }
      };

      window.setTimeout(() => requestAnimationFrame(tick), startDelay);

      if (prefersReducedMotion) {
        fill.style.width = '100%';
        text.textContent = '100%';
        hideLoader();
        return;
      }

      window.addEventListener('flutter-first-frame', () => {
        fill.style.width = '100%';
        text.textContent = '100%';
        window.setTimeout(hideLoader, longDelay ? 1800 : 900);
      }, { once: true });

      window.addEventListener('load', () => {
        window.setTimeout(() => {
          if (!loader.classList.contains('hidden')) {
            fill.style.width = '100%';
            text.textContent = '100%';
            window.setTimeout(hideLoader, longDelay ? 1500 : 700);
          }
        }, longDelay ? 3500 : 1800);
      }, { once: true });
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
