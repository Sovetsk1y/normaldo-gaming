# -*- coding: utf-8 -*-
"""Достижения → Game Center (App Store Connect API).

Кнопки «загрузить файлом» в интерфейсе App Store Connect НЕТ. Зато есть
App Store Connect API, и Game Center он покрывает целиком: сами записи, их
переводы и картинки. Семьдесят семь записей руками не заводит никто.

    python3 dev/tools/push_achievements.py --dry-run          # показать план
    python3 dev/tools/push_achievements.py --diff             # сверить с живым
    python3 dev/tools/push_achievements.py --push             # завести/поправить
    python3 dev/tools/push_achievements.py --push --images ДИР # и картинки

Ключ App Store Connect API (заводится в App Store Connect один раз) берётся из
переменных окружения — НЕ из файла в репозитории:

    ASC_ISSUER_ID   идентификатор издателя (uuid)
    ASC_KEY_ID      идентификатор ключа
    ASC_KEY_PATH    путь к файлу .p8  (или ASC_KEY_P8 — само тело ключа)
    ASC_APP_ID      идентификатор приложения в App Store Connect

── Один источник ─────────────────────────────────────────────────────────────
Скрипт НЕ ДЕРЖИТ СВОЙ СПИСОК. Это ровно та ошибка, которая в проекте стреляла
уже трижды (теги резистов, картинки статусов, раскладка предметов в тесте): две
копии одних данных расходятся в первую же правку и расходятся молча.

Источник — Концепция/Достижения.md, разобранная тем же парсером, которым живут
игра и xlsx. Перед выгрузкой скрипт СВЕРЯЕТ спеку с scripts/achievements.gd:
если файл игры не перегенерирован, выгрузка остановится, а не зальёт в Apple то,
чего в игре нет.

── Чего скрипт НЕ ДЕЛАЕТ ────────────────────────────────────────────────────
УДАЛЯТЬ. Ни одного DELETE здесь нет и быть не должно: в Game Center достижение
у игрока не отзывается (GameKit умеет только `resetAchievements`, а он стирает у
игрока ВСЕ достижения приложения разом). Заведённое живёт вечно; лишнее можно
разве что спрятать вручную. Поэтому и `campaign` помечено резервом — оно не
заводится вовсе, пока не начнёт отличаться от `ep3`.

── Что заливается ────────────────────────────────────────────────────────────
| ресурс                              | что несёт                              |
|-------------------------------------|----------------------------------------|
| gameCenterAchievements              | запись: id, очки, скрытое, повторяемое |
| gameCenterAchievementLocalizations  | язык, название, описание               |
| gameCenterAchievementImages         | картинка, загрузка в три шага          |

Идентификатор для кода — `com.normaldo.mobapp.ach.<id>`, и МЕНЯТЬ ЕГО НЕЛЬЗЯ
НИКОГДА: сменённый id — это новое достижение, а старое остаётся у игроков висеть
навсегда.

── Чего этот скрипт НЕ ПРОВЕРЕН ─────────────────────────────────────────────
Формы запросов написаны по документированной модели ресурсов App Store Connect,
но **на живом API не прогонялись** — ключа в этой среде нет. Первый запуск
делать с `--diff`: он только читает, и если формы не сходятся, это станет видно
до того, как в Apple что-то уедет.

Отдельно не сделан **выпуск версии** (`gameCenterAchievementReleases`): заведённое
достижение, возможно, нужно ещё привязать к версии приложения, чтобы оно стало
видно игрокам. Гадать об этом здесь нечего — проверяется на первом заведённом.

См. /Концепция/Достижения.md
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from achievements_xlsx import ROOT, SRC, parse, _check_chains  # noqa: E402
from achievements_gd import STATS, TIER_KEY, _check_stats  # noqa: E402

GD = ROOT / "dev" / "Normaldo-game" / "scripts" / "achievements.gd"

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE = "com.normaldo.mobapp"
LOCALE = "ru"          # игра русская; при выходе на другие языки список переводится целиком
TIER_POINTS = [0, 5, 10, 20, 30]

# Картинка: 512×512 или 1024×1024, png/jpg/tif, не меньше 72 DPI, RGB.
#
# СТРОГО ЛИ Apple ТРЕБУЕТ картинку — в документации прямо не сказано: справка
# описывает её как свойство достижения и советует добавить, обязательности не
# заявляет. Поэтому картинки здесь НЕОБЯЗАТЕЛЬНЫ: без `--images` заводятся сами
# записи, и ответ сервера на первом же достижении покажет, хватает ли этого.
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".tif", ".tiff")


# ── Данные ───────────────────────────────────────────────────────────────────

def rows():
    """Достижения из спеки, с проверками, и сверка с файлом игры."""
    rs = parse(SRC)
    _check_chains(rs)
    _check_stats(rs)
    _verify_game_file(rs)
    return rs


def _verify_game_file(rs):
    """Файл игры обязан совпадать со спекой по составу id.

    Иначе выгрузка зальёт в Apple то, чего в игре нет, — и наоборот: игрок
    получит достижение, которого в Game Center не существует. Обе половины
    ломаются молча, а разъезжаются они ровно тогда, когда спеку поправили и
    забыли перегенерировать.
    """
    if not GD.exists():
        raise SystemExit("нет %s — сначала dev/tools/achievements_gd.py" % GD)
    text = GD.read_text(encoding="utf-8")
    missing = [r["id"] for r in rs if '"id": "%s"' % r["id"] not in text]
    if missing:
        raise SystemExit(
            "scripts/achievements.gd отстал от спеки (нет: %s).\n"
            "Перегенерируйте: python3 dev/tools/achievements_gd.py"
            % ", ".join(missing))


def payload(r):
    """Одна строка спеки → то, что понимает App Store Connect."""
    return {
        "ref":       "%s.ach.%s" % (BUNDLE, r["id"]),
        "id":        r["id"],
        "points":    TIER_POINTS[TIER_KEY[r["Вес"]]],
        "hidden":    r["Скрытое"] == "да",
        # ПОВТОРЯЕМЫХ у нас нет. «Повторяемое» в Game Center — это достижение,
        # которое игрок берёт много раз (ежедневный вход и подобное); наши
        # лестницы устроены иначе — это разные достижения с разными порогами.
        "repeat":    False,
        "title":     r["Название"],
        "desc":      r["Условие"],
        # Описание ДО открытия. У скрытых Apple всё равно показывает «???», но
        # поле обязательное, и пустое оно не пройдёт.
        "before":    "???" if r["Скрытое"] == "да" else r["Условие"],
    }


# ── Ключ и запросы ───────────────────────────────────────────────────────────

def token():
    """JWT для App Store Connect: подписывается ES256 ключом .p8."""
    issuer = os.environ.get("ASC_ISSUER_ID", "")
    key_id = os.environ.get("ASC_KEY_ID", "")
    key_p8 = os.environ.get("ASC_KEY_P8", "")
    key_path = os.environ.get("ASC_KEY_PATH", "")
    if key_path and not key_p8:
        key_p8 = Path(key_path).read_text(encoding="utf-8")
    if not (issuer and key_id and key_p8):
        raise SystemExit(
            "нет ключа App Store Connect. Нужны переменные окружения "
            "ASC_ISSUER_ID, ASC_KEY_ID и ASC_KEY_PATH (или ASC_KEY_P8).")
    try:
        import jwt  # PyJWT
    except ImportError:
        raise SystemExit("нужен PyJWT: pip3 install 'pyjwt[crypto]'")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
        key_p8, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})


def call(method, path, tok, body=None, raw=None, headers=None):
    """Запрос к API. urllib, чтобы не тащить зависимость ради шести вызовов."""
    import urllib.error
    import urllib.request
    url = path if path.startswith("http") else API + path
    hdr = {"Authorization": "Bearer " + tok}
    data = raw
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        hdr["Content-Type"] = "application/json"
    hdr.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=hdr, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read().decode("utf-8")
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        raise SystemExit("%s %s → %d\n%s" % (method, url, e.code, detail))


def detail_id(tok, app_id):
    """Идентификатор gameCenterDetail приложения.

    Достижения висят НЕ НА ПРИЛОЖЕНИИ, а на его `gameCenterDetail` — отдельном
    ресурсе «состояние Game Center у этого приложения». Первая версия скрипта
    цепляла их прямо к `app`, и это было неверно.
    """
    res = call("GET", "/apps/%s/gameCenterDetail" % app_id, tok)
    d = res.get("data")
    if not d:
        raise SystemExit(
            "у приложения %s нет gameCenterDetail — Game Center ему ещё не "
            "включали в App Store Connect" % app_id)
    return d["id"]


def live(tok, det_id):
    """Что уже заведено в Game Center: ref → запись."""
    out, url = {}, "/gameCenterDetails/%s/achievements?limit=200" % det_id
    while url:
        page = call("GET", url, tok)
        for a in page.get("data", []):
            out[a["attributes"]["referenceName"]] = a
        url = page.get("links", {}).get("next")
    return out


# ── Действия ─────────────────────────────────────────────────────────────────

def create(tok, det_id, p):
    a = call("POST", "/gameCenterAchievements", tok, {
        "data": {
            "type": "gameCenterAchievements",
            "attributes": {
                "referenceName": p["ref"],
                "vendorIdentifier": p["ref"],
                "points": p["points"],
                # СКРЫТОЕ — это «не показывать ДО открытия». Поле названо от
                # обратного, и знак здесь легко перепутать: скрытое достижение
                # это showBeforeEarned = false.
                "showBeforeEarned": not p["hidden"],
                "repeatable": p["repeat"],
            },
            "relationships": {"gameCenterDetail": {
                "data": {"type": "gameCenterDetails", "id": det_id}}},
        }})
    return a["data"]["id"]


def localize(tok, ach_id, p):
    return call("POST", "/gameCenterAchievementLocalizations", tok, {
        "data": {
            "type": "gameCenterAchievementLocalizations",
            "attributes": {
                "locale": LOCALE,
                "name": p["title"],
                "beforeEarnedDescription": p["before"],
                "afterEarnedDescription": p["desc"],
            },
            "relationships": {"gameCenterAchievement": {
                "data": {"type": "gameCenterAchievements", "id": ach_id}}},
        }})["data"]["id"]


# ── Картинки ─────────────────────────────────────────────────────────────────
# КАРТИНКА ВИСИТ НЕ НА ДОСТИЖЕНИИ, А НА ЕГО ЛОКАЛИЗАЦИИ. Из этого следует то,
# ради чего разделение и сделано: заводить записи можно СЕЙЧАС, а картинки
# приносить потом, по мере готовности. Догрузка ничего в самой записи не
# трогает — ни `vendorIdentifier`, ни очки, ни то, что уже открыто у игроков.
#
# Тридцать девять иконок — работа художника, и ждать её, чтобы начать заводить
# семьдесят семь записей, незачем.

def localization(tok, ach_id):
    """Локализация достижения на нашем языке: (id, есть ли уже картинка)."""
    res = call("GET", "/gameCenterAchievements/%s/localizations"
               "?include=gameCenterAchievementImage" % ach_id, tok)
    for loc in res.get("data", []):
        if loc["attributes"].get("locale") != LOCALE:
            continue
        rel = loc.get("relationships", {}).get("gameCenterAchievementImage", {})
        return loc["id"], rel.get("data") is not None
    return None, False


def drop_image(tok, img_id):
    """Снять старую картинку. Удалять КАРТИНКУ безопасно — в отличие от самого
    достижения, которое у игроков не отзывается."""
    call("DELETE", "/gameCenterAchievementImages/" + img_id, tok)


def find_image(images_dir, aid):
    if not images_dir:
        return None
    for ext in IMAGE_EXT:
        f = Path(images_dir) / (aid + ext)
        if f.exists():
            return f
    return None


def upload_image(tok, loc_id, path):
    """Картинка грузится в три шага, как все ассеты App Store Connect."""
    import hashlib
    blob = path.read_bytes()
    res = call("POST", "/gameCenterAchievementImages", tok, {
        "data": {
            "type": "gameCenterAchievementImages",
            "attributes": {"fileName": path.name, "fileSize": len(blob)},
            "relationships": {"gameCenterAchievementLocalization": {
                "data": {"type": "gameCenterAchievementLocalizations", "id": loc_id}}},
        }})
    img = res["data"]
    for op in img["attributes"]["uploadOperations"]:
        hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = blob[op["offset"]:op["offset"] + op["length"]]
        call(op["method"], op["url"], tok, raw=chunk, headers=hdr)
    call("PATCH", "/gameCenterAchievementImages/" + img["id"], tok, {
        "data": {
            "type": "gameCenterAchievementImages",
            "id": img["id"],
            "attributes": {"uploaded": True,
                           "sourceFileChecksum": hashlib.md5(blob).hexdigest()},
        }})


# ── Главное ──────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Достижения → Game Center")
    ap.add_argument("--dry-run", action="store_true",
                    help="показать, что было бы залито, и выйти")
    ap.add_argument("--diff", action="store_true",
                    help="сверить спеку с тем, что заведено в App Store Connect")
    ap.add_argument("--push", action="store_true",
                    help="завести недостающие достижения")
    ap.add_argument("--images", metavar="ДИР",
                    help="папка с картинками: <id>.png рядом по имени достижения. "
                         "Можно позже и отдельным заходом — картинка висит на "
                         "локализации, а не на самой записи")
    ap.add_argument("--replace-images", action="store_true",
                    help="перезалить и там, где картинка уже стоит")
    args = ap.parse_args()

    rs = rows()
    # ЗАРЕЗЕРВИРОВАННОЕ НЕ ЗАВОДИТСЯ. Ошибка здесь необратима — см. шапку.
    ship = [payload(r) for r in rs if not r.get("Резерв")]
    held = [r["id"] for r in rs if r.get("Резерв")]
    print("в спеке %d, к заведению %d, в резерве %d (%s)"
          % (len(rs), len(ship), len(held), ", ".join(held) or "—"))

    total = sum(p["points"] for p in ship)
    print("очков в выгрузке: %d (потолок Apple — 1000 на приложение)" % total)
    if len(ship) > 100:
        raise SystemExit("достижений больше ста — Apple столько не примет")
    if total > 1000:
        raise SystemExit("очков больше тысячи — Apple столько не примет")

    if args.images:
        got = sum(1 for p in ship if find_image(args.images, p["id"]))
        print("картинок в %s: %d из %d" % (args.images, got, len(ship)))

    if args.dry_run or not (args.diff or args.push):
        for p in ship:
            img = find_image(args.images, p["id"])
            print("  %-14s %3d оч.  %-24s %s%s"
                  % (p["id"], p["points"], p["title"],
                     "скрытое " if p["hidden"] else "",
                     img.name if img else ""))
        if not (args.diff or args.push):
            print("\nничего не отправлено: нужен --push (или --diff для сверки)")
        return

    app_id = os.environ.get("ASC_APP_ID", "")
    if not app_id:
        raise SystemExit("нет ASC_APP_ID — идентификатора приложения")
    tok = token()
    det_id = detail_id(tok, app_id)
    have = live(tok, det_id)
    new = [p for p in ship if p["ref"] not in have]
    print("заведено сейчас: %d, из них наших %d; новых: %d"
          % (len(have), len(ship) - len(new), len(new)))

    if args.diff:
        # Расхождение по очкам не лечится само: очки — часть записи, и заметить
        # разницу глазами в списке на семьдесят семь строк нельзя.
        for p in ship:
            cur = have.get(p["ref"])
            if cur and int(cur["attributes"].get("points", 0)) != p["points"]:
                print("  ! %s: очков %s, в спеке %d"
                      % (p["id"], cur["attributes"].get("points"), p["points"]))
        for ref in sorted(have):
            if ref.startswith(BUNDLE + ".ach.") and ref not in {p["ref"] for p in ship}:
                # Удалить нельзя (см. шапку) — только показать.
                print("  ? %s заведено, но в спеке его нет" % ref)
        return

    made = {}
    for p in new:
        ach_id = create(tok, det_id, p)
        localize(tok, ach_id, p)
        made[p["ref"]] = ach_id
        print("  + %s" % p["id"])
    if new:
        print("заведено: %d" % len(new))

    if not args.images:
        if new:
            print("картинок не грузили — придут позже, тем же скриптом "
                  "с --images ДИР")
        return

    # ── Догрузка картинок ────────────────────────────────────────────────────
    # Идёт по ВСЕМ достижениям выгрузки, а не только по свежесозданным: в этом
    # и смысл — заводим сейчас, картинки приносим по мере готовности.
    put = skip = miss = 0
    for p in ship:
        img = find_image(args.images, p["id"])
        if img is None:
            miss += 1
            continue
        ach_id = made.get(p["ref"]) or have.get(p["ref"], {}).get("id")
        if ach_id is None:
            continue
        loc_id, has_img = localization(tok, ach_id)
        if loc_id is None:
            print("  ? %s: нет локализации %s" % (p["id"], LOCALE))
            continue
        if has_img and not args.replace_images:
            skip += 1
            continue
        if has_img:
            cur = call("GET", "/gameCenterAchievementLocalizations/%s"
                       "/gameCenterAchievementImage" % loc_id, tok)
            if cur.get("data"):
                drop_image(tok, cur["data"]["id"])
        upload_image(tok, loc_id, img)
        put += 1
        print("  🖼 %s ← %s" % (p["id"], img.name))
    print("картинки: загружено %d, уже стояли %d, файла нет у %d"
          % (put, skip, miss))


if __name__ == "__main__":
    main()
