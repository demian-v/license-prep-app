"""Export the onboarding screenshots and their highlight rects for the Flutter app.

Usage:
    python3 design/onboarding/_src/export_onboarding_assets.py RAW_DIR [--only SCREEN[,SCREEN]]

RAW_DIR holds one folder per locale (en, es, pl, ru, uk), each with six iPhone 16 Pro
simulator captures (1206×2622, status bar overridden to 9:41):
    tests.png  tests_s.png  theory.png  theory_s.png  profile.png  profile_s.png
(`*_s` = the same tab scrolled down). For each locale this script
  1. stitches each pair without the trial card (see compose_shots.py),
  2. finds the cards and the tab bead from the pixels,
  3. writes assets/images/onboarding/<locale>/<screen>.webp (720 px wide), and
  4. regenerates lib/widgets/onboarding_shots.dart with the rects, in a
     360×783 space (the screenshot's width scaled to 360).
It also writes RAW_DIR/<locale>/check_<screen>.png with the rects drawn on, to eyeball.

`instructors.png` / `instructors_s.png` (added 2026-10-05) are captured as a PAID
student, so the page has no trial card and nothing is cut. `--only instructors`
exports just that screen and keeps every other screen's rects from the current
onboarding_shots.dart, so approved screenshots don't have to be re-shot.
"""
import re
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

from compose_shots import BG, CLIP, compose_array

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
ASSETS = os.path.join(ROOT, 'assets', 'images', 'onboarding')
DART = os.path.join(ROOT, 'lib', 'widgets', 'onboarding_shots.dart')
LOCALES = ['en', 'es', 'pl', 'ru', 'uk']
SCALE = 360 / 1206          # capture pixels -> onboarding space
SIGNAL = np.array([0, 72, 195], np.float32)


def is_content(px):
    """Card or text, not page: brighter than the page (a white card), or far from it
    (text, a blue or dark card). Card shadows are only slightly darker, so they don't count."""
    d = px - np.array(BG, np.float32)
    return (d.min(axis=-1) > 5) | (np.abs(d).max(axis=-1) > 30)


def content_runs(img, x0=40, x1=1166, y0=200, y1=CLIP):
    """Row runs that hold a card or a label."""
    rows = is_content(img[y0:y1, x0:x1]).any(axis=1)
    runs, start = [], None
    for i, on in enumerate(rows):
        if on and start is None:
            start = i
        if not on and start is not None:
            runs.append((y0 + start, y0 + i))
            start = None
    if start is not None:
        runs.append((y0 + start, y1))
    return runs


def kind(img, top, bottom):
    """white / blue / dark, sampled near the card's right edge (clear of its text)."""
    r, g, b = img[(top + bottom) // 2, 1110]
    if r > 245 and g > 245 and b > 245:
        return 'white'
    if b > 150 and r < 120:
        return 'blue'
    if r < 60 and g < 60 and b < 80:
        return 'dark'
    return 'other'


def cards(img):
    out = []
    for top, bottom in content_runs(img):
        if bottom - top < 150:
            continue  # a section label or a line of text, not a card
        xs = np.nonzero(is_content(img[(top + bottom) // 2]))[0]
        out.append({'kind': kind(img, top, bottom), 'x0': int(xs[0]), 'x1': int(xs[-1]) + 1, 'y0': top, 'y1': bottom})
    return out


def trial_cut(top_img):
    """Rows to drop: from under the status bar to just before the content after the trial card."""
    runs = content_runs(top_img)
    return 200, runs[1][0] - 10


def bead_rect(img, wide_label=False):
    zone = img[2310:2460, :]
    mask = np.abs(zone - SIGNAL).max(axis=2) < 40
    xs = np.nonzero(mask.any(axis=0))[0]
    cx = (xs[0] + xs[-1]) / 2 * SCALE
    if wide_label:
        # «Инструкторы» / «Instructors» is wider than the 62-pt bead: take the
        # blue label's own width too, or the ring cuts the word.
        label = np.abs(img[2470:2540, :] - SIGNAL).max(axis=2) < 60
        lx = np.nonzero(label.any(axis=0))[0]
        half = max(31, (cx - lx[0] * SCALE) + 6, ((lx[-1] + 1) * SCALE - cx) + 6)
        return (cx - half, 686, 2 * half, 76)
    return (cx - 31, 686, 62, 76)


def rect(c, pad_y=0):
    return (c['x0'] * SCALE, c['y0'] * SCALE - pad_y, (c['x1'] - c['x0']) * SCALE, (c['y1'] - c['y0']) * SCALE + 2 * pad_y)


def union(a, b):
    x0, y0 = min(a[0], b[0]), min(a[1], b[1])
    x1, y1 = max(a[0] + a[2], b[0] + b[2]), max(a[1] + a[3], b[1] + b[3])
    return (x0, y0, x1 - x0, y1 - y0)


def pick(screen, cs):
    """The highlighted elements per screen, by card kind and order."""
    whites = [c for c in cs if c['kind'] == 'white']
    if screen == 'tests':
        hero = next(c for c in cs if c['kind'] == 'blue')
        mist = next(c for c in cs if c['kind'] == 'dark')
        tiles = [c for c in whites if hero['y1'] <= c['y0'] < mist['y0']]
        return {'hero': rect(hero), 'tiles': union(rect(tiles[0]), rect(tiles[-1])), 'mistakes': rect(mist)}
    if screen == 'theory':
        return {'module': rect(whites[0])}
    if screen == 'instructors':
        # The first instructor card under the segments and «Фильтры» (both
        # are shorter than a card, so cards() skips them).
        return {'card': rect(whites[0])}
    if screen == 'profile':
        hero = next(c for c in cs if c['kind'] == 'blue')
        rows = [c for c in whites if c['y0'] >= hero['y1']][:2]
        return {'settings': union(rect(rows[0]), rect(rows[1]))}
    raise ValueError(screen)


SCREENS = ['tests', 'theory', 'instructors', 'profile']
NO_TRIAL_CARD = {'instructors'}


def existing_rects():
    """The rects in the current onboarding_shots.dart, as {locale: {screen: {key: rect}}}."""
    found, loc = {}, None
    for line in open(DART):
        m = re.match(r"  '(\w+)': \{", line)
        if m:
            loc = found.setdefault(m.group(1), {})
            continue
        m = re.match(r"    '(\w+)\.(\w+)': Rect\.fromLTWH\(([^)]*)\),", line)
        if m and loc is not None:
            loc.setdefault(m.group(1), {})[m.group(2)] = tuple(float(v) for v in m.group(3).split(','))
    return found


def export(raw_dir, only=None):
    found = existing_rects() if only else {}
    for loc in LOCALES:
        src = os.path.join(raw_dir, loc)
        if not os.path.isdir(src):
            continue
        found.setdefault(loc, {})
        os.makedirs(os.path.join(ASSETS, loc), exist_ok=True)
        for screen in only or ['tests', 'theory', 'profile']:
            top = os.path.join(src, f'{screen}.png')
            scrolled = os.path.join(src, f'{screen}_s.png')
            top_img = np.asarray(Image.open(top).convert('RGB')).astype(np.float32)
            cut = (200, 200) if screen in NO_TRIAL_CARD else trial_cut(top_img)
            page = compose_array(top, scrolled, *cut)
            rects = pick(screen, cards(page))
            rects['tab'] = bead_rect(page, wide_label=screen == 'instructors')
            found[loc][screen] = rects
            im = Image.fromarray(page.astype(np.uint8))
            im.resize((720, 1565), Image.LANCZOS).save(os.path.join(ASSETS, loc, f'{screen}.webp'), quality=82, method=6)
            chk = im.resize((360, 783), Image.LANCZOS)
            d = ImageDraw.Draw(chk)
            for r in rects.values():
                d.rectangle([r[0], r[1], r[0] + r[2], r[1] + r[3]], outline=(255, 0, 80), width=2)
            chk.save(os.path.join(src, f'check_{screen}.png'))
            print(loc, screen, 'cut', cut, {k: tuple(round(v) for v in r) for k, r in rects.items()})
    write_dart(found)


def write_dart(found):
    lines = [
        '// GENERATED by design/onboarding/_src/export_onboarding_assets.py. Do not edit by hand:',
        '// re-run the script after new screenshots.',
        '//',
        '// Highlight rects for the onboarding screenshots, in a 360×783 space (the',
        '// screenshot scaled to 360 wide). Keys: <screen>.<element>, screens tests /',
        '// theory / instructors / profile, element tab plus hero, tiles, mistakes,',
        '// module, card, settings.',
        "import 'dart:ui';",
        '',
        'const Size onboardingShotSize = Size(360, 783);',
        '',
        '/// Locales that have their own screenshots; others fall back to English.',
        f"const List<String> onboardingShotLocales = [{', '.join(repr(l) for l in found)}];",
        '',
        'const Map<String, Map<String, Rect>> onboardingShotRects = {',
    ]
    for loc, screens in found.items():
        lines.append(f"  '{loc}': {{")
        for screen in sorted(screens, key=SCREENS.index):
            rects = screens[screen]
            for key, (x, y, w, h) in rects.items():
                lines.append(f"    '{screen}.{key}': Rect.fromLTWH({x:.1f}, {y:.1f}, {w:.1f}, {h:.1f}),")
        lines.append('  },')
    lines.append('};')
    open(DART, 'w').write('\n'.join(lines) + '\n')
    print('wrote', DART)


if __name__ == '__main__':
    only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
    export(sys.argv[1], only)
