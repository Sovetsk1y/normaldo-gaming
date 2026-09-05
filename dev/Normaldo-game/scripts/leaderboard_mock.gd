extends Node

# Локальный источник данных таблицы лидеров: им живёт экран, пока сервер не
# ответил (или его нет вовсе — в тестах и на сборке без сети).
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

const NAMES_POOL : Array = [
	"Hamilton",  "PizzaFan",  "Normaldo",   "GreyHat",   "Cat",
	"Mongoose",  "Tony",      "Sushi",      "Pavel",     "Vasil",
	"Wendy",     "Igor",      "Banana",     "TheKing",   "Joker",
	"MrPizza",   "Headshot",  "NightCrwl",  "Dragon",    "Slim",
	"FastFngrs", "Slowpoke",  "Elephant",   "Lupin",     "Saracen",
	"Kvasov",    "Borodin",   "Lev",        "Kostya",    "Anya",
	"Foggy",     "TacoBoy",   "Iceberg",    "Storm",     "Phoenix",
	"Cosmic",    "Pinky",     "Velvet",     "Trickster", "Nameless",
]

# Место игрока, его результат и прирост — по режимам. Эпизоды короче
# бесконечного, поэтому и цифры в них меньше: показная таблица обязана быть
# правдоподобной, иначе по ней нельзя проверить вёрстку.
const MOCK_PLAYER_RANK  : Array = [31, 58, 96, 47]
const MOCK_PLAYER_SCORE : Array = [186, 214, 240, 123]
const MOCK_PLAYER_DELTA : Array = [7, 4, 2, 12]
const MOCK_PLAYER_NEW   : Array = [true, false, false, true]
const MOCK_TOP_SCORE    : Array = [305, 348, 372, 412]

const MOCK_TOTAL_PLAYERS       : int   = 1247
const MOCK_RESET_SECONDS_LEFT  : float = 3.0 * 86400.0 + 14.0 * 3600.0 + 22.0 * 60.0

var _cache : Dictionary = {}

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

func get_top_n(mode: int, count: int = 100) -> Array:
	var rows : Array = []
	var player_rank := get_player_rank(mode)
	for r in range(1, count + 1):
		if r == player_rank:
			rows.append(_player_row(mode))
		else:
			rows.append(_row_at(mode, r))
	return rows

func get_window_around_player(mode: int, radius: int = 5) -> Array:
	var rank := get_player_rank(mode)
	var first := maxi(1, rank - radius)
	var last  := rank + radius
	var rows : Array = []
	for r in range(first, last + 1):
		if r == rank:
			rows.append(_player_row(mode))
		else:
			rows.append(_row_at(mode, r))
	return rows

func get_player_rank(mode: int) -> int:
	return int(MOCK_PLAYER_RANK[clampi(mode, 0, MOCK_PLAYER_RANK.size() - 1)])

func get_player_score(mode: int) -> int:
	return int(MOCK_PLAYER_SCORE[clampi(mode, 0, MOCK_PLAYER_SCORE.size() - 1)])

func get_player_delta(mode: int) -> int:
	return int(MOCK_PLAYER_DELTA[clampi(mode, 0, MOCK_PLAYER_DELTA.size() - 1)])

func get_player_is_new(mode: int) -> bool:
	return bool(MOCK_PLAYER_NEW[clampi(mode, 0, MOCK_PLAYER_NEW.size() - 1)])

func get_total_players() -> int:
	return MOCK_TOTAL_PLAYERS

func get_reset_seconds() -> float:
	return MOCK_RESET_SECONDS_LEFT

func make_mock_prize_reward() -> Dictionary:
	return {
		"metric":       mode_key(Mode.ENDLESS),
		"metric_label": mode_label(Mode.ENDLESS),
		"place":        12,
		"dollars":      1000,
		"tokens":       2,
	}

# ── Internal ─────────────────────────────────────────────────────────────────

func _player_row(mode: int) -> Dictionary:
	return {
		"rank":      get_player_rank(mode),
		"name":      "ТЫ",
		"score":     get_player_score(mode),
		"is_player": true,
	}

func _row_at(mode: int, rank: int) -> Dictionary:
	var scores := _ensure_scores(mode)
	var names  := _ensure_names(mode)
	var idx := rank - 1
	var score : int = scores[idx] if idx < scores.size() else 1
	var name  : String = names[idx] if idx < names.size() else "Player%d" % rank
	return {"rank": rank, "name": name, "score": score, "is_player": false}

func _ensure_scores(mode: int) -> Array:
	var key := "scores_%d" % mode
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + mode
	var score : int = int(MOCK_TOP_SCORE[clampi(mode, 0, MOCK_TOP_SCORE.size() - 1)])
	var scores : Array = []
	for i in 200:
		scores.append(score)
		score = maxi(score - rng.randi_range(2, 6), 1)
	_cache[key] = scores
	return scores

func _ensure_names(mode: int) -> Array:
	var key := "names_%d" % mode
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999 + mode * 13
	var names : Array = []
	for i in 200:
		var pool_idx := rng.randi() % NAMES_POOL.size()
		var suffix   := rng.randi_range(10, 999)
		names.append("%s%d" % [NAMES_POOL[pool_idx], suffix])
	_cache[key] = names
	return names
