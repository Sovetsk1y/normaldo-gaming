#!/usr/bin/env python3
"""Pre-bake the Figma "Drop shadow blur 25 #28443B 100%" effect for every
btn_*.png in assets/ui/menu/ into a companion btn_*_glow.png.

Rationale: a runtime Gaussian-blur shader over a 430×192 canvas at 25-px radius
is too expensive (~hundreds of taps per fragment × 5 buttons × 60 fps). The
glow is visually static, so we bake it once. The PNG can be re-baked any time
the source button art changes by re-running this script.

Figma blur of 25 is specified at the *viewport* resolution (Figma frame ≈ game
window 960×430). Our menu canvas is 430×192, so 25 viewport-pixels ≈ 11 canvas
pixels. PIL GaussianBlur(radius=N) treats N as sigma.
"""
from PIL import Image, ImageFilter
from pathlib import Path

DIR = Path('/Users/proc/Developer/normaldo-gaming/dev/Normaldo-game/assets/ui/menu')
# Figma blur 25 in viewport-pixels (960×430) → ~11 in canvas-pixels, but the
# user wanted the halo trimmed to ~1/3 of that for a tighter, less hazy look.
SIGMA = 4.0
TINT = (0x28, 0x44, 0x3B, 255)   # #28443B
# Multiplier on blurred alpha. Lower = weaker halo. Halved from the original
# 1.6 by user request — current 0.8 gives a noticeably softer glow.
ALPHA_GAIN = 0.8

PATTERNS = ('btn_*.png', 'chapter*_mode_btn.png', 'endless_mode_btn.png')
files = []
for p in PATTERNS:
    files.extend(DIR.glob(p))
for png in sorted(set(files)):
    if png.stem.endswith('_glow') or 'aseprite_backup' in png.stem:
        continue
    img = Image.open(png).convert('RGBA')
    alpha = img.split()[3]
    blurred = alpha.filter(ImageFilter.GaussianBlur(radius=SIGMA))
    # Lift alpha so the halo isn't washed out.
    blurred = blurred.point(lambda p: min(255, int(p * ALPHA_GAIN)))
    glow = Image.new('RGBA', img.size, TINT)
    glow.putalpha(blurred)
    out = png.with_name(png.stem + '_glow.png')
    glow.save(out)
    print(f'baked: {out.name}')
