#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Таблица достижений из спеки → xlsx.

    python3 dev/tools/achievements_xlsx.py [куда.xlsx]

Читает `Концепция/Достижения.md` и собирает из её таблиц один лист: категория,
волна, id, название, условие, вес, очки, источник события, лестница и номер
ступени в ней.

── Почему из спеки, а не из своего списка ───────────────────────────────────
Своего списка у этого скрипта НЕТ намеренно. Две копии одних и тех же данных в
этом проекте расходились уже не раз — список тегов резистов, таблица картинок
статусов, раскладка предметов в тесте, — и расходились молча, в первую же
правку. Спека — единственный источник; xlsx из неё выводится.

По этой же причине xlsx НЕ лежит в репозитории: он производная, и закоммиченная
производная разъезжается с исходником ровно так же. Нужен файл — собери им.

── Что здесь всё-таки своё ──────────────────────────────────────────────────
Раскладка лестниц (CHAINS). В спеке она есть отдельной таблицей, но в машинном
виде её оттуда не достать: там человекочитаемые подписи ступеней («100 за
забег», «все 14»), а не id. Сверка — `_check_chains`: каждый id лестницы обязан
найтись среди достижений, иначе скрипт падает. Так расхождение обнаруживается
при сборке, а не в готовом файле.

── Итоги — числа, а не формулы ──────────────────────────────────────────────
Сначала внизу стояли COUNTA / SUM / COUNTIF / SUMIF: файл уходит на
согласование, в нём будут вычёркивать строки и двигать достижения между
волнами, и после правки итоги сходились бы сами.

Не вышло по внешней причине. openpyxl пишет формулу СТРОКОЙ, без вычисленного
значения, и подставить его может только табличный движок. LibreOffice в рабочем
окружении этого проекта не отрабатывает — три попытки, таймауты на 86, 299 и
560 секундах. Excel и Numbers пересчитали бы при открытии, но до этого файл
показывает пустые клетки везде, где стояла формула: в быстром просмотре, в
почте, в мессенджере. Сводка, которая читается как пустая, хуже сводки,
устаревающей после правки.

Поэтому итоги считаются здесь и кладутся числами, а на листе стоит строка о
том, что это снимок: поправил таблицу — перезапусти скрипт.
"""
import sys
from pathlib import Path

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

ROOT = Path(__file__).resolve().parents[4]        # …/normaldo-gaming
SRC = ROOT / "Концепция" / "Достижения.md"
DEFAULT_OUT = ROOT / "Достижения — Нормальдо.xlsx"

# Вес → (имя, очки). Порядок словаря задаёт порядок строк в итогах.
TIER = {"🥉": ("бронза", 5), "🥈": ("серебро", 10),
        "🥇": ("золото", 20), "💎": ("платина", 30)}

CHAINS = [
    ("Пицца за всё время",  ["pizza_1k", "pizza_10k", "pizza_50k", "pizza_250k"]),
    ("Пицца за забег",      ["first_bite", "pizza_run_300", "pizza_run_700"]),
    ("Деньги за всё время", ["money_5k", "money_50k", "money_250k"]),
    ("Деньги за забег",     ["first_dollar", "money_run_200"]),
    ("Мешки денег",         ["bag_10", "bag_100"]),
    ("Жир",                 ["fat_slim", "fat_fat", "fat_uber"]),
    ("Кампания",            ["ep1", "ep2", "ep3", "campaign"]),
    ("Время в бесконечном", ["endless_3m", "endless_5m", "endless_10m", "endless_15m"]),
    ("Эпизоды без урона",   ["ep_nodmg_1", "ep_nodmg_all"]),
    ("Без удара подряд",    ["clean_60", "clean_180"]),
    ("Скины куплены",       ["skins_3", "skins_7", "skins_all"]),
    ("Уровни скинов",       ["lvl5_any", "lvl10_any", "lvl10_x3", "lvl10_all"]),
    ("Спеллы скина",        ["spell_100", "spell_1000"]),
    ("Резисты",             ["resist_10", "resist_200"]),
    ("Каталог",             ["codex_25", "codex_all"]),
    ("Автомат",             ["first_spin", "slot_100"]),
    ("Место в таблице",     ["top100", "top10", "top1"]),
]

HEAD = ["Категория", "Волна", "id", "Название", "Условие", "Вес", "Очки",
        "Откуда", "Лестница", "Ступень", "Скрытое"]
WIDTH = [22, 7, 16, 24, 52, 10, 7, 14, 22, 10, 9]

ARIAL = "Arial"
TIER_FILL = {
    "бронза":  PatternFill("solid", fgColor="F2E3D5"),
    "серебро": PatternFill("solid", fgColor="E8EAEE"),
    "золото":  PatternFill("solid", fgColor="FCEFC2"),
    "платина": PatternFill("solid", fgColor="DCE9F7"),
}
WAVE1_FILL = PatternFill("solid", fgColor="E6F4E6")


def parse(md_path):
    """Строки достижений из markdown-таблиц спеки.

    Опознаются по ШЕСТИ колонкам: у таблицы лестниц ниже по файлу их три, у
    вводных таблиц — четыре. Считать строки по «начинается с | `» нельзя, они
    все такие.
    """
    cat, out = None, []
    for line in md_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("### "):
            cat = line[4:].strip()
        if not (line.startswith("| ") and line.count("|") == 7 and "`" in line):
            continue
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        if not c[1].startswith("`"):
            continue
        tier_name, pts = TIER[c[4]]
        # Три состояния, а не два. ✅ — первая волна, пусто — вторая, ⏳ —
        # ЗАРЕЗЕРВИРОВАНО: достижение объявлено, но в App Store Connect не
        # заводится. Нужно это потому, что в Game Center достижение у игрока не
        # отзывается: заведённое живёт вечно, а незаведённый id ничего не стоит.
        # Волна у зарезервированного не «вторая» — она ещё не определена, и
        # ставится второй только чтобы поле не пустовало.
        out.append({
            "Категория": cat,
            "Волна":     1 if c[0] == "✅" else 2,
            "Резерв":    c[0] == "⏳",
            "id":        c[1].strip("`"),
            "Название":  c[2],
            "Условие":   c[3],
            "Вес":       tier_name,
            "Очки":      pts,
            "Откуда":    c[5],
            "Скрытое":   "да" if cat == "Скрытые" else "",
        })
    return out


def _check_chains(rows):
    """Лестницы обязаны ссылаться на существующие достижения."""
    ids = {r["id"] for r in rows}
    lost = [a for _n, chain in CHAINS for a in chain if a not in ids]
    if lost:
        raise SystemExit("в спеке нет достижений из лестниц: %s" % ", ".join(lost))
    step = {}
    for name, chain in CHAINS:
        for i, a in enumerate(chain):
            step[a] = (name, "%d из %d" % (i + 1, len(chain)))
    for r in rows:
        r["Лестница"], r["Ступень"] = step.get(r["id"], ("", ""))


def build(rows, out_path):
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Достижения"

    thin = Side(style="thin", color="C8CDD6")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)

    for j, h in enumerate(HEAD, start=1):
        c = ws.cell(row=1, column=j, value=h)
        c.font = Font(name=ARIAL, size=11, bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor="2F3B52")
        c.border = border
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        ws.column_dimensions[get_column_letter(j)].width = WIDTH[j - 1]
    ws.row_dimensions[1].height = 26

    for i, r in enumerate(rows, start=2):
        for j, h in enumerate(HEAD, start=1):
            var = r[h]
            # В колонке волны у зарезервированного стоит слово, а не число:
            # «2» читалось бы как «сделаем во вторую волну», а его не делают
            # вообще, пока эпизодов три.
            if h == "Волна" and r.get("Резерв"):
                var = "резерв"
            c = ws.cell(row=i, column=j, value=var)
            c.font = Font(name=ARIAL, size=10, bold=(h == "Название"))
            c.border = border
            c.alignment = Alignment(
                vertical="center",
                wrap_text=(h in ("Условие", "Название")),
                horizontal="center" if h in ("Волна", "Очки", "Ступень", "Скрытое") else "left")
            if h == "Вес":
                c.fill = TIER_FILL[r["Вес"]]
            elif h == "Волна" and r.get("Резерв"):
                c.fill = PatternFill("solid", fgColor="F0E4C8")
            elif h == "Волна" and r["Волна"] == 1:
                c.fill = WAVE1_FILL

    last = len(rows) + 1
    bold = Font(name=ARIAL, size=10, bold=True)
    plain = Font(name=ARIAL, size=10)

    def line(row, label, count, total, label_font=plain, num_font=plain):
        ws.cell(row=row, column=3, value=label).font = label_font
        ws.cell(row=row, column=4, value=count).font = num_font
        ws.cell(row=row, column=6, value="очков").font = plain
        ws.cell(row=row, column=7, value=total).font = num_font

    wave1 = [r for r in rows if r["Волна"] == 1]
    line(last + 2, "ВСЕГО достижений", len(rows),
         sum(r["Очки"] for r in rows), bold, bold)
    line(last + 3, "из них первая волна", len(wave1),
         sum(r["Очки"] for r in wave1))

    for k, (tier, _pts) in enumerate(TIER.values()):
        same = [r for r in rows if r["Вес"] == tier]
        rr = last + 5 + k
        line(rr, tier, len(same), sum(r["Очки"] for r in same))
        ws.cell(row=rr, column=3).fill = TIER_FILL[tier]

    note = ws.cell(row=last + 10, column=3, value=(
        "Потолок Apple: не больше 100 достижений на приложение, не больше 100 очков "
        "на достижение и не больше 1000 очков суммарно. Волна 1 — то, что делается "
        "первым.\n"
        "Итоги выше — СНИМОК на момент сборки, а не формулы: поправил таблицу — "
        "перезапусти dev/tools/achievements_xlsx.py.\n"
        "Источник таблицы: Концепция/Достижения.md в репозитории."))
    note.font = Font(name=ARIAL, size=9, italic=True, color="555555")
    note.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=last + 10, start_column=3, end_row=last + 12, end_column=8)

    ws.freeze_panes = "C2"
    ws.auto_filter.ref = "A1:K%d" % last
    wb.save(out_path)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    rows = parse(SRC)
    if not rows:
        raise SystemExit("в %s не нашлось ни одной строки достижения" % SRC)
    _check_chains(rows)
    build(rows, out)
    print("собрано: %d достижений → %s" % (len(rows), out))


if __name__ == "__main__":
    main()
