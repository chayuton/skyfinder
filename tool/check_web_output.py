#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check that the built web output is actually ours and installable.

A Flutter web build succeeds whether or not the overlay was applied, so
without this a deploy could go out with Flutter's stock English page and
default icons and nothing would be red.
"""
import json
import os
import pathlib
import sys


def build_config(js: str) -> dict | None:
    """Pull the object assigned to _flutter.buildConfig out of the bootstrap.

    Brace matching rather than a regex, because the config carries a nested
    list of builds and a `.*?` would stop at the first inner brace while a
    greedy one would run to the end of the file.
    """
    marker = js.find('buildConfig')
    if marker == -1:
        return None
    start = js.find('{', marker)
    if start == -1:
        return None
    depth, in_string, escaped = 0, False, False
    for i in range(start, len(js)):
        ch = js[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(js[start:i + 1])
                except json.JSONDecodeError:
                    return None
    return None


def main(out_dir: str) -> int:
    out = pathlib.Path(out_dir)
    problems = []
    warnings = []
    checks = []

    def need(path: str) -> pathlib.Path | None:
        p = out / path
        if not p.exists():
            problems.append(f'missing {path}')
            return None
        checks.append(f'{path} present ({p.stat().st_size} bytes)')
        return p

    index = need('index.html')
    manifest = need('manifest.json')
    need('flutter_bootstrap.js')
    need('main.dart.js')
    need('favicon.png')
    for icon in ('icons/icon-192.png', 'icons/icon-512.png',
                 'icons/icon-maskable-512.png', 'icons/apple-touch-icon-180.png'):
        need(icon)

    if index is not None:
        html = index.read_text(encoding='utf-8')
        for needle, why in [
            ('width=device-width', 'a mobile viewport, without which every MediaQuery width is the browser fallback'),
            ('<title>ดาวนำทาง</title>', 'Thai title'),
            ('apple-mobile-web-app-title', 'iOS home-screen metadata'),
            ('theme-color', 'theme colour'),
            ('lang="th"', 'Thai language attribute'),
            ('#070A14', 'dark first paint'),
            ('flutter_bootstrap.js', "Flutter's own loader still intact"),
        ]:
            if needle in html:
                checks.append(f'index.html carries {why}')
            else:
                problems.append(f'index.html lost {why} ({needle!r})')
        if 'A new Flutter project' in html:
            problems.append('index.html still has the stock Flutter description')

    boot = out / 'flutter_bootstrap.js'
    if boot.exists():
        js = boot.read_text(encoding='utf-8', errors='replace')
        # Without --no-web-resources-cdn the page ships only an engine
        # revision and the loader turns that into a www.gstatic.com URL it
        # fetches before it can paint anything. Any device that cannot reach
        # that host sits on the splash forever while the build looks fine
        # everywhere else, so a deploy that would do it fails here instead.
        #
        # The flag has to be read out of the build config rather than looked
        # for in the file. Flutter's own loader contains the source line
        # `e.engineRevision && !e.useLocalCanvasKit`, so a plain substring
        # test for the name matches every build ever produced and passes
        # exactly when it should be failing.
        cfg = build_config(js)
        # Whether the build script was able to ask for a local CanvasKit at
        # all. An SDK too old to know the flag is a thing to warn about, not
        # a reason to block the deploy: the rest of this release -- the cache
        # headers and a splash that can report its own failure -- is worth
        # shipping either way. A flag that was passed and did not take effect
        # is a different matter, and fails.
        expected = os.environ.get('SKYFINDER_EXPECT_LOCAL_CANVASKIT') == '1'
        if cfg is None:
            problems.append('cannot find _flutter.buildConfig in '
                            'flutter_bootstrap.js, so the CanvasKit source '
                            'cannot be verified')
        elif cfg.get('useLocalCanvasKit') is True:
            checks.append('CanvasKit is served from our own origin')
        elif expected:
            problems.append(
                'the build ran with --no-web-resources-cdn but the build '
                'config still does not set useLocalCanvasKit, so the engine '
                'will fetch CanvasKit from www.gstatic.com at runtime and the '
                'app will not start on any device that cannot reach it')
        else:
            warnings.append(
                'this SDK could not be asked for a local CanvasKit, so the '
                'engine will fetch it from www.gstatic.com at runtime and the '
                'app will not start on any device that cannot reach it')
        for name in ('canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm'):
            need(name)

    if index is not None:
        head, _, rest = html.partition('</head>')
        if 'id="skyfinder-loader"' in head:
            problems.append(
                'the splash markup sits inside <head>, which makes the parser '
                'close the head early and discard the real <body> tag')
        elif 'id="skyfinder-loader"' in rest:
            checks.append('splash markup is in the body where it belongs')
        else:
            problems.append('index.html has no splash markup at all')
        if 'skyfinder-loader-detail' in html:
            checks.append('splash can report a failed engine start')
        else:
            problems.append('splash has no failure reporting, so a dead engine '
                            'will look like a frozen progress bar')

    if manifest is not None:
        try:
            m = json.loads(manifest.read_text(encoding='utf-8'))
        except json.JSONDecodeError as e:
            problems.append(f'manifest.json is not valid JSON: {e}')
        else:
            if m.get('name', '').startswith('ดาวนำทาง'):
                checks.append('manifest names the app in Thai')
            else:
                problems.append(f'manifest name is {m.get("name")!r}')
            if m.get('display') == 'standalone':
                checks.append('manifest asks for standalone display')
            else:
                problems.append('manifest is not standalone, so it will not '
                                'install to the home screen')
            purposes = {i.get('purpose') for i in m.get('icons', [])}
            if 'maskable' in purposes:
                checks.append('manifest has a maskable icon for Android')
            else:
                problems.append('manifest has no maskable icon')

    print('=== web output check ===')
    for c in checks:
        print('  ok   ' + c)
    for w in warnings:
        print('  WARN ' + w)
    for p in problems:
        print('  FAIL ' + p)
    if problems:
        print(f'\n{len(problems)} problem(s) with the built web output')
        return 1
    print(f'\nall {len(checks)} checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'build/web'))
