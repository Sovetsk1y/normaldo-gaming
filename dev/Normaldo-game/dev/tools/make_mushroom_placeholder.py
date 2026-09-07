# -*- coding: utf-8 -*-
"""ЗАГЛУШКА картинки гриба.

    python3 dev/tools/make_mushroom_placeholder.py

Это НЕ финальный ассет. Настоящий гриб рисует художник; здесь нарисована
узнаваемая болванка, чтобы предмет можно было увидеть в кадре и прогнать
тестами, пока картинки нет.

Заглушка нужна ещё и потому, что без файла игра НЕ КОМПИЛИРУЕТСЯ: `mushroom_item.gd`
делает `preload`, а он проверяется на этапе разбора скрипта. То есть отсутствие
одной картинки роняло бы весь проект, а не один предмет.

Как заменить: положить настоящий `mushroom.png` на то же место
(`assets/items/mushroom.png`) и удалить этот скрипт. Размер кадра — 512×512,
рисунок внутри с полями, как у остальных предметов: `ItemSizing.fit_sprite_content`
меряет непрозрачную рамку, поэтому поля на масштаб не влияют.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "items" / "mushroom.png"

SIZE = 512
CAP = (122, 63, 155, 255)      # фиолетовая шляпка
CAP_LIT = (150, 92, 186, 255)  # блик
GILLS = (92, 108, 220, 255)    # синий низ шляпки
STEM = (150, 150, 156, 255)    # серая ножка
STEM_LIT = (186, 186, 192, 255)
STAR = (232, 120, 40, 255)     # оранжевые звёзды
LINE = (0, 0, 0, 255)


def star(d, cx, cy, r, fill):
    """Пятиконечная звезда — тем же приёмом, что и звёзды на шляпке в эскизе."""
    import math
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.42
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Ножка: слегка изогнутая книзу колонка.
    d.rounded_rectangle([206, 250, 306, 452], radius=44, fill=STEM, outline=LINE, width=10)
    d.rounded_rectangle([228, 276, 258, 430], radius=15, fill=STEM_LIT)

    # Низ шляпки — синие пластинки.
    d.ellipse([84, 214, 428, 306], fill=GILLS, outline=LINE, width=10)

    # Шляпка.
    d.pieslice([70, 96, 442, 340], start=180, end=360, fill=CAP, outline=LINE, width=10)
    d.pieslice([104, 122, 300, 300], start=195, end=300, fill=CAP_LIT)
    d.pieslice([70, 96, 442, 340], start=180, end=360, outline=LINE, width=10)

    # Звёзды на шляпке.
    star(d, 168, 186, 52, STAR)
    star(d, 300, 160, 34, STAR)
    star(d, 372, 214, 26, STAR)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print("заглушка записана: %s (%d×%d)" % (OUT, SIZE, SIZE))
    print("ЭТО НЕ ФИНАЛЬНЫЙ АССЕТ — заменить картинкой художника.")


if __name__ == "__main__":
    main()
