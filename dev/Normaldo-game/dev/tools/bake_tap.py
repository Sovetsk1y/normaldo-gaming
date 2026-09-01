#!/usr/bin/env python3
"""Собирает «TAP!» и два кадра тапающего пальца для мини-игры ЖИРОБОССА.

Зачем. В мини-игре по центру мигало СЛОВО «ТАПАЙ», набранное шрифтом, а по
бокам от него стояли стрелки «назад» из интерфейса заданий. Рядом с рисованной
мордой босса это читалось как отладочная подпись: у игры есть свой набор
комиксовых выкриков (POW, BAM, KEK, LOL, dang, oops), и подсказка обязана быть
из того же набора, а не из шрифта.

Что делается:

  tap.png       — «TAP!» в стиле выкриков: чёрная тень со сдвигом, жёлтая
                  обводка, розовая заливка со светлым бликом. Палитра снята
                  пиксельно с assets/ui/reactions/pow.png.
  finger_1.png  — палец из старого проекта (assets/images/finger.png), поднят.
  finger_2.png  — он же в НИЖНЕЙ точке: кисть подсажена и сплюснута, вокруг
                  подушечки — колечко удара. Два кадра плюс движение вниз и
                  дают тап: палец идёт вниз, в нижней точке меняется кадр.

Кадры пальца — ЗАГЛУШКА, собранная из того, что есть в проекте. Придут
авторские — заменить эти два файла, код читает их по имени и больше ничего о
них не знает.

    python3 dev/tools/bake_tap.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
LEGACY = ROOT.parent / 'legacy' / 'normaldo_gaming' / 'assets' / 'images'
OUT = ROOT / 'assets' / 'ui' / 'reactions'
FONT = ROOT / 'assets' / 'fonts' / 'RussoOne-Regular.ttf'

# Палитра выкриков, снята с pow.png.
INK    = (0, 0, 0, 255)
FILL   = (215, 123, 186, 255)
LIGHT  = (228, 168, 209, 255)
EDGE   = (251, 242, 54, 255)

TEXT = 'TAP!'
SIZE = 260              # кегль
SS = 3                  # сглаживание сверхвыборкой
SHADOW = (18, 20)       # сдвиг чёрной тени, в пикселях итогового размера
EDGE_W = 7              # толщина жёлтой обводки
INK_W = 5               # толщина чёрного контура букв


def _mask(text, font, w, h, pos):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).text(pos, text, font=font, fill=255)
    return m


def _grow(mask, px):
    """Расширить маску на px пикселей."""
    return mask.filter(ImageFilter.MaxFilter(px * 2 + 1)) if px > 0 else mask


def bake_tap():
    font = ImageFont.truetype(str(FONT), SIZE * SS)
    box = font.getbbox(TEXT)
    pad = (EDGE_W + INK_W) * SS + max(SHADOW) * SS + 8 * SS
    w = box[2] - box[0] + pad * 2
    h = box[3] - box[1] + pad * 2
    pos = (pad - box[0], pad - box[1])

    body = _mask(TEXT, font, w, h, pos)
    ink = _grow(body, INK_W * SS)
    edge = _grow(body, (INK_W + EDGE_W) * SS)

    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    # Тень — тот же силуэт с контуром, сдвинутый вниз-вправо.
    shadow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    shadow.paste(INK, (0, 0), ink)
    img.alpha_composite(shadow, (SHADOW[0] * SS, SHADOW[1] * SS))
    img.paste(EDGE, (0, 0), edge)
    img.paste(INK, (0, 0), ink)
    img.paste(FILL, (0, 0), body)
    # Блик — та же маска, поджатая и сдвинутая вверх-влево.
    hi = body.filter(ImageFilter.MinFilter(9 * SS // 2 * 2 + 1))
    hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hl.paste(LIGHT, (0, 0), hi)
    img.alpha_composite(hl, (-4 * SS, -5 * SS))
    img.paste(FILL, (0, 0), Image.new('L', (w, h), 0))   # no-op, читаемость

    img = img.resize((w // SS, h // SS), Image.LANCZOS)
    img = img.crop(img.split()[3].getbbox())
    img.save(OUT / 'tap.png')
    return img.size


def _drop_black_bg(im):
    """Убрать залитый чёрным фон заливкой от углов.

    В старом проекте палец лежит НЕ на прозрачном фоне, а на чёрном
    прямоугольнике — вставлять его как есть значит поставить рядом с боссом две
    чёрные плашки. Заливка идёт от углов и до контура рисунка, поэтому чёрная
    обводка внутри самого пальца остаётся на месте.
    """
    w, h = im.size
    px = im.load()
    seen = [[False] * h for _ in range(w)]
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[x][y]:
            continue
        r, g, b, a = px[x, y]
        if a > 0 and max(r, g, b) > 40:
            continue
        seen[x][y] = True
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def _outline(im, px, color):
    """Обвести рисунок по силуэту.

    Палец зелёный, и висит он рядом с зелёной головой Нормальдо — без обводки
    рука сливается с лицом ровно в тот момент, когда она и должна подсказывать.
    Цвет тот же жёлтый, что у выкриков: подсказка остаётся из одного набора.
    """
    a = im.split()[3].point(lambda v: 255 if v > 40 else 0)
    ring = _grow(a, px)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(color, (0, 0), ring)
    out.alpha_composite(im)
    return out


def bake_fingers():
    src = _drop_black_bg(Image.open(LEGACY / '3.0x' / 'finger.png').convert('RGBA'))
    src = src.crop(src.split()[3].getbbox())
    pad = max(src.size) // 12
    box = Image.new('RGBA', (src.width + pad * 2, src.height + pad * 2), (0, 0, 0, 0))
    box.alpha_composite(src, (pad, pad))
    src = _outline(box, pad // 2, EDGE)
    # Палец в старом проекте смотрит ВВЕРХ — он был указателем на кнопку сверху.
    # Тапают вниз, поэтому кадр переворачивается: подушечка ведёт движение.
    src = src.transpose(Image.FLIP_TOP_BOTTOM)
    src = src.crop(src.split()[3].getbbox())
    w, h = src.size
    pad = h // 5
    up = Image.new('RGBA', (w, h + pad), (0, 0, 0, 0))
    up.alpha_composite(src, (0, 0))
    up.save(OUT / 'finger_1.png')

    # Нижняя точка: кисть подсажена и сплюснута — палец «уперся».
    squash = src.resize((int(w * 1.06), int(h * 0.90)), Image.LANCZOS)
    down = Image.new('RGBA', (w, h + pad), (0, 0, 0, 0))
    down.alpha_composite(squash, ((w - squash.width) // 2, pad))
    # Колечко удара под подушечкой — она теперь внизу кадра.
    d = ImageDraw.Draw(down)
    cx = w // 2
    cy = pad + squash.height - int(h * 0.02)
    r = int(w * 0.34)
    d.ellipse((cx - r, cy - r // 3, cx + r, cy + r // 3),
              outline=EDGE, width=max(2, w // 40))
    down.save(OUT / 'finger_2.png')
    return up.size


if __name__ == '__main__':
    print('tap.png     ', bake_tap())
    print('finger_1/2  ', bake_fingers())
