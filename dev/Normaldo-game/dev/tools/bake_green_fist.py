#!/usr/bin/env python3
"""Зелёный кулак Нормальдо — из кулака Викинга.

    python3 dev/tools/bake_green_fist.py

Бьёт Нормальдо на боссе тем же кулаком, что и Викинг: он крупный, уже нарисован
и уже означает в этой игре «удар». Но нарисован он СЕРЫМ — это кулак викинга, а
не Нормальдо, и на арене два серых бойца различались только по тому, кто где
стоит.

Перекрашивается только заливка. Чёрные линии и голубой контур остаются: они и
делают кулак кулаком, а не зелёным пятном. Зелёный берётся ТОТ ЖЕ, что у головы
Нормальдо (34, 177, 76) — не «похожий зелёный», а буквально его цвет, иначе
кулак читался бы как чужая рука.

Ставить в игре руками нечего: скрипт кладёт готовый файл рядом с исходным, а
`bum_king.gd` грузит его по имени.
"""

import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC  = ROOT / "assets/skills/viking/fist.png"
DST  = ROOT / "assets/skills/fist_green.png"

# Заливка кулака викинга и зелёный головы Нормальдо.
GREY  = (121, 117, 117)
GREEN = (34, 177, 76)
# Затенение внутри заливки: у исходника оно есть, и без него кулак становится
# плоской зелёной кляксой. Порог по яркости, а не список цветов: оттенков там
# больше, чем видно в топе гистограммы.
TOL   = 46


def close_to(c, ref, tol):
    return all(abs(int(c[i]) - ref[i]) <= tol for i in range(3))


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    px = im.load()
    w, h = im.size
    changed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if not close_to((r, g, b), GREY, TOL):
                continue
            # Сохраняем СВЕТЛОТУ пикселя: тёмные места заливки остаются тёмными,
            # светлые — светлыми, иначе пропадает объём.
            k = (r + g + b) / (3.0 * GREY[0])
            px[x, y] = (
                min(255, int(GREEN[0] * k)),
                min(255, int(GREEN[1] * k)),
                min(255, int(GREEN[2] * k)),
                a,
            )
            changed += 1
    im.save(DST)
    print(f"{DST.relative_to(ROOT)}: перекрашено {changed} пикселей из {w * h}")


if __name__ == "__main__":
    main()
