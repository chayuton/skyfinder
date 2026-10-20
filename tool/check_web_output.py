#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check that the built web output is actually ours and installable.

A Flutter web build succeeds whether or not the overlay was applied, so
without this a deploy could go out with Flutter's stock English page and
default icons and nothing would be red.
"""
import json
import pathlib
import sys


def main(out_dir: str) -> int:
    out = pathlib.Path(out_dir)
    problems = []
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
    for p in problems:
        print('  FAIL ' + p)
    if problems:
        print(f'\n{len(problems)} problem(s) with the built web output')
        return 1
    print(f'\nall {len(checks)} checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'build/web'))
