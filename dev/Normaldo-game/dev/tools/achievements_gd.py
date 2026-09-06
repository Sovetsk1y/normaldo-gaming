# -*- coding: utf-8 -*-
"""Концепция/Достижения.md → scripts/achievements.gd

Таблица достижений для игры генерится из спеки, а не пишется руками. Причина
та же, по которой генерится и выгрузка в xlsx: две копии одних данных в этом
проекте расходились уже не раз — список тегов резистов, таблица картинок
статусов, раскладка предметов в тесте, — и расходились молча.

Здесь копий было бы три (спека, игра, Apple), и вручную они не удержались бы
и месяца.

    python3 dev/tools/achievements_gd.py

Разбор спеки берётся из соседнего achievements_xlsx.py: парсер один на оба
выхода, иначе разойтись смогли бы уже сами инструменты.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from achievements_xlsx import ROOT, SRC, parse, _check_chains  # noqa: E402

OUT = ROOT / "dev" / "Normaldo-game" / "scripts" / "achievements.gd"

# Категория спеки → короткий ключ и подпись вкладки на экране.
CATS = [
    ("start",    "Первые шаги",        "СТАРТ"),
    ("pizza",    "Пицца",              "ПИЦЦА"),
    ("money",    "Деньги",             "ДЕНЬГИ"),
    ("fat",      "Жир",                "ЖИР"),
    ("campaign", "Кампания и боссы",   "КАМПАНИЯ"),
    ("endless",  "Бесконечный режим",  "БЕСКОНЕЧНЫЙ"),
    ("skins",    "Скины",              "СКИНЫ"),
    ("skill",    "Мастерство",         "МАСТЕРСТВО"),
    ("codex",    "Каталог и предметы", "КАТАЛОГ"),
    ("slots",    "Автоматы",           "АВТОМАТЫ"),
    ("leaders",  "Таблица лидеров",    "ЛИДЕРЫ"),
    ("secret",   "Скрытые",            "СКРЫТЫЕ"),
]
KEY_BY_RU = {ru: key for key, ru, _ in CATS}
TIER_KEY = {"бронза": 1, "серебро": 2, "золото": 3, "платина": 4}

# ── Счётчик и порог на каждое достижение ─────────────────────────────────────
# В спеке «условие» написано словами — она для людей. Машине нужны имя счётчика
# и число, и связывает их эта таблица.
#
# Да, это второй список рядом с первым — тот самый, против которого всё
# остальное здесь и сделано. Разница в том, что он ОБЯЗАН совпадать по составу
# со спекой, и сборка это проверяет: лишний или недостающий id роняет скрипт
# (см. _check_stats). Молча разойтись, как расходились прошлые копии, он не
# может — а вписать имена счётчиков в спеку значило бы засорить документ,
# который читают глазами.
#
# Имена счётчиков — настоящие, под них и будут заводиться хуки в игре.
# Префикс `item:` — счётчик по имени предмета из `normaldo._area_tag`.
STATS = {
    # Первые шаги
    "first_flight":  ("runs_total", 1),
    "first_bite":    ("pizzas_run_best", 100),
    "first_dollar":  ("money_run_best", 50),
    "first_skin":    ("skins_bought", 1),
    "first_spin":    ("slot_spins", 1),
    "first_boss":    ("boss_reached", 1),
    # Пицца
    "pizza_1k":      ("pizzas_total", 1000),
    "pizza_10k":     ("pizzas_total", 10000),
    "pizza_50k":     ("pizzas_total", 50000),
    "pizza_250k":    ("pizzas_total", 250000),
    "pizza_run_300": ("pizzas_run_best", 300),
    "pizza_run_700": ("pizzas_run_best", 700),
    # Деньги
    "money_5k":      ("money_total", 5000),
    "money_50k":     ("money_total", 50000),
    "money_250k":    ("money_total", 250000),
    "money_run_200": ("money_run_best", 200),
    "bag_10":        ("item:money_bag", 10),
    "bag_100":       ("item:money_bag", 100),
    # Жир
    "fat_slim":      ("fat_max", 1),
    "fat_fat":       ("fat_max", 2),
    "fat_uber":      ("fat_max", 3),
    "uber_10":       ("uber_runs", 10),
    "uber_fast":     ("uber_fast", 1),
    "diet":          ("skinny_episode", 1),
    # Кампания и боссы
    "ep1":           ("episodes_done", 1),
    "ep2":           ("episodes_done", 2),
    "ep3":           ("episodes_done", 3),
    "campaign":      ("campaign_done", 1),
    "ep_nodmg_1":    ("nodmg_episodes", 1),
    "ep_nodmg_all":  ("nodmg_episodes", 3),
    "croc_nodmg":    ("boss_nodmg:croc", 1),
    "club_nodmg":    ("boss_nodmg:club", 1),
    "ninja_fast":    ("ninja_fast", 1),
    "bosses_25":     ("bosses_beaten", 25),
    # Бесконечный режим
    "endless_start": ("endless_runs", 1),
    "endless_3m":    ("endless_best", 180),
    "endless_5m":    ("endless_best", 300),
    "endless_10m":   ("endless_best", 600),
    "endless_15m":   ("endless_best", 900),
    "hardcore":      ("hardcore_reached", 1),
    "hardcore_2m":   ("hardcore_best", 120),
    # Скины
    "skins_3":       ("skins_owned", 3),
    "skins_7":       ("skins_owned", 7),
    "skins_all":     ("skins_owned", 14),
    "lvl5_any":      ("skin_lvl_max", 5),
    "lvl10_any":     ("skin_lvl_max", 10),
    "lvl10_x3":      ("skins_at_10", 3),
    "lvl10_all":     ("skins_at_10", 14),
    "fitting_room":  ("all_skins_played", 1),
    "spell_100":     ("spell_casts", 100),
    "spell_1000":    ("spell_casts", 1000),
    "viking_50":     ("spell_hits:viking", 50),
    "spider_50":     ("spell_hits:spider_man", 50),
    # Мастерство
    "resist_10":     ("resists", 10),
    "resist_200":    ("resists", 200),
    "safe_resist":   ("safe_resist", 1),
    "clean_60":      ("clean_best", 60),
    "clean_180":     ("clean_best", 180),
    "curse_survive": ("curse_survived", 1),
    "reflex_5":      ("reflex_run_best", 5),
    "timestop_10":   ("time_stops", 10),
    # Каталог и предметы
    "codex_25":      ("codex_seen", 25),
    "codex_all":     ("codex_seen", 54),
    "magicbox_50":   ("item:magic_box", 50),
    "mutagen_10":    ("minigame:fat_boss", 10),
    "pack_10":       ("minigame:pizza_party", 10),
    "girl_20":       ("item:girl", 20),
    # Автоматы
    "slot_x3":       ("slot_best_match", 3),
    "slot_100":      ("slot_spins", 100),
    "slot_jackpot":  ("slot_jackpot", 1),
    # Таблица лидеров.
    #
    # Место тем лучше, чем оно МЕНЬШЕ, а счётчик умеет только расти — поэтому
    # хранится не место, а `101 − лучшее место за неделю` (0, если в сотню не
    # попал). Лестница на нём получается настоящая, с осмысленным процентом:
    # игрок на 50-м месте имеет 51 из 91 до топ-10, то есть «уже больше
    # половины пути», а не «ноль до самого попадания».
    "top100":        ("best_rank_inv", 1),
    "top10":         ("best_rank_inv", 91),
    "top1":          ("best_rank_inv", 100),
    "all_modes":     ("modes_ranked_week", 4),
    # Скрытые
    "barrel_death":  ("death_by:bum_barrel", 1),
    "night_owl":     ("night_run", 1),
    "remote_10":     ("tv_remote", 10),
    "pacifist":      ("no_spell_episode", 1),
}


def _check_stats(rows):
    """Состав STATS обязан совпадать со спекой — иначе сборка падает."""
    spec = {r["id"] for r in rows}
    mine = set(STATS)
    missing = sorted(spec - mine)
    extra = sorted(mine - spec)
    if missing or extra:
        raise SystemExit(
            "STATS разошлась со спекой.\n  нет счётчика: %s\n  лишние: %s"
            % (missing or "—", extra or "—"))
    # Внутри лестницы порог обязан РАСТИ: ступень, оказавшаяся легче
    # предыдущей, — это перепутанные местами строки, и в таблице на 78 строк
    # глазами это не ловится.
    from achievements_xlsx import CHAINS
    for name, ids in CHAINS:
        goals = [STATS[i][1] for i in ids if STATS[i][0] == STATS[ids[0]][0]]
        if goals != sorted(goals):
            raise SystemExit("лестница «%s»: пороги не растут — %s" % (name, goals))


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    rows = parse(SRC)
    # Тот же разбор лестниц, что и в выгрузке: он проставляет «Лестница» и
    # «Ступень» и заодно ловит ссылку на несуществующее достижение.
    _check_chains(rows)
    _check_stats(rows)

    out = []
    w = out.append
    w("class_name Achievements")
    w("extends RefCounted")
    w("")
    w("# ── Таблица достижений ────────────────────────────────────────────────────────")
    w("# ФАЙЛ СГЕНЕРИРОВАН: dev/tools/achievements_gd.py из Концепция/Достижения.md.")
    w("# Править надо СПЕКУ и перегенерировать — правка здесь потеряется при первой же")
    w("# пересборке, а список разъедется со спекой и с выгрузкой в App Store Connect.")
    w("#")
    w("# Достижение описано счётчиком и порогом, а не «условием». Условие пришлось бы")
    w("# вычислять, а счётчик просто лежит, и из него бесплатно получается ПРОЦЕНТ —")
    w("# он нужен и полоске на экране, и Game Center, который принимает")
    w("# percentComplete, а не «да/нет». Разовые достижения — это goal = 1, отдельного")
    w("# вида для них не нужно.")
    w("#")
    w("# `stat` пока НЕ СЧИТАЕТСЯ НИКЕМ: машинерии счётчиков ещё нет, экран собран на")
    w("# моках (см. mock_progress). Имена счётчиков при этом настоящие — под них")
    w("# и будут заводиться хуки.")
    w("#")
    w("# См. /Концепция/Достижения.md")
    w("")
    w("# Вес: 1 бронза (5 очков), 2 серебро (10), 3 золото (20), 4 платина (30).")
    w("# Потолок Apple — 100 достижений и 1000 очков суммарно; сходится ровно в 1000.")
    w("const TIER_POINTS : Array = [0, 5, 10, 20, 30]")
    w('const TIER_NAMES  : Array = ["", "бронза", "серебро", "золото", "платина"]')
    w("")
    w("# Категории в порядке вкладок экрана.")
    w("const CATEGORIES : Array = [")
    for key, ru, tab in CATS:
        w('\t{ "key": "%s", "title": "%s", "tab": "%s" },' % (key, esc(ru), esc(tab)))
    w("]")
    w("")
    w("const ALL : Array = [")
    for r in rows:
        cat = KEY_BY_RU[r["Категория"]]
        stat, goal = STATS[r["id"]]
        w('\t{ "id": "%s", "cat": "%s", "tier": %d, "wave": %d,'
          % (r["id"], cat, TIER_KEY[r["Вес"]], r["Волна"]))
        w('\t  "title": "%s", "desc": "%s",'
          % (esc(r["Название"]), esc(r["Условие"])))
        w('\t  "stat": "%s", "goal": %d, "hidden": %s, "chain": "%s", "step": "%s" },'
          % (stat, goal, "true" if r["Скрытое"] == "да" else "false",
             esc(r["Лестница"]), r["Ступень"]))
    w("]")
    w("")
    w("static func by_id(aid: String) -> Dictionary:")
    w("\tfor a in ALL:")
    w('\t\tif String(a["id"]) == aid:')
    w("\t\t\treturn a")
    w("\treturn {}")
    w("")
    w("static func in_category(key: String) -> Array:")
    w("\tvar out : Array = []")
    w("\tfor a in ALL:")
    w('\t\tif String(a["cat"]) == key:')
    w("\t\t\tout.append(a)")
    w("\treturn out")
    w("")
    w("static func points(a: Dictionary) -> int:")
    w('\treturn int(TIER_POINTS[int(a["tier"])])')
    w("")
    w("static func total_points() -> int:")
    w("\tvar n := 0")
    w("\tfor a in ALL:")
    w("\t\tn += points(a)")
    w("\treturn n")
    w("")

    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print("собрано: %d достижений → %s" % (len(rows), OUT))


if __name__ == "__main__":
    main()
