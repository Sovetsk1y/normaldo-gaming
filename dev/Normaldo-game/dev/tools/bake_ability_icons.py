#!/usr/bin/env python3
"""Иконки для кружков способностей: поворот и обрезка по рисунку.

Кружок вписывает ТЕКСТУРУ ЦЕЛИКОМ, вместе с прозрачными полями. Если рисунок
сидит в холсте не по центру, картинка в кружке выходит мелкой и съезжает к краю
— а под ней остаётся открытой подсветка и читается как цветной шар. Поэтому
холст обрезается по самому рисунку и кладётся в квадрат по центру.

Поворот — из той же оперы, но про смысл: батаранг нарисован лежащим набок, и в
кружке его не узнать; повёрнутый, он встаёт классической эмблемой.

Пропорции рисунка не трогаются — меняется только то, как он стоит внутри своей
картинки.

    python3 dev/tools/bake_ability_icons.py
"""
from PIL import Image
import pathlib

PAD = 0.04          # поле по краям, долей от стороны

# исходник → (результат, поворот в градусах против часовой)
JOBS = [
    ("assets/skills/pirate/flag.png",   "assets/skills/pirate/flag_icon.png",   0),
    ("assets/skills/batman/throw.png",  "assets/skills/batman/throw_icon.png", 90),
]

for src, dst, angle in JOBS:
    im = Image.open(src).convert("RGBA")
    if angle:
        im = im.rotate(angle, expand=True, resample=Image.BICUBIC)
    box = im.getbbox()
    if box is None:
        raise SystemExit(f"в {src} нет непрозрачных пикселей")
    art = im.crop(box)
    side = int(max(art.size) * (1.0 + PAD * 2.0))
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(art, ((side - art.width) // 2, (side - art.height) // 2), art)
    out.save(dst)
    print(f"{src} → {dst} {out.size}, поворот {angle}°, рисунок {art.size}")
