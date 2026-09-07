# -*- coding: utf-8 -*-
"""Чипы выбора эпизода из авторских иконок.

    python3 dev/tools/bake_episode_chips.py <папка с иконками>

Художник присылает РИСУНОК эпизода — бак свалки, коряги, пальмы, горящую
копмашину, клубную колонку. А чип в меню — это не рисунок: это рисунок ПЛЮС
плашка под подпись, одна и та же у всех режимов до пикселя. Скрипт собирает одно
из другого.

── Почему плашка КОПИРУЕТСЯ, а не рисуется заново ───────────────────────────
Она уже есть в чипе первого эпизода, нарисована автором и увеличена
`bake_mode_btn.py` в той же плотности. Нарисовать её второй раз значило бы завести
второй источник одной картинки: разойдутся оттенком полос или толщиной обводки —
и шесть чипов в одном кольце перестанут быть одним семейством, причём заметить
это можно только положив их рядом.

── Свечение ─────────────────────────────────────────────────────────────────
Тоже собирается, а не берётся у первого: оно повторяет СИЛУЭТ чипа, а силуэты у
всех разные. Радиус и цвет — замер с `chapter1_mode_btn_glow.png`, чтобы новые
светились ровно так же, как тот, что уже в игре.

Иконку первого эпизода скрипт НЕ ТРОГАЕТ: она нарисована автором целиком, вместе
с плашкой, и пересобирать её из самой себя незачем.
"""
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets" / "ui" / "menu"
BASE = DIR / "chapter1_mode_btn.png"

UNIT = 64                      # авторский кадр, в его единицах задана разметка
PLATE = (11, 40, 42, 12)       # плашка под подпись: x, y, ш, в — замер, см. bake_mode_btn.py

# Свечение: замер с chapter1_mode_btn_glow.png.
GLOW_BLUR  = 9
GLOW_COLOR = (40, 68, 59)
GLOW_ALPHA = 203

# Эпизод → файл художника. Первого тут нет намеренно (см. шапку).
#
# НУМЕРАЦИЯ СДВИНУТА НА ОДИН, и это не опечатка. Иконки рисовались под шесть
# эпизодов, где вторым была СВАЛКА (бак с надписью DUMP). Эпизодов пять —
# столько же, сколько нарисованных фонов, — и свалки среди них нет: полосы у неё
# не существует. Поэтому `epizod 2.png` не используется, а остальные съезжают:
# коряги достаются реке, пальмы пляжу, горящая копмашина двору, колонка клубу.
# Каждая при этом ложится на СВОЙ фон — на полосе 3 нарисованы те же пальмы, на
# полосе 4 те же тачки, на полосе 5 та же вывеска клуба.
ICONS = {
    2: "epizod 3.png",   # коряги      → РЕКА
    3: "epizod 4.png",   # пальмы      → ПЛЯЖ
    4: "epizod 5.png",   # копмашина   → ДВОР
    5: "epizod 6.png",   # колонка     → КЛУБ
}


def fit(img: Image.Image, box: tuple) -> Image.Image:
    """Вписать рисунок в окно, сохранив пропорции, и положить по центру снизу.

    ПО ЦЕНТРУ СНИЗУ, а не по центру окна: у чипа первого эпизода труба стоит на
    плашке, и рисунок, повисший в воздухе над ней, читался бы как съехавший.
    """
    bw, bh = box[2] - box[0], box[3] - box[1]
    src = img.crop(img.getbbox()) if img.getbbox() else img
    k = min(bw / src.width, bh / src.height)
    w, h = max(1, int(src.width * k)), max(1, int(src.height * k))
    # LANCZOS, а не NEAREST: это рисунок, а не осепараллельная плашка, и
    # ступеньки ему ни к чему (та же логика, что в bake_mode_btn.py).
    out = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    out.paste(src.resize((w, h), Image.LANCZOS), ((bw - w) // 2, bh - h))
    return out


def glow_for(chip: Image.Image) -> Image.Image:
    """Мягкий силуэт чипа тем же цветом и радиусом, что у первого эпизода."""
    a = chip.getchannel("A").filter(ImageFilter.GaussianBlur(GLOW_BLUR))
    a = a.point(lambda v: min(GLOW_ALPHA, int(v * 1.35)))
    g = Image.new("RGBA", chip.size, GLOW_COLOR + (0,))
    g.putalpha(a)
    return g


def main():
    if len(sys.argv) < 2:
        raise SystemExit("укажите папку с иконками: bake_episode_chips.py <папка>")
    src_dir = Path(sys.argv[1])
    base = Image.open(BASE).convert("RGBA")
    k = base.width // UNIT
    px, py, pw, ph = [v * k for v in PLATE]
    plate = base.crop((px, py, px + pw, py + ph))
    # Окно рисунка — всё, что НАД плашкой. Границу берём у плашки, а не числом:
    # перепечатают чип в другой плотности — окно поедет за ней само.
    window = (0, 0, base.width, py)

    for ep, name in sorted(ICONS.items()):
        f = src_dir / name
        if not f.exists():
            print("нет файла, пропускаю: %s" % f)
            continue
        chip = Image.new("RGBA", base.size, (0, 0, 0, 0))
        chip.paste(fit(Image.open(f).convert("RGBA"), window), (0, 0))
        chip.alpha_composite(plate, (px, py))
        out = DIR / ("chapter%d_mode_btn.png" % ep)
        chip.save(out)
        glow_for(chip).save(DIR / ("chapter%d_mode_btn_glow.png" % ep))
        print("эпизод %d → %s (+свечение)" % (ep, out.name))


if __name__ == "__main__":
    main()
