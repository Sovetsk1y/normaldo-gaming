#!/usr/bin/env python3
"""Режет нарисованную полосу уровня на куски 645×430 → assets/backgrounds/levelN/.

Зачем резать. Полосы уровней в старом проекте — одна длинная картинка на весь
уровень: от 7 до 27 тысяч пикселей в ширину. Загрузить такую текстуру целиком
нельзя: предел размера текстуры на мобильных GLES3 — 4096, а на многих
устройствах и того меньше. Поэтому полоса режется на куски высотой во весь
вьюпорт и проигрывается по порядку (см. scripts/background.gd).

Ширина куска 645 выбрана не из красоты: это чуть больше двух третей экрана
(960), то есть на экране всегда лежат два-три куска, и подмена уехавшего за
левый край происходит вне поля зрения.

Порядок кусков ОБЯЗАТЕЛЕН и задаётся именем файла: у соседей сходятся кладка,
линия пола и рисунок, и перемешать их значит получить ступеньки на швах.

    python3 dev/tools/slice_level_bg.py            # нарезать уровни 2..5
    python3 dev/tools/slice_level_bg.py 3          # только третий
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT.parent / 'legacy' / 'normaldo_gaming' / 'assets' / 'images' / 'backgrounds'
OUT = ROOT / 'assets' / 'backgrounds'

SLICE_W = 645
SLICE_H = 430

# Имена в старом проекте разнобойные — часть строчными, часть капсом с пробелом.
SOURCES = {
    1: 'level1.png',
    2: 'level2.png',
    3: 'LEVEL 3.png',
    4: 'LEVEL 4.png',
    5: 'LEVEL 5.png',
}


def slice_level(n: int) -> int:
    src = SRC / SOURCES[n]
    im = Image.open(src).convert('RGBA')
    if im.height != SLICE_H:
        raise SystemExit(f'{src.name}: высота {im.height}, ожидалась {SLICE_H}')
    out_dir = OUT / f'level{n}'
    out_dir.mkdir(parents=True, exist_ok=True)
    # Хвост короче куска ОТБРАСЫВАЕТСЯ: обрезок в двести пикселей, вставленный
    # в цикл, читается как рывок картинки, а не как продолжение стены.
    count = im.width // SLICE_W
    for i in range(count):
        part = im.crop((i * SLICE_W, 0, (i + 1) * SLICE_W, SLICE_H))
        part.save(out_dir / f'level{n}_{i + 1:02d}.png')
    print(f'level{n}: {im.width}px → {count} кусков (хвост {im.width % SLICE_W}px отброшен)')
    return count


if __name__ == '__main__':
    args = [int(a) for a in sys.argv[1:]] or [2, 3, 4, 5]
    for n in args:
        slice_level(n)
