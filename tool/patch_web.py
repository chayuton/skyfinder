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

The splash is inserted in two pieces. Metadata and styles belong in the head;
the splash markup and its script belong at the top of the body. An earlier
version pushed the whole thing in front of `</head>`, which left a `<div>`
inside the head: the parser recovers by closing the head early and opening a
body of its own, so the page happened to render, but the real `<body>` tag
that followed was then discarded as a stray. Putting the splash first in the
body also means its error handlers are installed before the async
flutter_bootstrap.js runs, so a failure during engine start is actually caught
instead of being lost before anything is listening.
"""
import re
import sys

SENTINEL = '<!-- skyfinder-web-overlay -->'

HEAD_EXTRA = SENTINEL + '''
  <!-- Flutter's web template ships no viewport tag at all. Without one a phone
       browser lays the page out at its fallback desktop width (about 980px) and
       scales the result down, so every width the app reads from MediaQuery is
       that fallback rather than the device: compactPhone never matches,
       tabletLikeLayout always does, and the max-width rule below never fires.
       The cover value for viewport-fit is deliberately left off. Flutter web
       does not fill MediaQuery.padding in from env(safe-area-inset-*), so with
       it the UI would sit under a notch or home indicator with no inset
       available to move it back; left off, iOS keeps the standalone web view
       inside the safe area by itself. Zoom is pinned because the sky map reads
       its own drag and pinch gestures, which browser page zoom would take. -->
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
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
    html, body { margin: 0; padding: 0; background: #070A14; height: 100%;
                   -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
    body { overscroll-behavior-y: none; }
    #skyfinder-loader, #skyfinder-loader * { box-sizing: border-box; }
    #skyfinder-loader {
      position: fixed;
      inset: 0;
      z-index: 9999;
      display: grid;
      place-items: center;
      padding: 24px 16px;
      overflow-y: auto;
      -webkit-overflow-scrolling: touch;
      background: radial-gradient(circle at top, #0b1530 0%, #070A14 48%, #02060d 100%);
      transition: opacity 260ms ease, visibility 260ms ease;
    }
    #skyfinder-loader.hidden {
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
    }
    #skyfinder-loader canvas {
      position: fixed;
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
    }
    .skyfinder-loader-orbit {
      width: 86px;
      height: 86px;
      border-radius: 50%;
      border: 1px solid rgba(255,255,255,0.14);
      box-shadow: inset 0 0 18px rgba(152, 188, 255, 0.22), 0 0 34px rgba(111, 143, 255, 0.18);
      position: relative;
      animation: skyfinder-spin 1.8s linear infinite;
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
    /* The splash stops pretending to make progress once it has given up. */
    #skyfinder-loader.failed .skyfinder-loader-orbit,
    #skyfinder-loader.failed .skyfinder-loader-progress-wrap { display: none; }
    #skyfinder-loader-error[hidden] { display: none; }
    #skyfinder-loader-error {
      width: min(430px, 88vw);
      text-align: left;
      background: rgba(10, 16, 34, 0.92);
      border: 1px solid rgba(255,255,255,0.14);
      border-radius: 14px;
      padding: 14px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .skyfinder-err-title { font-size: 13.5px; font-weight: 700; color: #ffd9a0; }
    .skyfinder-err-hint {
      font-size: 11.5px;
      line-height: 1.6;
      color: rgba(223, 231, 255, 0.82);
    }
    #skyfinder-loader-detail {
      margin: 0;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 10px;
      line-height: 1.55;
      white-space: pre-wrap;
      word-break: break-word;
      max-height: 32vh;
      overflow: auto;
      -webkit-overflow-scrolling: touch;
      background: rgba(0,0,0,0.35);
      border-radius: 9px;
      padding: 9px;
      color: rgba(226, 234, 255, 0.9);
      user-select: text;
      -webkit-user-select: text;
    }
    .skyfinder-err-row { display: flex; flex-wrap: wrap; gap: 8px; }
    .skyfinder-err-btn {
      flex: 1 1 auto;
      min-width: 108px;
      font: inherit;
      font-size: 12px;
      font-weight: 600;
      padding: 10px;
      border-radius: 999px;
      cursor: pointer;
      border: 1px solid rgba(255,255,255,0.18);
      background: rgba(255,255,255,0.08);
      color: #eaf0ff;
      -webkit-appearance: none;
      appearance: none;
    }
    .skyfinder-err-btn.primary {
      background: #f0d98c;
      color: #141a2c;
      border-color: transparent;
    }
    @media (max-width: 480px) {
      .skyfinder-loader-shell { gap: 12px; }
      .skyfinder-loader-orbit { width: 72px; height: 72px; }
      .skyfinder-loader-title { font-size: 13px; }
      .skyfinder-loader-sub { font-size: 10px; }
    }
  </style>
'''

BODY_EXTRA = '''
  <div id="skyfinder-loader" aria-live="polite" aria-busy="true">
    <canvas id="skyfinder-loader-canvas" aria-hidden="true"></canvas>
    <div class="skyfinder-loader-shell">
      <div class="skyfinder-loader-orbit"></div>
      <div class="skyfinder-loader-title">ดาวนำทาง</div>
      <div id="skyfinder-loader-status" class="skyfinder-loader-sub">กำลังเริ่มระบบท้องฟ้า…</div>
      <div class="skyfinder-loader-progress-wrap">
        <div class="skyfinder-loader-progress-bar" aria-hidden="true">
          <div id="skyfinder-loader-progress-fill" class="skyfinder-loader-progress-fill"></div>
        </div>
        <div id="skyfinder-loader-progress-text" class="skyfinder-loader-progress-text">8%</div>
      </div>
      <div id="skyfinder-loader-error" hidden>
        <div class="skyfinder-err-title">เปิดแอปไม่สำเร็จ</div>
        <div class="skyfinder-err-hint">เครื่องนี้โหลดตัวเรนเดอร์กราฟิกของแอปไม่ขึ้น ลองล้างแคชแล้วเปิดใหม่ก่อน ถ้ายังไม่หาย กดคัดลอกรายละเอียดด้านล่างส่งให้ผู้พัฒนาได้เลย</div>
        <pre id="skyfinder-loader-detail"></pre>
        <div class="skyfinder-err-row">
          <button type="button" id="skyfinder-err-reset" class="skyfinder-err-btn primary">ล้างแคชแล้วลองใหม่</button>
          <button type="button" id="skyfinder-err-retry" class="skyfinder-err-btn">ลองใหม่</button>
          <button type="button" id="skyfinder-err-copy" class="skyfinder-err-btn">คัดลอกรายละเอียด</button>
        </div>
      </div>
    </div>
  </div>
  <script>
    (function () {
      var byId = function (id) { return document.getElementById(id); };
      var loader = byId('skyfinder-loader');
      var fill = byId('skyfinder-loader-progress-fill');
      var text = byId('skyfinder-loader-progress-text');
      var status = byId('skyfinder-loader-status');
      var canvas = byId('skyfinder-loader-canvas');
      var panel = byId('skyfinder-loader-error');
      var detail = byId('skyfinder-loader-detail');
      if (!loader || !fill || !text || !status || !panel || !detail) return;

      var isMobile = window.innerWidth < 768 ||
        /Mobile|iPhone|iPad|iPod|Android/.test(navigator.userAgent);
      // Engine start is a wasm download plus a compile. A cold 4G phone can
      // genuinely need twenty seconds, so the deadline is generous; what it
      // must never do is wait forever and leave a frozen percentage on screen.
      var DEADLINE = isMobile ? 28000 : 16000;

      var problems = [];
      var record = function (what) {
        var line = String(what);
        if (line.length > 300) line = line.slice(0, 300) + '…';
        if (problems.indexOf(line) === -1) problems.push(line);
      };

      // Capture phase, because a <script> or wasm fetch that 404s fires an
      // error event that does not bubble.
      window.addEventListener('error', function (e) {
        var t = e.target;
        if (t && t !== window && (t.src || t.href)) {
          record('โหลดไฟล์ไม่ขึ้น: ' + (t.src || t.href));
        } else if (e.message) {
          record(e.message + (e.filename ? ' @ ' + e.filename + ':' + e.lineno : ''));
        }
      }, true);

      window.addEventListener('unhandledrejection', function (e) {
        var r = e.reason;
        record('promise: ' + ((r && (r.message || r.toString())) || 'ไม่ทราบสาเหตุ'));
      });

      // ---- starfield -------------------------------------------------
      var starFrame = 0;
      var stopStars = function () {
        if (starFrame) cancelAnimationFrame(starFrame);
        starFrame = 0;
      };

      var drawStars = function () {
        var ctx = canvas.getContext('2d');
        if (!ctx) return;
        // The splash animation runs while the engine is compiling wasm on the
        // same thread, so it is deliberately cheap: a phone backing store at
        // full devicePixelRatio is three times the pixels for no visible gain
        // and real contention at exactly the wrong moment.
        var ratio = Math.min(isMobile ? 1.5 : 2, window.devicePixelRatio || 1);
        var count = isMobile ? 60 : 110;
        var w = window.innerWidth;
        var h = window.innerHeight;
        var stars = [];
        for (var i = 0; i < count; i++) {
          stars.push({
            x: Math.random() * w,
            y: Math.random() * h,
            r: Math.random() * 1.9 + 0.6,
            a: Math.random() * 0.8 + 0.25,
            vx: (Math.random() - 0.5) * 0.12,
            vy: (Math.random() - 0.5) * 0.12
          });
        }
        var resize = function () {
          w = window.innerWidth;
          h = window.innerHeight;
          canvas.width = Math.floor(w * ratio);
          canvas.height = Math.floor(h * ratio);
          canvas.style.width = w + 'px';
          canvas.style.height = h + 'px';
          ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
        };
        var render = function (time) {
          if (document.hidden) { starFrame = requestAnimationFrame(render); return; }
          ctx.clearRect(0, 0, w, h);
          for (var j = 0; j < stars.length; j++) {
            var s = stars[j];
            s.x += s.vx;
            s.y += s.vy;
            if (s.x < -8) s.x = w + 8;
            if (s.x > w + 8) s.x = -8;
            if (s.y < -8) s.y = h + 8;
            if (s.y > h + 8) s.y = -8;
            var alpha = s.a + Math.sin(time * 0.0012 + s.x * 0.03) * 0.3;
            ctx.beginPath();
            ctx.fillStyle = 'rgba(255,255,255,' + Math.min(1, Math.max(0.12, alpha)) + ')';
            ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
            ctx.fill();
          }
          starFrame = requestAnimationFrame(render);
        };
        resize();
        window.addEventListener('resize', resize, { passive: true });
        starFrame = requestAnimationFrame(render);
      };

      // ---- diagnostics -----------------------------------------------
      var describeGl = function () {
        try {
          var c = document.createElement('canvas');
          if (c.getContext('webgl2')) return 'webgl2';
          if (c.getContext('webgl')) return 'webgl1';
          return 'ไม่รองรับ';
        } catch (e) {
          return 'error: ' + e.message;
        }
      };

      var diagnostics = function () {
        var lines = [];
        lines.push('ดาวนำทาง · รายงานการเปิดแอป');
        lines.push('เวลา: ' + new Date().toString());
        lines.push('ที่อยู่: ' + location.href);
        lines.push('UA: ' + navigator.userAgent);
        lines.push('จอ: ' + window.innerWidth + 'x' + window.innerHeight +
          ' @' + (window.devicePixelRatio || 1));
        lines.push('ออนไลน์: ' + navigator.onLine);
        lines.push('WebAssembly: ' + (typeof WebAssembly !== 'undefined' ? 'รองรับ' : 'ไม่รองรับ'));
        lines.push('WebGL: ' + describeGl());
        lines.push('standalone: ' + !!(navigator.standalone === true ||
          (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches)));
        lines.push('อยู่บนหน้าจอมา: ' + Math.round(elapsed / 1000) + ' วินาที');
        if (problems.length) {
          lines.push('ข้อผิดพลาดที่จับได้:');
          for (var i = 0; i < problems.length && i < 8; i++) {
            lines.push('  • ' + problems[i]);
          }
        } else {
          lines.push('ข้อผิดพลาด: ไม่มีที่จับได้ (เอนจินเงียบไปเฉย ๆ)');
        }
        return lines.join('\\n');
      };

      // ---- progress ---------------------------------------------------
      var phases = [
        'กำลังเริ่มระบบท้องฟ้า…',
        'โหลดตัวเรนเดอร์กราฟิก…',
        'เตรียมข้อมูลดาว…',
        'คำนวณตำแหน่งดาว…',
        'ใกล้พร้อมแล้ว…'
      ];
      var settled = false;
      var elapsed = 0;
      var last = Date.now();
      var shown = 8;

      // An engine that painted without firing the event must not be buried
      // under an error panel, so the deadline checks the DOM before giving up.
      var enginePainted = function () {
        return !!(document.querySelector('flutter-view') ||
          document.querySelector('flt-glass-pane') ||
          document.querySelector('flt-scene-host'));
      };

      var hide = function () {
        loader.classList.add('hidden');
        window.setTimeout(function () {
          if (loader.parentNode) loader.parentNode.removeChild(loader);
        }, 340);
      };

      var succeed = function () {
        if (settled) return;
        settled = true;
        window.clearInterval(ticker);
        stopStars();
        fill.style.width = '100%';
        text.textContent = '100%';
        status.textContent = 'พร้อมแสดงฟ้า…';
        loader.setAttribute('aria-busy', 'false');
        window.setTimeout(hide, 420);
      };

      var giveUp = function () {
        if (settled) return;
        if (enginePainted()) { succeed(); return; }
        settled = true;
        window.clearInterval(ticker);
        stopStars();
        loader.classList.add('failed');
        loader.setAttribute('aria-busy', 'false');
        status.textContent = 'เปิดแอปไม่สำเร็จ';
        detail.textContent = diagnostics();
        panel.hidden = false;
      };

      var ticker = window.setInterval(function () {
        if (settled) return;
        var now = Date.now();
        var delta = now - last;
        last = now;
        // A gap this large means the tab was backgrounded or the phone slept,
        // not that the engine spent that long working, so it does not count
        // against the deadline. Without this, locking the screen during a
        // cold start would reliably produce a false failure.
        if (delta < 8000) elapsed += delta;

        var ratio = Math.min(1, elapsed / DEADLINE);
        var want = Math.min(96, Math.round(8 + ratio * 88));
        if (want > shown) {
          shown = want;
          fill.style.width = shown + '%';
          text.textContent = shown + '%';
        }
        var idx = Math.min(phases.length - 1, Math.floor(ratio * phases.length));
        if (status.textContent !== phases[idx]) status.textContent = phases[idx];

        if (enginePainted()) { succeed(); return; }
        if (ratio >= 1) giveUp();
      }, 120);

      window.addEventListener('flutter-first-frame', succeed, { once: true });

      // ---- recovery ---------------------------------------------------
      var hardReset = function () {
        var done = function () { location.reload(); };
        var jobs = [];
        try {
          if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
            jobs.push(navigator.serviceWorker.getRegistrations().then(function (regs) {
              return Promise.all(regs.map(function (r) { return r.unregister(); }));
            }));
          }
        } catch (e) { /* nothing to unregister */ }
        try {
          if (window.caches && caches.keys) {
            jobs.push(caches.keys().then(function (keys) {
              return Promise.all(keys.map(function (k) { return caches.delete(k); }));
            }));
          }
        } catch (e) { /* no cache storage */ }
        if (!jobs.length) { done(); return; }
        Promise.all(jobs).then(done, done);
      };

      var reset = byId('skyfinder-err-reset');
      var retry = byId('skyfinder-err-retry');
      var copy = byId('skyfinder-err-copy');
      if (reset) reset.addEventListener('click', function () {
        reset.textContent = 'กำลังล้าง…';
        hardReset();
      });
      if (retry) retry.addEventListener('click', function () { location.reload(); });
      if (copy) copy.addEventListener('click', function () {
        var say = function (msg) {
          copy.textContent = msg;
          window.setTimeout(function () { copy.textContent = 'คัดลอกรายละเอียด'; }, 1800);
        };
        try {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(detail.textContent).then(
              function () { say('คัดลอกแล้ว'); },
              function () { say('กดค้างที่ข้อความเพื่อคัดลอก'); });
            return;
          }
        } catch (e) { /* fall through to manual selection */ }
        try {
          var range = document.createRange();
          range.selectNodeContents(detail);
          var sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);
          say('เลือกข้อความแล้ว กดคัดลอก');
        } catch (e2) {
          say('กดค้างที่ข้อความเพื่อคัดลอก');
        }
      });

      if (!(window.matchMedia &&
            window.matchMedia('(prefers-reduced-motion: reduce)').matches)) {
        drawStars();
      }
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
    r'[ \t]*<meta name="viewport"[^>]*>\n?',
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
    s = s.replace('</head>', '  ' + HEAD_EXTRA + '</head>', 1)

    # Straight after the opening body tag, so the splash's error handlers are
    # listening before Flutter's async bootstrap script gets a chance to run.
    body = re.search(r'<body[^>]*>', s)
    if body is None:
        raise SystemExit(f'{path}: no <body>, cannot add the splash')
    s = s[:body.end()] + '\n' + BODY_EXTRA + s[body.end():]

    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(s)
    print('   index.html patched')


if __name__ == '__main__':
    main(sys.argv[1])
