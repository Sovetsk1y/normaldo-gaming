extends Node

# СЛОВАРЬ РЕЖИМОВ таблицы лидеров: их имена, подписи и лестница призов.
#
# Раньше этот файл назывался `leaderboard_mock.gd` и был источником ПОКАЗНЫХ
# данных: сорок выдуманных ников, двести выдуманных очков на режим, выдуманное
# «31 место из 1247» и выдуманный отсчёт «призы через 3 д 14 ч». Пока сервер
# молчал (а он молчит в тестах, на сборке без сети и просто до ответа), экран
# показывал всё это молча и неотличимо от настоящего — то есть врал игроку
# ровно в том месте, где вся ценность в честности числа.
#
# Выдуманных данных здесь больше нет. Сервер не ответил — экран так и говорит.
# Осталось то, что данными не является: перечень режимов и таблица призов за
# место, одинаковая с серверной (см. dev/firebase/functions/src/index.ts).
#
# ── Четыре режима, а не две метрики ──────────────────────────────────────────
# Раньше таблиц было две: «рекорд забега» и «гора пицц» — обе про ОДИН режим,
# бесконечный. Вторая складывала пиццы за неделю, то есть мерила не игру, а
# усидчивость: наверху оказывался не тот, кто играет лучше, а тот, кто играет
# дольше. Убрана.
#
# Режимов теперь четыре, и каждый ведёт свою таблицу рекордов: три эпизода
# кампании и бесконечный. Эпизод — отрезок фиксированной длины с боссом в
# конце, и рекорд в нём сравним между игроками честно: у всех одна и та же
# дистанция. Бесконечный сравнивает, кто дальше уехал.
#
# См. /Концепция/Экран лидеров.md
enum Mode { EP1 = 0, EP2 = 1, EP3 = 2, ENDLESS = 3 }

# Порядок вкладок на экране и он же порядок в enum.
const MODES : Array = [Mode.EP1, Mode.EP2, Mode.EP3, Mode.ENDLESS]

# Имя режима на сервере — то же самое лежит в `SaveData.mode_best`.
const MODE_KEYS : Array = ["ep1", "ep2", "ep3", "endless"]

# Подпись на вкладке. Коротко: вкладок четыре, а полоса под них одна.
const MODE_LABELS : Array = ["ЭПИЗОД 1", "ЭПИЗОД 2", "ЭПИЗОД 3", "БЕСКОНЕЧНЫЙ"]

func mode_key(mode: int) -> String:
	return String(MODE_KEYS[clampi(mode, 0, MODE_KEYS.size() - 1)])

func mode_label(mode: int) -> String:
	return String(MODE_LABELS[clampi(mode, 0, MODE_LABELS.size() - 1)])

# Номер эпизода (1…3) для режима-эпизода; 0 для бесконечного.
func mode_episode(mode: int) -> int:
	return 0 if mode == Mode.ENDLESS else mode + 1

func mode_for_episode(episode: int) -> int:
	return Mode.ENDLESS if episode <= 0 else clampi(episode - 1, 0, Mode.EP3)

func reward_for_place(place: int) -> Dictionary:
	if place == 1:  return {"dollars": 5000, "tokens": 10}
	if place <= 3:  return {"dollars": 2500, "tokens": 5}
	if place <= 10: return {"dollars": 1000, "tokens": 2}
	if place <= 50: return {"dollars": 300,  "tokens": 1}
	if place <= 100:return {"dollars": 100,  "tokens": 1}
	return {"dollars": 0, "tokens": 1}

# Сколько осталось до сброса недели. Считается ЧЕСТНО — до ближайшего
# понедельника 00:00 UTC, потому что именно по ISO-неделям сервер и раскладывает
# таблицы (`getCurrentWeekId`). Раньше здесь лежала константа «3 д 14 ч 22 мин»,
# которая не двигалась между запусками и означала ровно ничего.
func seconds_to_week_reset() -> float:
	var now := Time.get_datetime_dict_from_system(true)
	# `weekday` в Godot: 0 — воскресенье. Переводим в ISO, где 1 — понедельник.
	var iso_day : int = int(now["weekday"])
	iso_day = 7 if iso_day == 0 else iso_day
	var days_left : int = 7 - iso_day
	var secs_today : int = int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"])
	return float(days_left * 86400 + (86400 - secs_today))
