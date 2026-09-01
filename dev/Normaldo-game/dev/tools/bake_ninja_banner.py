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

# ── Пицца на лбу ─────────────────────────────────────────────────────────────
# На лбу у ноги ниндзя нарисован ОТПЕЧАТОК СТОПЫ — знак, который в титре не
# читается: в круге буквы O он превращается в тёмное пятно и выглядит как
# дефект печати. В титре ниндзя должен носить ПИЦЦУ: она и опознаётся мгновенно,
# и говорит, за чем он пришёл.
#
# Отпечаток не стирается, а закрывается: пицца ставится поверх с запасом, и
# ставится ТОЛЬКО в титре — в забеге у босса остаётся его собственный лоб.
#
# Рамка отпечатка снята по сетке с самого спрайта, в долях кадра.
FOOT_BOX = (0.17, 0.04, 0.35, 0.155)
# Центр пиццы чуть ниже и правее центра отпечатка: у самого верха голова уже
# сужается, и пицца по центру рамки наполовину висела за силуэтом.
PIZZA_AT   = (0.28, 0.125)
PIZZA_OVER = 1.85    # во сколько раз пицца перекрывает отпечаток

if __name__ == '__main__':
    banner = Image.open(SRC / 'BOSSFIGHT LH.png').convert('RGBA')
    ImageDraw.Draw(banner).ellipse((CX - R, CY - R, CX + R, CY + R),
                                   fill=(0, 0, 0, 255))
    head = Image.open(SRC / 'ninja foot1.png').convert('RGBA')

    pizza = Image.open(ROOT / 'assets' / 'items' / 'pizza.png').convert('RGBA')
    pizza = pizza.crop(pizza.split()[3].getbbox())
    hw, hh = head.size
    fx0, fy0, fx1, fy1 = (FOOT_BOX[0] * hw, FOOT_BOX[1] * hh,
                          FOOT_BOX[2] * hw, FOOT_BOX[3] * hh)
    want = max(fx1 - fx0, fy1 - fy0) * PIZZA_OVER
    k = want / max(pizza.size)
    pizza = pizza.resize((max(1, round(pizza.width * k)),
                          max(1, round(pizza.height * k))), Image.LANCZOS)
    head.alpha_composite(pizza, (round(PIZZA_AT[0] * hw - pizza.width / 2),
                                 round(PIZZA_AT[1] * hh - pizza.height / 2)))

    head = head.crop(head.split()[3].getbbox())
    k = (R * 2 * FILL) / max(head.size)
    head = head.resize((max(1, round(head.width * k)),
                        max(1, round(head.height * k))), Image.LANCZOS)
    banner.alpha_composite(head, (CX - head.width // 2, CY - head.height // 2))
    banner.save(OUT)
    print(f'{OUT.name}: голова {head.size[0]}×{head.size[1]} в круге r={R}')
