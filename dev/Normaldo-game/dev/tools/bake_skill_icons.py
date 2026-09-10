#!/usr/bin/env python3
"""Печёт иконку способности из уже имеющегося рисунка.

    python3 dev/tools/bake_skill_icons.py

── Зачем печь, а не рисовать ────────────────────────────────────────────────
Иконка — это существующий рисунок, отражённый и приставленный к себе же.
Нарисовать её отдельно значило бы завести вторую копию карты: правка рисунка
перестала бы доходить до кружка способности.

(Эмблему Бэтмена пробовали печь так же — бэтаранг плюс его зеркало. Не вышло:
бэтаранг нарисован когтистой лапой, а не половиной крыла, и пара давала не
мышь, а две перчатки. Эмблема нашлась готовой — `batman/throw.png`.)

  card_pair.png — красная карта и её зеркало, разведённые веером. Спелл кидает
                  четыре карты крестом, то есть в обе стороны сразу, — одна
                  карта в кружке обещала бы бросок в одну.

Скрипт идемпотентный: перезапуск даёт тот же файл.
"""

import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def trim(im):
    """Обрезка по РИСУНКУ. Одинокие точки в углу холста (а они есть) обычный
    getbbox() принимает за рисунок и растягивает кадр на весь файл."""
    a = np.array(im)[:, :, 3] > 32

    def span(v):
        thr = max(6.0, v.max() * 0.05)
        idx = np.where(v >= thr)[0]
        return int(idx[0]), int(idx[-1] + 1)

    y0, y1 = span(a.sum(1))
    x0, x1 = span(a.sum(0))
    return im.crop((x0, y0, x1, y1))


def bake_card_pair():
    src = trim(Image.open(os.path.join(ROOT, "assets/skills/joker/card_red1.png")).convert("RGBA"))
    # Карты РАЗВЕДЕНЫ ВЕЕРОМ, а не поставлены рядом: две одинаковые карты стоймя
    # читаются как «две карты», а наклонённые врозь — как «полетели в стороны».
    ang = 18
    a = src.rotate(ang, expand=True, resample=Image.NEAREST)
    b = src.transpose(Image.FLIP_LEFT_RIGHT).rotate(-ang, expand=True, resample=Image.NEAREST)
    w, h = a.size
    over = int(w * 0.34)
    out = Image.new("RGBA", (w * 2 - over, h), (0, 0, 0, 0))
    out.alpha_composite(b, (0, 0))
    out.alpha_composite(a, (w - over, 0))
    out = trim(out)
    dst = os.path.join(ROOT, "assets/skills/joker/card_pair.png")
    out.save(dst)
    print("card_pair.png", src.size, "->", out.size)


if __name__ == "__main__":
    bake_card_pair()
