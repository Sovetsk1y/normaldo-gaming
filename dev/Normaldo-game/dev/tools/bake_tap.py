#!/usr/bin/env python3
"""Режет авторскую раскладку тапающего пальца и кладёт картинку «TAP!».

Исходники — в `dev/art/tap/`:

  tap.png            — надпись «TAP!» граффити, как в наборе выкриков.
  fingers_sheet.png  — раскладка 2×2: слева пара кадров ЛЕВОГО пальца, справа —
                       ПРАВОГО; сверху «поднят», снизу «прижат» (молнии и
                       красный след удара).

Главное здесь — СОВМЕЩЕНИЕ кадров. Кадры нарисованы в разных местах своей
четверти, и если резать по содержимому, палец на подмене прыгает вбок и вверх.
Совмещаем по МАНЖЕТЕ: это единственная часть, которая при тапе стоит на месте,
всё остальное — сам палец и разлетающиеся молнии. Манжета берётся из верхней
четверти рисунка (молнии туда не достают): её верх и её середина по горизонтали
и есть якорь. Все четыре кадра выводятся на холст одного размера с якорем в
одной и той же точке — подмена получается без прыжка.

    python3 dev/tools/bake_tap.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'dev' / 'art' / 'tap'
OUT = ROOT / 'assets' / 'ui' / 'reactions'

ALPHA_MIN = 40
SPLIT_X = 500          # граница колонок раскладки
SPLIT_Y = 510          # граница рядов
CUFF_BAND = 0.25       # какую долю кадра сверху считать манжетой
ANCHOR = (0.5, 0.10)   # где якорь стоит на итоговом холсте


def _bbox(im, box):
    """Рамка непрозрачного в куске раскладки, в координатах всего листа."""
    part = im.crop(box)
    bb = part.split()[3].point(lambda v: 255 if v >= ALPHA_MIN else 0).getbbox()
    if bb is None:
        raise SystemExit('пустая четверть раскладки: %s' % (box,))
    return (box[0] + bb[0], box[1] + bb[1], box[0] + bb[2], box[1] + bb[3])


def _anchor(im, bb):
    """Верх и середина МАНЖЕТЫ — точка, которая при тапе стоит на месте."""
    top = bb[1]
    band = im.crop((bb[0], top, bb[2], top + max(1, int((bb[3] - top) * CUFF_BAND))))
    cb = band.split()[3].point(lambda v: 255 if v >= ALPHA_MIN else 0).getbbox()
    return (bb[0] + (cb[0] + cb[2]) / 2.0, top)


def bake_fingers():
    sheet = Image.open(SRC / 'fingers_sheet.png').convert('RGBA')
    W, H = sheet.size
    quads = {
        'l1': (0, 0, SPLIT_X, SPLIT_Y),
        'r1': (SPLIT_X, 0, W, SPLIT_Y),
        'l2': (0, SPLIT_Y, SPLIT_X, H),
        'r2': (SPLIT_X, SPLIT_Y, W, H),
    }
    frames = {}
    for key, box in quads.items():
        bb = _bbox(sheet, box)
        frames[key] = (bb, _anchor(sheet, bb))

    # Холст один на все кадры: он обязан вместить самый широкий и самый высокий
    # кадр относительно якоря, иначе молнии обрежутся именно на прижатом кадре.
    left = max(a[0] - bb[0] for bb, a in frames.values())
    right = max(bb[2] - a[0] for bb, a in frames.values())
    up = max(a[1] - bb[1] for bb, a in frames.values())
    down = max(bb[3] - a[1] for bb, a in frames.values())
    # Якорь стоит в ANCHOR холста — добираем поля до этой пропорции.
    w = int(max(left, right) * 2)
    h = int(max(down / (1.0 - ANCHOR[1]), up / ANCHOR[1]))
    ax, ay = int(w * ANCHOR[0]), int(h * ANCHOR[1])

    sizes = {}
    for key, (bb, a) in frames.items():
        canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        canvas.alpha_composite(sheet.crop(bb),
                               (int(ax - (a[0] - bb[0])), int(ay - (a[1] - bb[1]))))
        canvas.save(OUT / ('finger_%s.png' % key))
        sizes[key] = canvas.size
    return w, h


def bake_tap():
    tap = Image.open(SRC / 'tap.png').convert('RGBA')
    tap = tap.crop(tap.split()[3].getbbox())
    tap.save(OUT / 'tap.png')
    return tap.size


if __name__ == '__main__':
    print('tap.png     ', bake_tap())
    print('finger_*    ', bake_fingers())
