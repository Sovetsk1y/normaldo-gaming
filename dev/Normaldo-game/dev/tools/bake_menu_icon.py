#!/usr/bin/env python3
"""Собирает иконку кнопки главного меню: рисунок на фиолетовой шайбе.

Зачем скрипт, а не «нарисовать в редакторе». Кнопок в меню шесть, и шайба у них
обязана быть ОДНА И ТА ЖЕ: разъехавшийся на пиксель круг или чуть другой ореол
в ряду из четырёх кнопок читается как брак. Часть иконок пришла готовой (СЛОТЫ),
часть собирается здесь из голого рисунка — и шайба должна совпасть с точностью
до пикселя. Поэтому её геометрия и цвета не выдуманы, а СНЯТЫ ЗАМЕРОМ с готовых
иконок из набора автора (`SlotsButton.png` и остальные):

    кадр            55×55, центр (27, 27)
    тёмная заливка  d <= 15.5      #000000 при alpha 191
    кольцо          15.5 < d <= 17.5   #5704EF, alpha 255
    ореол           d > 17.5       #3C02A6 со спадом альфы GLOW (замер по кольцу)

Рисунок кладётся в квадрат ART_PX по длинной стороне и центрируется по кругу —
у авторских иконок он занимает 31–35 px, то есть немного заходит на кольцо.

Использование:
    python3 dev/tools/bake_menu_icon.py <исходник.png> <результат.png>
    python3 dev/tools/bake_menu_icon.py --all      # пересобрать весь набор
"""
import sys
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / 'dev' / 'art' / 'menu_icons'
OUT_DIR = ROOT / 'assets' / 'ui' / 'menu' / 'icons'

SIZE = 55
CENTER = 27.0
R_FILL = 15.5
R_RING = 17.5
ART_PX = 34.0

FILL = (0, 0, 0, 191)
RING = (0x57, 0x04, 0xEF, 255)
GLOW = (0x3C, 0x02, 0xA6)
# Спад альфы ореола по расстоянию от центра — замер по авторским иконкам
# (радиус: альфа). Между узлами линейно, дальше последнего — прозрачно.
GLOW_FALLOFF = [(17.5, 255), (18.0, 72), (19.0, 57), (20.0, 45),
                (21.0, 33), (22.0, 23), (23.0, 15), (24.0, 9), (25.0, 4), (26.0, 0)]

# Какой рисунок на какую кнопку и нужна ли ему обводка. Имя результата — это
# НАЗНАЧЕНИЕ кнопки, а не что нарисовано: иконку меняют, а константа в hud.gd
# остаётся на месте.
#
# Обводка — не украшение, а единственный способ показать ТЁМНЫЙ рисунок на почти
# чёрной шайбе: без неё чёрные гаечные ключи и тёмно-синяя шапочка читаются как
# дырка в круге. Так же решено и у автора набора: белый контур есть ровно у одной
# иконки — чёрной, — а у жёлтой короны и зелёной книги его нет и быть не должно,
# он бы съел их собственную обводку.
SET = {
    'settings.png':    ('fist.png',  1),   # НАСТРОЙКИ — чёрный рисунок
    'book.png':        ('book.png',  0),   # КНИГА УЧИТЕЛЯ
    'quests.png':      ('cap.png',   1),   # ЗАДАНИЯ — тёмно-синяя шапочка
    'skins.png':       ('skull.png', 0),   # СКИНЫ
    'leaderboard.png': ('crown.png', 0),   # ЛИДЕРЫ
}


def _glow_alpha(d: float) -> int:
    for i in range(len(GLOW_FALLOFF) - 1):
        r0, a0 = GLOW_FALLOFF[i]
        r1, a1 = GLOW_FALLOFF[i + 1]
        if r0 <= d <= r1:
            k = (d - r0) / (r1 - r0)
            return int(round(a0 + (a1 - a0) * k))
    return 0


# Шайба рисуется в SS раз крупнее и потом усредняется. Круг, посчитанный сразу в
# пикселе, даёт ступенчатое кольцо: у авторской иконки край кольца сглажен, и
# рядом с ней жёсткий круг читался бы как другая кнопка.
SS = 4


def make_plate() -> Image.Image:
    big = Image.new('RGBA', (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    px = big.load()
    for y in range(SIZE * SS):
        for x in range(SIZE * SS):
            fx = (x + 0.5) / SS - 0.5
            fy = (y + 0.5) / SS - 0.5
            d = ((fx - CENTER) ** 2 + (fy - CENTER) ** 2) ** 0.5
            if d <= R_FILL:
                px[x, y] = FILL
            elif d <= R_RING:
                px[x, y] = RING
            else:
                a = _glow_alpha(d)
                if a:
                    px[x, y] = (*GLOW, a)
    return big.resize((SIZE, SIZE), Image.BOX)


# Белый контур вокруг силуэта рисунка. Считается ПОСЛЕ уменьшения, по итоговым
# пикселям: обведённый в исходном разрешении контур после сжатия в пятнадцать раз
# превратился бы в серую кайму толщиной в полпикселя.
def _outline(art: Image.Image, w: int) -> Image.Image:
    pad = Image.new('RGBA', (art.width + 2 * w, art.height + 2 * w), (0, 0, 0, 0))
    pad.alpha_composite(art, (w, w))
    grown = pad.split()[3].filter(ImageFilter.MaxFilter(2 * w + 1))
    # Порог, а не мягкая кайма: полупрозрачный контур на тёмной шайбе снова
    # становится тёмным и не отделяет рисунок от фона.
    grown = grown.point(lambda p: 255 if p > 96 else 0)
    ring = Image.new('RGBA', pad.size, (255, 255, 255, 255))
    ring.putalpha(grown)
    ring.alpha_composite(pad)
    return ring


def bake(src: Path, out: Path, outline: int = 0) -> None:
    art = Image.open(src).convert('RGBA')
    bbox = art.split()[3].getbbox()
    if bbox is None:
        raise SystemExit(f'{src.name}: пустой рисунок')
    art = art.crop(bbox)
    # Обводка входит В ту же клетку: иначе обведённая иконка вырастала бы в ряду
    # относительно необведённых.
    k = (ART_PX - 2 * outline) / max(art.size)
    art = art.resize((max(1, round(art.width * k)), max(1, round(art.height * k))),
                     Image.LANCZOS)
    if outline:
        art = _outline(art, outline)
    icon = make_plate()
    icon.alpha_composite(art, (round(CENTER - art.width / 2),
                               round(CENTER - art.height / 2)))
    icon.save(out)
    print(f'{out.name}: {src.name} → {art.size[0]}×{art.size[1]} на шайбе {SIZE}×{SIZE}')


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == '--all':
        for dst, (src, outline) in SET.items():
            bake(SRC_DIR / src, OUT_DIR / dst, outline)
    elif len(sys.argv) in (3, 4):
        bake(Path(sys.argv[1]), Path(sys.argv[2]),
             int(sys.argv[3]) if len(sys.argv) == 4 else 0)
    else:
        raise SystemExit(__doc__)
