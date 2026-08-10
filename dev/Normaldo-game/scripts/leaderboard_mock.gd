extends Node

# Mock data source for Phase 1 leaderboard UI.
# Replaced by Firebase calls in Phase 2 (same public API shape).

enum Metric { BEST = 0, TOTAL = 1 }

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

const MOCK_PLAYER_BEST_RANK    : int   = 47
const MOCK_PLAYER_TOTAL_RANK   : int   = 122
const MOCK_PLAYER_BEST_SCORE   : int   = 123
const MOCK_PLAYER_TOTAL_SCORE  : int   = 1820
const MOCK_PLAYER_DELTA_BEST   : int   = 12
const MOCK_PLAYER_DELTA_TOTAL  : int   = 3
const MOCK_PLAYER_NEW_BEST     : bool  = true
const MOCK_PLAYER_NEW_TOTAL    : bool  = false
const MOCK_TOTAL_PLAYERS       : int   = 1247
const MOCK_RESET_SECONDS_LEFT  : float = 3.0 * 86400.0 + 14.0 * 3600.0 + 22.0 * 60.0

var _cache : Dictionary = {}

func reward_for_place(place: int) -> Dictionary:
	if place == 1:  return {"dollars": 5000, "tokens": 10}
	if place <= 3:  return {"dollars": 2500, "tokens": 5}
	if place <= 10: return {"dollars": 1000, "tokens": 2}
	if place <= 50: return {"dollars": 300,  "tokens": 1}
	if place <= 100:return {"dollars": 100,  "tokens": 1}
	return {"dollars": 0, "tokens": 1}

func get_top_n(metric: int, count: int = 100) -> Array:
	var rows : Array = []
	var player_rank := get_player_rank(metric)
	for r in range(1, count + 1):
		if r == player_rank:
			rows.append(_player_row(metric))
		else:
			rows.append(_row_at(metric, r))
	return rows

func get_window_around_player(metric: int, radius: int = 5) -> Array:
	var rank := get_player_rank(metric)
	var first := maxi(1, rank - radius)
	var last  := rank + radius
	var rows : Array = []
	for r in range(first, last + 1):
		if r == rank:
			rows.append(_player_row(metric))
		else:
			rows.append(_row_at(metric, r))
	return rows

func get_player_rank(metric: int) -> int:
	return MOCK_PLAYER_BEST_RANK if metric == Metric.BEST else MOCK_PLAYER_TOTAL_RANK

func get_player_score(metric: int) -> int:
	return MOCK_PLAYER_BEST_SCORE if metric == Metric.BEST else MOCK_PLAYER_TOTAL_SCORE

func get_player_delta(metric: int) -> int:
	return MOCK_PLAYER_DELTA_BEST if metric == Metric.BEST else MOCK_PLAYER_DELTA_TOTAL

func get_player_is_new(metric: int) -> bool:
	return MOCK_PLAYER_NEW_BEST if metric == Metric.BEST else MOCK_PLAYER_NEW_TOTAL

func get_total_players() -> int:
	return MOCK_TOTAL_PLAYERS

func get_reset_seconds() -> float:
	return MOCK_RESET_SECONDS_LEFT

func make_mock_prize_reward() -> Dictionary:
	return {
		"metric":       "best",
		"metric_label": "Рекорд забега",
		"place":        12,
		"dollars":      1000,
		"tokens":       2,
	}

# ── Internal ─────────────────────────────────────────────────────────────────

func _player_row(metric: int) -> Dictionary:
	return {
		"rank":      get_player_rank(metric),
		"name":      "ТЫ",
		"score":     get_player_score(metric),
		"is_player": true,
	}

func _row_at(metric: int, rank: int) -> Dictionary:
	var scores := _ensure_scores(metric)
	var names  := _ensure_names(metric)
	var idx := rank - 1
	var score : int = scores[idx] if idx < scores.size() else 1
	var name  : String = names[idx] if idx < names.size() else "Player%d" % rank
	return {"rank": rank, "name": name, "score": score, "is_player": false}

func _ensure_scores(metric: int) -> Array:
	var key := "scores_%d" % metric
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + metric
	var top_score : int = 412 if metric == Metric.BEST else 3500
	var scores : Array = []
	var score := top_score
	for i in 200:
		scores.append(score)
		var dec : int = rng.randi_range(2, 6) if metric == Metric.BEST else rng.randi_range(15, 60)
		score = maxi(score - dec, 1)
	_cache[key] = scores
	return scores

func _ensure_names(metric: int) -> Array:
	var key := "names_%d" % metric
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999 + metric * 13
	var names : Array = []
	for i in 200:
		var pool_idx := rng.randi() % NAMES_POOL.size()
		var suffix   := rng.randi_range(10, 999)
		names.append("%s%d" % [NAMES_POOL[pool_idx], suffix])
	_cache[key] = names
	return names
