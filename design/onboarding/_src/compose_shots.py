"""Stitch two simulator screenshots of one tab into an onboarding screenshot without the trial card.

Usage:
    python3 compose_shots.py TOP.png SCROLLED.png CUT_FROM CUT_TO OUT.jpg

TOP.png       the tab at scroll 0 (iPhone 16 Pro, 1206×2622, status bar 9:41 via
              `xcrun simctl status_bar booted override --time 9:41 ...`)
SCROLLED.png  the same tab scrolled down, so the content below the fold is known
CUT_FROM/TO   rows (in 1206-wide pixels) to remove; the trial card is 200..~670
              (Tests 200 700, Theory 200 669, Profile 200 668 on 2026-09-29)
OUT.jpg       720×1565 JPEG for shots/

The status-bar strip (rows 0..200, including the DEBUG ribbon) is painted with the
page background; the page draws its own status bar on top. Everything from the
scroll clip (row 2304) down, i.e. the floating tab bar, is kept from TOP.png.
"""
import sys
import numpy as np
from PIL import Image

CLIP = 2304            # first row below the scroll viewport (the tab bar zone)
BG = (242, 244, 248)   # AppColors.field, #F2F4F8


def load(path):
    return np.asarray(Image.open(path).convert('RGB')).astype(np.float32)


def offset(top, scrolled):
    """Scroll distance between the two captures, by matching a band of rows."""
    band = scrolled[400:470]
    best = (float('inf'), 0)
    for d in range(0, CLIP - 870):
        err = float(np.mean((top[400 + d:470 + d] - band) ** 2))
        if err < best[0]:
            best = (err, d)
    return best


def compose_array(top_path, scrolled_path, cut_from, cut_to):
    """The stitched page at full capture size (float32 RGB), trial card removed."""
    top, scrolled = load(top_path), load(scrolled_path)
    height, width, _ = top.shape
    err, d = offset(top, scrolled)
    if err > 50:
        print(f'warning: {top_path}: weak scroll match (error {err:.1f})')
    bg_row = np.tile(np.array(BG, np.float32), (width, 1))

    def page(y):
        if y < CLIP:
            return top[y]
        if y - d < CLIP:
            return scrolled[y - d]
        return bg_row

    cut = cut_to - cut_from
    out = np.zeros_like(top)
    for y in range(height):
        if y < 200:
            out[y] = bg_row
        elif y < CLIP:
            out[y] = page(y + cut)
        else:
            out[y] = top[y]
    return out


def compose(top_path, scrolled_path, cut_from, cut_to, out_path):
    out = compose_array(top_path, scrolled_path, cut_from, cut_to)
    Image.fromarray(out.astype(np.uint8)).resize((720, 1565), Image.LANCZOS).save(out_path, quality=86)


if __name__ == '__main__':
    a, b, c0, c1, o = sys.argv[1:6]
    compose(a, b, int(c0), int(c1), o)
