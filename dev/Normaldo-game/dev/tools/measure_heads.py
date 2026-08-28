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
    """(доля ширины кадра, смещение центра X, смещение центра Y, доля высоты).

    Высота головы нужна ЖИРОБОССУ: там голова растягивается на высоту экрана, и
    считать её размер по ширине нельзя — у классики голова заметно шире, чем
    выше, и она вылезала бы за кадр сильнее остальных.
    """
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
            ((miny + maxy) / 2.0) / float(H) - 0.5,
            (maxy - miny + 1) / float(H))


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
    frac, _, _, frac_h = head_metrics(states[0])
    offs, boxes, heads = [], [], []
    for p in states:
        if p is None:
            offs.append((0.0, 0.0))
            boxes.append((1.0, 1.0))
            heads.append((frac, frac_h))
            continue
        fw, ox, oy, fh = head_metrics(p)
        offs.append((ox, oy))
        boxes.append(body_box(p))
        # Голова ПО КАЖДОМУ состоянию жира: при жирении она нарисована крупнее,
        # и ЖИРОБОСС, считающий размер по первому состоянию, на четвёртом
        # раздувался бы сильнее и хитбоксом вылезал за лицо.
        heads.append((fw, fh))
    return (sid, ref / frac, frac, frac_h, offs, boxes, heads)


# Варианты кадра головы: «ест», позы каста, призрачные кадры Дракулы, «доллары
# в глазах» классики. Все они подменяют текстуру на том же спрайте, а масштаб у
# спрайта посчитан по ОБЫЧНОМУ кадру. Если художник кадрировал вариант иначе,
# голова на подмене меняет размер: у классики кадр «доллары в глазах» приезжал
# в 2.7 раза крупнее обычного и читался как пролаг движка.
#
# Здесь считается поправка: во сколько раз ужать спрайт на этом варианте, чтобы
# ГОЛОВА осталась того же размера.
VARIANT_SUFFIXES = ["_eat", "_spell", "_spell2", "_ghost", "_ghost_eat", "_cash"]


def _head_px(path):
    from PIL import Image as _I
    frac, _, _, _ = head_metrics(path)
    return frac * _I.open(path).size[0]


def variant_row(sid, d, classic=False):
    """{ "_eat": [k1..k4], ... } — только там, где поправка реально нужна."""
    out = {}
    for suf in VARIANT_SUFFIXES:
        ks, need = [], False
        for st in range(1, 5):
            base = os.path.join(SKINS_DIR, "normaldo%d.png" % st) if classic \
                else os.path.join(d, "state%d.png" % st)
            var = os.path.join(SKINS_DIR, "normaldo%d%s.png" % (st, suf)) if classic \
                else os.path.join(d, "state%d%s.png" % (st, suf))
            if not (os.path.exists(base) and os.path.exists(var)):
                ks.append(1.0)
                continue
            k = _head_px(base) / max(1e-6, _head_px(var))
            ks.append(k)
            if abs(k - 1.0) > 0.04:
                need = True
        if need:
            out[suf] = ks
    return out


def build_variants():
    rows = {}
    v = variant_row("classic", None, classic=True)
    if v:
        rows["classic"] = v
    for d in sorted(glob.glob(os.path.join(SKINS_DIR, "*") + os.sep)):
        sid = os.path.basename(d.rstrip(os.sep))
        if not os.path.exists(os.path.join(d, "state1.png")):
            continue
        v = variant_row(sid, d)
        if v:
            rows[sid] = v
    return rows


def render_variants(rows):
    out = []
    for sid in sorted(rows):
        parts = ", ".join('"%s": [%s]' % (suf, ", ".join("%.3f" % k for k in ks))
                          for suf, ks in sorted(rows[sid].items()))
        out.append('\t"%s": { %s },' % (sid, parts))
    return "\n".join(out)


def build_rows():
    # Классика — эталон: её кадр это ровно голова.
    ref = head_metrics(os.path.join(SKINS_DIR, "normaldo1.png"))[0]
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
    for sid, scale, frac, frac_h, offs, boxes, heads in rows:
        pts = ", ".join("Vector2(%.4f, %.4f)" % o for o in offs)
        bxs = ", ".join("Vector2(%.4f, %.4f)" % b for b in boxes)
        hds = ", ".join("Vector2(%.4f, %.4f)" % h for h in heads)
        out.append('\t"%s": { "scale": %.3f, "head": %.4f, "head_h": %.4f, '
                   '"off": [%s], "box": [%s], "head_wh": [%s] },'
                   % (sid, scale, frac, frac_h, pts, bxs, hds))
    return "\n".join(out)


def main():
    rows = build_rows()
    table = render_table(rows)
    vtable = render_variants(build_variants())

    if "--check" in sys.argv:
        current = open(OUT, encoding="utf-8").read()
        block = re.search(r"const HEADS : Dictionary = \{\n(.*?)^\}",
                          current, re.S | re.M)
        if block is None:
            print("НЕ НАЙДЕНА таблица HEADS в", OUT)
            return 1
        if block.group(1).strip() != table.strip():
            print("Таблица РАЗОШЛАСЬ со спрайтами. Перегенерируйте:")
            print("  python3 dev/tools/measure_heads.py")
            return 1
        vblock = re.search(r"const POSE_K : Dictionary = \{\n(.*?)^\}", current, re.S | re.M)
        if vblock is None or vblock.group(1).strip() != vtable.strip():
            print("Поправки вариантов РАЗОШЛИСЬ. Перегенерируйте:")
            print("  python3 dev/tools/measure_heads.py")
            return 1
        print("Таблица совпадает со спрайтами (%d скинов)." % len(rows))
        return 0

    current = open(OUT, encoding="utf-8").read()
    updated = re.sub(r"(const HEADS : Dictionary = \{\n).*?(^\})",
                     lambda m: m.group(1) + table + "\n" + m.group(2),
                     current, flags=re.S | re.M)
    updated = re.sub(r"(const POSE_K : Dictionary = \{\n).*?(^\})",
                     lambda m: m.group(1) + vtable + "\n" + m.group(2),
                     updated, flags=re.S | re.M)
    open(OUT, "w", encoding="utf-8").write(updated)
    print("Обновлено %d скинов в %s" % (len(rows), os.path.relpath(OUT, ROOT)))
    for sid, scale, frac, frac_h, _, boxes, _h in rows:
        print("  %-14s ×%.2f  голова %.0f×%.0f %% кадра, силуэт %.0f×%.0f %%"
              % (sid, scale, frac * 100.0, frac_h * 100.0,
                 boxes[0][0] * 100.0, boxes[0][1] * 100.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
