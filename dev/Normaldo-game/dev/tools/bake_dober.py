#!/usr/bin/env python3
"""Кадры добермана капитана — из присланных художником DOG1..DOG5.

Три из четырёх кадров берутся как есть. Четвёртый (`run`) ВЫВОДИТСЯ: собака,
сорвавшаяся с поводка, обязана лететь БЕЗ ЦЕПИ, а кадра «пасть закрыта и цепи
нет» среди присланных нет — есть «закрыта с цепью» (DOG1) и «раскрыта без
цепи» (DOG4).

Поэтому у DOG1 цепь стирается. Она нарисована отдельно от ошейника — белыми
звеньями выше и правее него, — и вырезается прямоугольником: ошейник со своими
шипами начинается ниже CHAIN_BOTTOM, голова кончается левее CHAIN_LEFT.

    python3 dev/tools/bake_dober.py <папка с DOG1..DOG5>
"""
import os
import sys
from PIL import Image

DST = "assets/bosses/police/dog"

# Прямоугольник цепи в кадре 600×600. Взят по рисунку: звенья идут от (455,100)
# до (568,155), верхний шип ошейника начинается на y≈170, ухо — левее x≈400.
CHAIN_LEFT   = 440
CHAIN_BOTTOM = 168

# Что откуда берётся и зачем оно нужно.
TAKE = [
    ("DOG1.png", "leashed.png", "у хозяина, на цепи, пасть закрыта"),
    ("DOG5.png", "strain.png",  "рвётся с цепи, пасть раскрыта"),
    ("DOG4.png", "bite.png",    "в броске, без цепи, пасть раскрыта"),
]


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = sys.argv[1]
    os.makedirs(DST, exist_ok=True)
    for name, out, why in TAKE:
        im = Image.open(os.path.join(src, name)).convert("RGBA")
        im.save(os.path.join(DST, out))
        print(f"{out:14s} ← {name}  ({why})")

    # `run` — DOG1 без цепи.
    im = Image.open(os.path.join(src, "DOG1.png")).convert("RGBA")
    px = im.load()
    cut = 0
    for y in range(0, CHAIN_BOTTOM):
        for x in range(CHAIN_LEFT, im.width):
            if px[x, y][3]:
                px[x, y] = (0, 0, 0, 0)
                cut += 1
    im.save(os.path.join(DST, "run.png"))
    print(f"{'run.png':14s} ← DOG1.png минус цепь ({cut} точек стёрто)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
