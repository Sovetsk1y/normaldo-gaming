#!/usr/bin/env python3
"""Иконка флага для кружка способности пирата.

flag.png — рисунок на квадратном холсте 1000×1000, но сам флаг занимает в нём
широкую полосу и сидит ВЫШЕ центра: прозрачные поля сверху и снизу не равны.
Кружок способности вписывает ТЕКСТУРУ ЦЕЛИКОМ, вместе с полями, — поэтому флаг
получался мелким и съезжал в верхний угол, оставляя подсветку открытой, и она
читалась как синий шар с чёрной кляксой сбоку.

Здесь холст обрезается по самому рисунку и заново кладётся в квадрат по центру,
с небольшим полем. Пропорции флага не трогаются — меняется только то, где он
стоит внутри своей картинки.

    python3 dev/tools/bake_pirate_flag.py
"""
from PIL import Image
import pathlib

SRC = pathlib.Path("assets/skills/pirate/flag.png")
DST = pathlib.Path("assets/skills/pirate/flag_icon.png")
PAD = 0.04          # поле по краям, долей от стороны

im = Image.open(SRC).convert("RGBA")
box = im.getbbox()
if box is None:
    raise SystemExit("во flag.png нет непрозрачных пикселей")
art = im.crop(box)
side = int(max(art.size) * (1.0 + PAD * 2.0))
out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
out.paste(art, ((side - art.width) // 2, (side - art.height) // 2), art)
out.save(DST)
print(f"{SRC} {im.size} → {DST} {out.size}, рисунок {art.size}")
