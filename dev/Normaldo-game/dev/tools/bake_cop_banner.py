#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Титр BOSS FIGHT для Капитана полиции.

    python3 dev/tools/bake_cop_banner.py

У боссов ОДИН титр на всех, и меняется в нём только лицо в круге: то же
кольцо, те же шипы, та же надпись. Набранное шрифтом «БОСС ФАЙТ» выпадало бы
из ряда — у троих рисунок, у четвёртого надпись.

Берём титр ХОЗЯИНА КЛУБА как заготовку (у него голова с куском пиццы на ней —
ровно то, что просили для копа), вырезаем из круга его лицо и вставляем голову
капитана с таким же куском.

ПОЧЕМУ ЗАГОТОВКА, А НЕ РИСОВАНИЕ С НУЛЯ: буквы нарисованы от руки, и повторить
их кодом нельзя. Круг же — сплошной чёрный диск, и заменить его содержимое
безопасно: границы диска остаются авторскими.
"""
import os
from PIL import Image

# Скрипт лежит в <игра>/dev/tools/, значит корень игры — две папки вверх.
GAME = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_BANNER = os.path.join(GAME, "assets/bosses/club_boss/banner.png")
SRC_COP    = os.path.join(GAME, "assets/bosses/police/cop.png")
SRC_PIZZA  = os.path.join(GAME, "assets/items/pizza.png")
OUT        = os.path.join(GAME, "assets/bosses/police/banner.png")

# Круг замерен по заготовке: сплошной тёмный диск в средней трети титра.
CIRCLE_X, CIRCLE_Y = 600, 243
CIRCLE_R = 104
# Голова занимает не весь круг: у соседей она вписана с полем, и без поля
# капитан упирался бы фуражкой в кольцо.
HEAD_K  = 1.62
# Кусок пиццы на макушке — как у хозяина клуба.
PIZZA_K = 0.62
PIZZA_ANGLE = -18
PIZZA_DX, PIZZA_DY = -22, -62


def content_box(im):
    """Рамка НАРИСОВАННОГО, а не кадра: поля у исходников разные, и вписывать
    надо рисунок, иначе одна голова окажется вдвое мельче другой."""
    return im.getbbox()


def main():
    banner = Image.open(SRC_BANNER).convert("RGBA")
    cop    = Image.open(SRC_COP).convert("RGBA")
    pizza  = Image.open(SRC_PIZZA).convert("RGBA")

    # Гасим прежнее лицо: закрашиваем круг чёрным ровно по диску.
    disc = Image.new("RGBA", banner.size, (0, 0, 0, 0))
    from PIL import ImageDraw
    ImageDraw.Draw(disc).ellipse(
        [CIRCLE_X - CIRCLE_R, CIRCLE_Y - CIRCLE_R,
         CIRCLE_X + CIRCLE_R, CIRCLE_Y + CIRCLE_R],
        fill=(10, 8, 14, 255))
    banner.alpha_composite(disc)

    cop = cop.crop(content_box(cop))
    k = (CIRCLE_R * HEAD_K) / max(cop.width, cop.height)
    cop = cop.resize((max(1, int(cop.width * k)), max(1, int(cop.height * k))),
                     Image.NEAREST)
    banner.alpha_composite(cop, (CIRCLE_X - cop.width // 2,
                                 CIRCLE_Y - cop.height // 2))

    pizza = pizza.crop(content_box(pizza))
    pk = (CIRCLE_R * PIZZA_K) / max(pizza.width, pizza.height)
    pizza = pizza.resize((max(1, int(pizza.width * pk)),
                          max(1, int(pizza.height * pk))), Image.NEAREST)
    pizza = pizza.rotate(PIZZA_ANGLE, expand=True, resample=Image.NEAREST)
    banner.alpha_composite(pizza, (CIRCLE_X - pizza.width // 2 + PIZZA_DX,
                                   CIRCLE_Y - pizza.height // 2 + PIZZA_DY))

    banner.save(OUT)
    print("готово:", OUT, banner.size)


if __name__ == "__main__":
    main()
