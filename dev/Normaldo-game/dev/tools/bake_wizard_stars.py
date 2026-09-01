#!/usr/bin/env python3
"""Режет магические звёзды мага из авторских листов на три отдельных снаряда.

В архиве `assets/skills/wizard/magicball2..4.png` — это НЕ четыре кадра одной
анимации, а ЛИСТЫ: в каждом по шесть рисунков, три ряда на две колонки. Ряды —
это три РАЗНЫХ снаряда (синяя звезда, жёлтая звезда, розовый дротик), колонки —
чистый рисунок и он же со смазом движения.

Код грузил лист целиком и отправлял в полёт всю шестёрку сразу: на экране летели
три звезды с хвостами вместо одной. Плюс масштаб считался по ширине ЛИСТА, из-за
чего каждая звезда выходила втрое мельче задуманного.

Здесь берётся ЛЕВАЯ (чистая) колонка: смаз в игре не нужен — снаряд крутится
сам, и нарисованный хвост при вращении читается как мусор вокруг звезды.

    python3 dev/tools/bake_wizard_stars.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / 'assets' / 'skills' / 'wizard'
SHEET = 'magicball2.png'     # лист, с которого берём чистую колонку
ALPHA_MIN = 40
MIN_AREA = 200


def blobs(im):
    W, H = im.size
    a = im.split()[3].load()
    seen = [[False] * H for _ in range(W)]
    out = []
    for sx in range(W):
        for sy in range(H):
            if seen[sx][sy] or a[sx, sy] < ALPHA_MIN:
                continue
            stack = [(sx, sy)]
            seen[sx][sy] = True
            x0 = x1 = sx
            y0 = y1 = sy
            area = 0
            while stack:
                x, y = stack.pop()
                area += 1
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                               (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[nx][ny] \
                            and a[nx, ny] >= ALPHA_MIN:
                        seen[nx][ny] = True
                        stack.append((nx, ny))
            if area >= MIN_AREA:
                out.append((x0, y0, x1 + 1, y1 + 1))
    return out


if __name__ == '__main__':
    sheet = Image.open(DIR / SHEET).convert('RGBA')
    found = blobs(sheet)
    if len(found) != 6:
        raise SystemExit('ожидалось 6 рисунков на листе, найдено %d' % len(found))
    found.sort(key=lambda b: (b[1], b[0]))
    # По два в ряду: левый — чистый, правый — со смазом. Берём левые.
    for row in range(3):
        pair = sorted(found[row * 2:row * 2 + 2], key=lambda b: b[0])
        star = sheet.crop(pair[0])
        # Квадратный холст: снаряд КРУТИТСЯ, и на прямоугольном кадре центр
        # вращения уезжает от центра рисунка — звезда болталась бы по кругу.
        side = max(star.size)
        canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        canvas.alpha_composite(star, ((side - star.width) // 2,
                                      (side - star.height) // 2))
        canvas.save(DIR / ('star%d.png' % (row + 1)))
        print('star%d.png %dx%d' % (row + 1, side, side))
