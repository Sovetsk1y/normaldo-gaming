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

	# Скин ПРИБИТ к классике. Пик раздувания считается от нарисованной головы, а
	# она у каждого скина своя — и тест, читающий скин из сейва, зависел от того,
	# какой прогон был перед ним: smoke_skins оставляет на диске последний скин
	# реестра, и пороги здесь то проходили, то нет.
	var save : Node = get_root().get_node_or_null("SaveData")
	if save != null:
		save.active_skin = "classic"
		normaldo.call("reload_skin")
		await process_frame

	print("── Взял мутаген — стал большим ──")
	await _test_start(boss, normaldo)
	print("── Не тапаешь — уменьшаешься ──")
	await _test_shrink(boss, normaldo)
	print("── Тапаешь — держишься жирным ──")
	await _test_tap_holds(boss, normaldo)
	print("── Амплитуда тапа и потолок ──")
	await _test_tap_punch(boss, normaldo)
	print("── Раздувание слабеет со временем ──")
	await _test_stamina(boss, normaldo)
	print("── Тап разгоняет поток ──")
	await _test_stream(boss, normaldo)
	print("── Мини-игра всегда кончается ──")
	await _test_always_ends(boss, normaldo)
	print("── Подсказка TAP! ──")
	await _test_prompt(boss)
	print("── Возврат в забег ──")
	await _test_return_guard(boss, normaldo)
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

	# Голова видна на экране целиком-почти: три четверти лица, а не половина за
	# краем. И за мини-игру она НЕ ползает — стоит на одном месте.
	var vp : Vector2 = get_root().get_visible_rect().size
	var anchor_x : float = boss.call("boss_anchor", vp).x
	var head_w : float = float(boss.call("_boss_head_w"))
	_check(anchor_x > head_w * 0.15,
		"центр головы отодвинут от края: x=%.0f при ширине головы %.0f"
			% [anchor_x, head_w])
	var x0 : float = (normaldo as Node2D).position.x
	await _play(boss, 3.0, 0.0)
	# Допуск в 2 % ширины: сам Нормальдо каждый кадр подтягивает себя в кадр и
	# смещается на единицы пикселей. Ловим мы не это, а прежний дрейф якоря —
	# он был в десятки пикселей.
	_check(absf((normaldo as Node2D).position.x - x0) < vp.x * 0.02,
		"за мини-игру босс не ползает: x=%.0f → %.0f"
			% [x0, (normaldo as Node2D).position.x])
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

	# Отдача чуть падает с ростом жира, но основную работу делают потолок сверху
	# и затухание со временем (см. ниже) — иначе тап перестаёт ощущаться.
	boss.set("_bar", 0.0)
	var gain_low : float = float(boss.call("tap_gain"))
	boss.set("_bar", 1.0)
	var gain_high : float = float(boss.call("tap_gain"))
	_check(gain_high < gain_low and gain_high > gain_low * 0.3,
		"у полного жира тап даёт меньше, но не в ноль: %.3f против %.3f"
			% [gain_high, gain_low])
	boss.call("_end_minigame")
	await _await_idle(boss)

# То, ради чего этот заход и делался: тап обязан ЗАМЕТНО вспухать голову.
# Раньше импульс был 0.03 — «еле трясётся», и ощущения «получается» не было.
func _test_tap_punch(boss: Node, normaldo: Node) -> void:
	await _begin(boss, 0.55)
	await _play(boss, 0.4, 0.0)
	var calm : float = _factor(normaldo)
	# Несколько тапов подряд — импульс накапливается.
	for _i in 4:
		boss.call("_on_tap")
		await process_frame
	var punched : float = _factor(normaldo)
	_check(punched > calm * 1.35,
		"тап заметно вспухает голову: ×%.2f → ×%.2f" % [calm, punched])
	boss.call("_end_minigame")
	await _await_idle(boss)

	# И при этом есть ПОТОЛОК: сколько ни мэшь, выше пика на OVERSHOOT_MAX не
	# раздуться. Иначе голова уезжает за пределы кадра и мини-игра ломается.
	await _begin(boss, 1.0)
	var peak : float = float(boss.get("_max_factor"))
	var cap  : float = peak * float(boss.get("OVERSHOOT_MAX"))
	var worst := 0.0
	for _i in 240:
		boss.call("_on_tap")
		await process_frame
		worst = maxf(worst, _factor(normaldo))
	_check(worst <= cap + 0.01,
		"потолок раздувания держится: ×%.2f при пределе ×%.2f" % [worst, cap])
	_check(worst > peak,
		"но выше пика раздуться всё-таки можно: ×%.2f при пике ×%.2f" % [worst, peak])
	boss.call("_end_minigame")
	await _await_idle(boss)

# Заявленный способ закончить мини-игру: раздувание с тапа слабеет со временем.
func _test_stamina(boss: Node, _normaldo: Node) -> void:
	await _begin(boss, 0.5)
	boss.set("_play_time", 0.0)
	var early : float = float(boss.call("tap_gain"))
	boss.set("_play_time", 100.0)
	var late : float = float(boss.call("tap_gain"))
	_check(late < early * 0.2,
		"со временем тап раздувает заметно слабее: %.4f против %.4f" % [late, early])
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
	# Сдувание нарочно быстрое: мини-игра должна ощущаться как удержание, а не
	# как медленное таяние. Нижняя граница — чтобы игрок всё-таки успел понять,
	# что происходит, и нажать.
	_check(quick > 1.2 and quick < 15.0,
		"без тапов сдувается за разумное время: %.1f c" % quick)
	await _await_idle(boss)

# Отдельно — защита от старой поломки: возвращать голову вплотную к левому краю
# нельзя, оттуда забег непроходим — предметы прилетают сразу на голову.
# Сравнение идёт с КРАЕМ: раньше сравнивалось с якорем босса, но якорь уехал в
# играбельное место и такая проверка начала срабатывать на обычной позиции.
# Подсказка мини-игры — КАРТИНКА «TAP!» и два тапающих пальца по бокам, а не
# слово, набранное шрифтом. Ломается это молча: достаточно вернуть Label, и на
# экране снова появится отладочного вида подпись — тесты механики не заметят.
#
# Узел общий с пицца-пати (scripts/tap_prompt.gd), поэтому проверка одна на обе
# мини-игры: пицца-пати достаточно поставить тот же узел.
func _test_prompt(boss: Node) -> void:
	await _begin(boss, 1.0)
	boss.call("_show_prompt")
	await process_frame
	var root : Node2D = boss.get("_title_root")
	_check(is_instance_valid(root), "подсказка собралась")
	if not is_instance_valid(root):
		return
	_check(root.get_script() == boss.TAP_PROMPT,
		"подсказка — общий кирпич tap_prompt.gd, а не своя копия")

	var labels : Array = []
	var sprites : Array = []
	for c in root.get_children():
		if c is Label:
			labels.append(c)
		elif c is Sprite2D:
			sprites.append(c)
	_check(labels.is_empty(), "слова в подсказке нет — только картинки")
	_check(sprites.size() == 3, "картинка TAP! и два пальца: %d спрайтов" % sprites.size())

	var tap : Sprite2D = null
	var fingers : Array = []
	for s in sprites:
		if (s as Sprite2D).texture == root.TAP_TEX:
			tap = s
		else:
			fingers.append(s)
	_check(tap != null, "картинка TAP! на месте")
	_check(fingers.size() == 2, "пальцев ровно два")
	if fingers.size() == 2:
		var x0 : float = (fingers[0] as Sprite2D).position.x
		var x1 : float = (fingers[1] as Sprite2D).position.x
		_check(x0 * x1 < 0.0, "пальцы по РАЗНЫЕ стороны: %.0f и %.0f" % [x0, x1])
		# Левый и правый нарисованы ОТДЕЛЬНО, а не зеркалятся: у них по-разному
		# лежит большой палец. Зеркальный спрайт вместо своего кадра — молчаливая
		# потеря половины авторской раскладки.
		_check((fingers[0] as Sprite2D).texture != (fingers[1] as Sprite2D).texture,
			"у левого и правого пальца СВОИ кадры")
		for f in fingers:
			_check((f as Sprite2D).scale.x > 0.0,
				"палец не зеркалится масштабом: ×%.2f" % (f as Sprite2D).scale.x)

	# Полный цикл тапа: палец обязан и уехать вниз, и сменить кадр на прижатый.
	# Кадр без движения — это мигание, движение без кадра — качание.
	var f0 : Sprite2D = fingers[0]
	var up : Texture2D = f0.texture
	var y0 : float = f0.position.y
	var low : float = y0
	var pressed := false
	var t0 : float = Time.get_ticks_msec() / 1000.0
	var cycle : float = float(root.DOWN_T) + float(root.HOLD_T) \
		+ float(root.UP_T) + float(root.REST_T)
	while Time.get_ticks_msec() / 1000.0 - t0 < cycle * 1.6:
		low = maxf(low, f0.position.y)
		if f0.texture != up:
			pressed = true
		await process_frame
	_check(low - y0 > float(root.DROP) * 0.7,
		"палец уходит вниз на %.0f px при ходе %.0f" % [low - y0, root.DROP])
	_check(pressed, "в нижней точке кадр меняется на прижатый")

	# Проверка БЕЗ ожидания кадра: мини-игра простаивает, и на следующем же
	# `_process` она честно покажет подсказку заново.
	boss.call("_hide_prompt")
	_check(root.get("_taps").is_empty(), "твины пальцев погашены вместе с подсказкой")
	boss.call("_end_minigame")
	await _await_idle(boss)

func _test_return_guard(boss: Node, normaldo: Node) -> void:
	var vp : Vector2 = get_root().get_visible_rect().size
	(normaldo as Node2D).position = Vector2(0.0, vp.y * 0.5)
	await _begin(boss, 1.0)
	var back : Vector2 = boss.get("_pre_boss_pos")
	_check(back.x >= vp.x * float(boss.RETURN_MIN_FRAC) - 0.5,
		"старт у самого края не делает точкой возврата край: x=%.0f" % back.x)
	boss.call("_end_minigame")
	await _await_idle(boss)

	# А обычную позицию забега трогать не за что: она возвращается как есть.
	var home := Vector2(vp.x * 0.23, vp.y * 0.5)
	(normaldo as Node2D).position = home
	await _begin(boss, 1.0)
	var back2 : Vector2 = boss.get("_pre_boss_pos")
	_check(absf(back2.x - home.x) < 1.0,
		"обычная позиция забега возвращается как есть: x=%.0f (было %.0f)"
			% [back2.x, home.x])
	boss.call("_end_minigame")
	await _await_idle(boss)

func _test_restore(boss: Node, normaldo: Node) -> void:
	var pos_before : Vector2 = (normaldo as Node2D).position
	await _begin(boss, 1.0)
	var vp : Vector2 = get_root().get_visible_rect().size
	var anchor : Vector2 = boss.call("boss_anchor", vp)
	_check(absf((normaldo as Node2D).position.x - anchor.x) < vp.x * 0.05,
		"на полном жире голова у якоря босса: x=%.0f" % (normaldo as Node2D).position.x)
	# И возвращаться она обязана в играбельное место, а не к самому краю.
	var back : Vector2 = boss.get("_pre_boss_pos")
	_check(back.x > vp.x * 0.10,
		"точка возврата не у левого края: x=%.0f" % back.x)
	await _play(boss, 30.0, 0.0)
	# Аутро сдувает голову и возвращает забег. Запас кадров с добавлением печати
	# SLAKE BAKE в окно итогов вырос: такт длится около полутора секунд, и
	# прежних пяти секунд ожидания стало впритык.
	for _i in 600:
		if int(boss.get("_state")) == 0:   # State.IDLE
			break
		await process_frame
	_check(int(boss.get("_state")) == 0, "мини-игра вернулась в IDLE")
	_check(absf(_factor(normaldo) - 1.0) < 0.05,
		"размер вернулся к обычному: ×%.2f" % _factor(normaldo))
	_check(not bool(boss.call("is_busy")), "мини-игра больше не занята")
