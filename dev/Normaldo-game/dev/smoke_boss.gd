extends SceneTree

# Headless-проверка мини-игры ЖИРОБОСС (мутаген).
#   godot --headless --path . --script res://dev/smoke_boss.gd
#
# Механика держится на одной величине — ЖИРЕ, — и ломается она молча: жир
# перестаёт стекать (мини-игра не кончается), тап перестаёт держать размер
# (тапать незачем), поток не разгоняется (тап ничего не даёт). Глазами это
# ловится только полным прогоном на телефоне.
#
# См. /Концепция/Мини-игра — Жиробосс (мутаген).md

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var boss     : Node = game.get_node_or_null("FatBoss")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	if boss == null or normaldo == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Взял мутаген — стал большим ──")
	await _test_start(boss, normaldo)
	print("── Не тапаешь — уменьшаешься ──")
	await _test_shrink(boss, normaldo)
	print("── Тапаешь — держишься жирным ──")
	await _test_tap_holds(boss, normaldo)
	print("── Тап разгоняет поток ──")
	await _test_stream(boss, normaldo)
	print("── Мини-игра всегда кончается ──")
	await _test_always_ends(boss, normaldo)
	print("── Возврат в забег ──")
	await _test_restore(boss, normaldo)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _begin(boss: Node, bar: float = 1.0) -> void:
	boss.call("dev_begin_play", bar)
	await process_frame

# Дождаться, пока мини-игра доиграет аутро и вернётся в покой. Ждать «столько-то
# секунд» нельзя: аутро асинхронное, и начатая поверх него мини-игра тут же
# обрывается его же корутиной — измеренная длительность выходит вдвое короче.
func _await_idle(boss: Node) -> void:
	for _i in 3000:
		if int(boss.get("_state")) == 0:
			return
		await process_frame

# Прогон фазы Б на `sec` игровых секунд с заданной частотой тапов.
# Возвращает `_play_time` самой мини-игры: считать время своими руками нельзя —
# `get_process_delta_time()` в headless не совпадает с тем `delta`, который
# приходит в `_process`, и измеренная длительность получается вдвое короче
# настоящей. Мини-игра меряет время тем же тактом, что и растит сложность.
func _play(boss: Node, sec: float, taps_per_sec: float) -> float:
	var acc := 0.0
	var guard := 0
	while int(boss.get("_state")) == 2 and float(boss.get("_play_time")) < sec:
		guard += 1
		if guard > 20000:
			break
		if taps_per_sec > 0.0:
			var dt : float = maxf(0.001, get_root().get_tree().root.get_process_delta_time())
			acc += dt * taps_per_sec
			while acc >= 1.0:
				acc -= 1.0
				boss.call("_on_tap")
		await process_frame
	return float(boss.get("_play_time"))

func _factor(normaldo: Node) -> float:
	return float((normaldo as Node2D).scale.x)

# ── Тесты ─────────────────────────────────────────────────────────────────────

func _test_start(boss: Node, normaldo: Node) -> void:
	await _begin(boss, 1.0)
	_check(int(boss.get("_state")) == 2, "фаза Б запустилась")
	# Через кадр жир уже чуть стёк — сравниваем с допуском на один кадр слива.
	_check(float(boss.get("_bar")) > 0.95,
		"жир на старте полный: %.3f" % boss.get("_bar"))
	var peak : float = float(boss.get("_max_factor"))
	_check(peak > 3.0, "пиковый множитель посчитан под экран: ×%.1f" % peak)
	_check(absf(_factor(normaldo) - peak) < peak * 0.05,
		"на старте размер пиковый: ×%.1f при пике ×%.1f" % [_factor(normaldo), peak])
	# Пол размера: даже на нуле жира голова заметно больше обычной.
	var floor_f : float = float(boss.call("fat_factor_for", 0.0))
	_check(floor_f > 1.5 and floor_f < peak,
		"на нуле жира голова ещё большая, но меньше пика: ×%.1f" % floor_f)
	boss.call("_end_minigame")
	await _await_idle(boss)

# Главное в переделке: перестал тапать — сдуваешься НА ГЛАЗАХ.
func _test_shrink(boss: Node, normaldo: Node) -> void:
	await _begin(boss, 1.0)
	var f0 : float = _factor(normaldo)
	await _play(boss, 1.0, 0.0)
	var f1 : float = _factor(normaldo)
	_check(f1 < f0 * 0.95,
		"за секунду без тапов заметно сдулся: ×%.1f → ×%.1f" % [f0, f1])
	_check(float(boss.get("_bar")) < 0.95, "жир стекает: %.2f" % boss.get("_bar"))

	# Сдуваясь, босс отъезжает от края: иначе уменьшение уходит за кадр вместе с
	# головой, и главную обратную связь мини-игры игрок просто не видит.
	var vp : Vector2 = get_root().get_visible_rect().size
	var x_full : float = boss.call("boss_anchor", vp).x
	await _play(boss, 4.0, 0.0)
	_check((normaldo as Node2D).position.x > x_full + vp.x * 0.10,
		"худея, босс отъезжает в кадр: x=%.0f" % (normaldo as Node2D).position.x)
	boss.call("_end_minigame")
	await _await_idle(boss)

# Тап делает ровно две вещи, и первая — держит размер.
func _test_tap_holds(boss: Node, normaldo: Node) -> void:
	# Без тапов с половины жира — падает.
	await _begin(boss, 0.5)
	await _play(boss, 1.5, 0.0)
	var idle_bar : float = float(boss.get("_bar"))
	boss.call("_end_minigame")
	await _await_idle(boss)

	# С тапами с той же половины — держится или растёт.
	await _begin(boss, 0.5)
	await _play(boss, 1.5, 8.0)
	var tap_bar : float = float(boss.get("_bar"))
	_check(tap_bar > idle_bar + 0.1,
		"с тапами жира заметно больше: %.2f против %.2f" % [tap_bar, idle_bar])
	_check(tap_bar >= 0.45,
		"тапая, остаёшься жирным: %.2f" % tap_bar)

	# Отдача падает с ростом жира — иначе максимум держался бы бесконечно.
	boss.set("_bar", 0.0)
	var gain_low : float = float(boss.call("tap_gain"))
	boss.set("_bar", 1.0)
	var gain_high : float = float(boss.call("tap_gain"))
	_check(gain_high < gain_low * 0.5,
		"у полного жира тап даёт меньше: %.3f против %.3f" % [gain_high, gain_low])
	boss.call("_end_minigame")
	await _await_idle(boss)

# Вторая вещь, которую делает тап: разгоняет поток.
func _test_stream(boss: Node, normaldo: Node) -> void:
	await _begin(boss, 0.0)
	await _play(boss, 0.6, 0.0)
	var slow : float = _stream_speed(boss)
	boss.call("_end_minigame")
	await _await_idle(boss)

	await _begin(boss, 1.0)
	await _play(boss, 0.3, 12.0)
	var fast : float = _stream_speed(boss)
	_check(fast > slow * 1.5,
		"на жире поток заметно быстрее: %.0f против %.0f" % [fast, slow])
	boss.call("_end_minigame")
	await _await_idle(boss)

func _stream_speed(boss: Node) -> float:
	var base : float = float(boss.get("_base_item_speed"))
	var bar  : float = float(boss.get("_bar"))
	return base * lerpf(float(boss.get("ITEM_SPEED_SLOW")),
		float(boss.get("ITEM_SPEED_FAST")), bar)

# Даже при бесконечном мэшинге мини-игра обязана закончиться: слив нарастает со
# временем. Иначе игрок застревает в ней навсегда.
func _test_always_ends(boss: Node, normaldo: Node) -> void:
	await _begin(boss, 1.0)
	var lasted : float = await _play(boss, 40.0, 14.0)
	_check(int(boss.get("_state")) != 2,
		"при максимальном тапе мини-игра закончилась за %.1f c" % lasted)
	_check(lasted < float(boss.get("FRENZY_HARD_CAP")),
		"и закончилась ПО ЖИРУ, не по аварийному потолку: %.1f c" % lasted)
	await _await_idle(boss)

	# Без тапов она кончается быстро — но не мгновенно.
	await _begin(boss, 1.0)
	var quick : float = await _play(boss, 30.0, 0.0)
	_check(quick > 2.0 and quick < 15.0,
		"без тапов сдувается за разумное время: %.1f c" % quick)
	await _await_idle(boss)

func _test_restore(boss: Node, normaldo: Node) -> void:
	var pos_before : Vector2 = (normaldo as Node2D).position
	await _begin(boss, 1.0)
	var vp : Vector2 = get_root().get_visible_rect().size
	var anchor : Vector2 = boss.call("boss_anchor", vp)
	_check(absf((normaldo as Node2D).position.x - anchor.x) < vp.x * 0.05,
		"на полном жире голова у якоря босса: x=%.0f" % (normaldo as Node2D).position.x)
	# И возвращаться она обязана НЕ на якорь: иначе забег продолжится вплотную
	# к левому краю. Этот баг уже случался.
	var back : Vector2 = boss.get("_pre_boss_pos")
	_check(back.x > anchor.x + get_root().get_visible_rect().size.x * 0.1,
		"точка возврата не на краю экрана: x=%.0f при якоре %.0f" % [back.x, anchor.x])
	await _play(boss, 30.0, 0.0)
	# Аутро сдувает голову и возвращает забег.
	for _i in 300:
		if int(boss.get("_state")) == 0:   # State.IDLE
			break
		await process_frame
	_check(int(boss.get("_state")) == 0, "мини-игра вернулась в IDLE")
	_check(absf(_factor(normaldo) - 1.0) < 0.05,
		"размер вернулся к обычному: ×%.2f" % _factor(normaldo))
	_check(not bool(boss.call("is_busy")), "мини-игра больше не занята")
