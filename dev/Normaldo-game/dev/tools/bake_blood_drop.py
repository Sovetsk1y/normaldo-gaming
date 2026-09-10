#!/usr/bin/env python3
"""Печёт каплю крови — кружок пассивки Дракулы «ОТЖОР ЛЮДЕЙ».

    python3 dev/tools/bake_blood_drop.py

── Почему нарисовано кодом ──────────────────────────────────────────────────
ЭТО ВРЕМЕНКА. Автор прислал каплю картинкой прямо в переписке, файлом она до
проекта не доехала, а кружок пассивки без картинки — это звёздочка, которая не
говорит ничего. Форма и цвета сняты с той картинки: большая капля и маленькая
рядом, тёмно-бордовая заливка, красный ободок, чёрный контур и светлый блик.

Как только файл появится, этот скрипт удаляется вместе с `blood_drop.png`, а на
его место кладётся авторский рисунок. Ничего, кроме иконки, от него не зависит.

Капля рисуется из ОКРУЖНОСТЕЙ И ТРЕУГОЛЬНИКА, а не кривыми: игра пиксельная,
сглаженные кривые в ней выглядят чужеродно, а из кругов получается ровно тот
силуэт, что у капли на рисунке.
"""

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DST = os.path.join(ROOT, "assets/skills/dracula/blood_drop.png")

# Цвета сняты с присланной картинки.
OUTLINE = (10, 8, 10, 255)
RIM     = (224, 26, 26, 255)
FILL    = (110, 12, 14, 255)
SHINE   = (232, 228, 228, 255)

SS = 6          # сглаживание: рисуем крупно, ужимаем в конец
W = H = 128


def drop(d, cx, cy, r, tip, col):
    """Капля: круг снизу и треугольник, сходящийся в остриё сверху."""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    d.polygon([(cx - r * 0.96, cy - r * 0.28), (cx, cy - r - tip),
               (cx + r * 0.96, cy - r * 0.28)], fill=col)


def bake():
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Большая капля слева-внизу, маленькая справа-сверху — как на рисунке.
    for cx, cy, r, tip in [(52, 78, 30, 34), (94, 40, 15, 18)]:
        for pad, col in [(5, OUTLINE), (0, RIM), (-6, FILL)]:
            drop(d, cx * SS, cy * SS, (r + pad) * SS, (tip + pad) * SS, col)
    # Блик — короткая светлая полоска на большой капле, как на присланном.
    d.rounded_rectangle(
        [int(40 * SS), int(62 * SS), int(45 * SS), int(84 * SS)],
        radius=int(2.5 * SS), fill=SHINE)
    im = im.resize((W, H), Image.LANCZOS)
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    im.save(DST)
    print("blood_drop.png ->", im.size)


if __name__ == "__main__":
    bake()
