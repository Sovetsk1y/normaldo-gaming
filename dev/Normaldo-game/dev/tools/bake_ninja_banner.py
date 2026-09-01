#!/usr/bin/env python3
"""Собирает титр «BOSS FIGHT» для Ноги Ниндзя из авторского листа крокодила.

У боссов ОДИН титр на всех, и меняется в нём только лицо в букве O. В старом
проекте нарисованы два: `BOSSFIGHT LH.png` (крокодил) и `BOSSFIGHT FA.png`
(хозяин клуба). Ниндзя своего не досталось, а набирать его шрифтом — значит
выбить его из ряда: у двоих рисунок, у третьего надпись.

Поэтому титр собирается: берётся лист крокодила, внутренность круга заливается
чёрным, и в неё вставляется голова ноги ниндзя. КОЛЬЦО И ШИПЫ буквы O при этом
остаются нетронутыми — заливается ровно круг, а не прямоугольник вокруг морды.

Геометрия круга снята с увеличенного листа: центр (586, 240), радиус 79.

    python3 dev/tools/bake_ninja_banner.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT.parent / 'legacy' / 'normaldo_gaming' / 'assets' / 'images' / 'bosses'
OUT = ROOT / 'assets' / 'bosses' / 'ninja_foot' / 'banner.png'

CX, CY, R = 586, 240, 79
FILL = 0.94   # какую долю круга занимает голова

if __name__ == '__main__':
    banner = Image.open(SRC / 'BOSSFIGHT LH.png').convert('RGBA')
    ImageDraw.Draw(banner).ellipse((CX - R, CY - R, CX + R, CY + R),
                                   fill=(0, 0, 0, 255))
    head = Image.open(SRC / 'ninja foot1.png').convert('RGBA')
    head = head.crop(head.split()[3].getbbox())
    k = (R * 2 * FILL) / max(head.size)
    head = head.resize((max(1, round(head.width * k)),
                        max(1, round(head.height * k))), Image.LANCZOS)
    banner.alpha_composite(head, (CX - head.width // 2, CY - head.height // 2))
    banner.save(OUT)
    print(f'{OUT.name}: голова {head.size[0]}×{head.size[1]} в круге r={R}')
