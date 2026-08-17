#!/usr/bin/env python3
"""Замер голов скинов → scripts/skin_metrics.gd.

Зачем. Спрайты скинов кадрированы по-разному: у классики в кадре только голова,
у Джокера — голова на 27 % ширины и разведённые руки. Если нормировать масштаб
по ширине КАДРА (как было раньше), голова у скинов с руками выходит в разы
мельче, хотя игрок оценивает размер персонажа именно по голове.

Голова определяется как САМАЯ КРУПНАЯ связная непрозрачная область спрайта:
руки, перчатки и посохи нарисованы отдельными пятнами и в неё не попадают.

    python3 dev/tools/measure_heads.py            # перегенерировать таблицу
    python3 dev/tools/measure_heads.py --check    # только проверить совпадение

`--check` возвращает ненулевой код, если таблица разошлась со спрайтами, —
годится для CI и для проверки после перерисовки скина.

Требует Pillow:  pip install pillow
"""

import glob
import os
import re
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SKINS_DIR = os.path.join(ROOT, "assets", "normaldo")
OUT = os.path.join(ROOT, "scripts", "skin_metrics.gd")

# До какого размера ужимаем спрайт перед заливкой. Заливка по пикселям на
# 1000×1000 неоправданно долгая, а нам нужна пропорция, а не точность до пикселя.
WORK_SIZE = 200
ALPHA_MIN = 40


def head_metrics(path):
    """(доля ширины кадра, смещение центра по X, по Y) — всё в долях кадра."""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    sc = float(WORK_SIZE) / max(w, h)
    im = im.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.NEAREST)
    W, H = im.size
    a = im.split()[3].load()

    seen = [[False] * H for _ in range(W)]
    best = None
    for sx in range(W):
        for sy in range(H):
            if seen[sx][sy] or a[sx, sy] < ALPHA_MIN:
                continue
            stack = [(sx, sy)]
            seen[sx][sy] = True
            minx = maxx = sx
            miny = maxy = sy
            area = 0
            while stack:
                x, y = stack.pop()
                area += 1
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[nx][ny] \
                            and a[nx, ny] >= ALPHA_MIN:
                        seen[nx][ny] = True
                        stack.append((nx, ny))
            if best is None or area > best[0]:
                best = (area, minx, maxx, miny, maxy)

    _, minx, maxx, miny, maxy = best
    return ((maxx - minx + 1) / float(W),
            ((minx + maxx) / 2.0) / float(W) - 0.5,
            ((miny + maxy) / 2.0) / float(H) - 0.5)


def body_box(path):
    """(ширина, высота) ВИДИМОГО силуэта в долях кадра.

    Нужна, чтобы ограничить общий размер скина. Нормировка по голове делает
    головы одинаковыми, но у скинов с телом и посохом силуэт при этом
    раздувается вдвое против классики — а бьётся всё равно только голова
    (хитбокс — круг радиусом 32). Игрок видит тушу, которая ничего не задевает.
    """
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    bb = im.split()[3].point(lambda v: 255 if v >= ALPHA_MIN else 0).getbbox()
    if bb is None:
        return (1.0, 1.0)
    return ((bb[2] - bb[0]) / float(w), (bb[3] - bb[1]) / float(h))


def _states(d, classic=False):
    """Пути к четырём состояниям жира: у классики своё имя файлов."""
    out = []
    for st in range(1, 5):
        p = os.path.join(SKINS_DIR, "normaldo%d.png" % st) if classic \
            else os.path.join(d, "state%d.png" % st)
        out.append(p if os.path.exists(p) else None)
    return out


def _row(sid, states, ref):
    frac, _, _ = head_metrics(states[0])
    offs, boxes = [], []
    for p in states:
        if p is None:
            offs.append((0.0, 0.0))
            boxes.append((1.0, 1.0))
            continue
        _, ox, oy = head_metrics(p)
        offs.append((ox, oy))
        boxes.append(body_box(p))
    return (sid, ref / frac, frac, offs, boxes)


def build_rows():
    # Классика — эталон: её кадр это ровно голова.
    ref, _, _ = head_metrics(os.path.join(SKINS_DIR, "normaldo1.png"))
    # Классика тоже попадает в таблицу: масштаб у неё ×1, но силуэт и доля
    # головы нужны интерфейсу наравне с остальными.
    rows = [_row("classic", _states(None, classic=True), ref)]
    for d in sorted(glob.glob(os.path.join(SKINS_DIR, "*") + os.sep)):
        sid = os.path.basename(d.rstrip(os.sep))
        if not os.path.exists(os.path.join(d, "state1.png")):
            continue
        rows.append(_row(sid, _states(d), ref))
    return rows


def render_table(rows):
    out = []
    for sid, scale, frac, offs, boxes in rows:
        pts = ", ".join("Vector2(%.4f, %.4f)" % o for o in offs)
        bxs = ", ".join("Vector2(%.4f, %.4f)" % b for b in boxes)
        out.append('\t"%s": { "scale": %.3f, "head": %.4f, "off": [%s], "box": [%s] },'
                   % (sid, scale, frac, pts, bxs))
    return "\n".join(out)


def main():
    rows = build_rows()
    table = render_table(rows)

    if "--check" in sys.argv:
        current = open(OUT, encoding="utf-8").read()
        block = re.search(r"const HEADS : Dictionary = \{\n(.*?)\n\}",
                          current, re.S)
        if block is None:
            print("НЕ НАЙДЕНА таблица HEADS в", OUT)
            return 1
        if block.group(1).strip() != table.strip():
            print("Таблица РАЗОШЛАСЬ со спрайтами. Перегенерируйте:")
            print("  python3 dev/tools/measure_heads.py")
            return 1
        print("Таблица совпадает со спрайтами (%d скинов)." % len(rows))
        return 0

    current = open(OUT, encoding="utf-8").read()
    updated = re.sub(r"(const HEADS : Dictionary = \{\n).*?(\n\})",
                     lambda m: m.group(1) + table + m.group(2),
                     current, flags=re.S)
    open(OUT, "w", encoding="utf-8").write(updated)
    print("Обновлено %d скинов в %s" % (len(rows), os.path.relpath(OUT, ROOT)))
    for sid, scale, frac, _, boxes in rows:
        print("  %-14s ×%.2f  голова %.0f %% кадра, силуэт %.0f×%.0f %%"
              % (sid, scale, frac * 100.0, boxes[0][0] * 100.0, boxes[0][1] * 100.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
