extends SceneTree

# Headless-проверка букв NORMALDO.
#   godot --headless --path . --script res://dev/smoke_letters.gd
#
# Буква — это ОАЗИС и ЧАСЫ одновременно. Как оазис она обязана быть чистой:
# один-единственный посторонний предмет посреди буквы возвращает забег в режим
# уворачивания, и передышки не получается. Как часы она обязана досчитать до
# конца слова и ровно там вызвать босса: эпизод, кончившийся посреди слова, —
# это сломанные часы.
#
# Проверяется поэтому не «буква появилась», а три вещи: форма, чистота и счёт.
#
# См. /Концепция/Паттерны препятствий.md → «Буквы NORMALDO»

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 20

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	await process_frame
	get_root().get_tree().paused = false

	print("── Глифы ──")
	_test_glyphs(sp)
	print("── Одна буква на экране ──")
	await _test_one_letter(sp)
	print("── Слово и босс ──")
	await _test_word(sp)
	print("── WIN после босса ──")
	await _test_win_word(sp)
	_finish()

# Победа над боссом печатает WIN долларами — тем же приёмом, что и буквы.
# Салюта на этом месте больше нет: частицы по краям экрана ничего не дают и
# ничем не отличаются от такого же салюта в лудилке.
#
# Проверяется здесь ровно то, чем слово отличается от буквы: три глифа подряд,
# не слипшиеся, из долларов и во всю высоту.
func _test_win_word(sp: Node) -> void:
	sp.call("clear_items")
	sp.set("_frozen", false)
	await process_frame
	var vp : Vector2 = get_root().get_visible_rect().size

	var word : String = "WIN"
	var miss : Array = []
	for i in word.length():
		if not (sp.LETTER_GLYPHS as Dictionary).has(word[i]):
			miss.append(word[i])
	_check(miss.is_empty(), "глиф есть у каждой буквы WIN: %s" % str(miss))

	var hold : float = float(sp.call("lay_word", word, false))
	await process_frame
	var items : Array = sp.get_children()
	_check(items.size() > 30, "WIN выложено из предметов: %d" % items.size())

	var dollars := 0
	for it in items:
		if it.is_in_group("dollar"):
			dollars += 1
	_check(dollars == items.size(),
		"и целиком из долларов: %d из %d" % [dollars, items.size()])

	# Три буквы, а не одна: слово обязано быть ШИРЕ буквы ровно втрое с
	# пробелами. Слипшееся WIN читается как клякса.
	var cell  : float = vp.y * float(sp.LETTER_H_FRAC) / float(sp.LETTER_ROWS)
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for it in items:
		x0 = minf(x0, (it as Node2D).position.x)
		x1 = maxf(x1, (it as Node2D).position.x)
		y0 = minf(y0, (it as Node2D).position.y)
		y1 = maxf(y1, (it as Node2D).position.y)
	var want_w : float = cell * (float(sp.LETTER_COLS) * 3.0 + float(sp.WORD_GAP_COLS) * 2.0 - 1.0)
	_check(absf((x1 - x0) - want_w) < cell,
		"ширина в три буквы с пробелами: %.0f при ожидаемых %.0f" % [x1 - x0, want_w])
	_check(y1 - y0 > vp.y * 0.7,
		"и во всю высоту: %.0f из %.0f" % [y1 - y0, vp.y])
	_check(x0 > vp.x, "стартует целиком из-за края: %.0f при экране %.0f" % [x0, vp.x])
	_check(hold > 1.0, "и ждать его есть сколько: %.1f с" % hold)
	sp.call("clear_items")
	await process_frame

# Слово должно быть выложено ЦЕЛИКОМ: буква без глифа молча превратилась бы в
# пустой оазис — тридцать секунд тишины ни за что.
func _test_glyphs(sp: Node) -> void:
	var word : String = String(sp.LETTER_WORD)
	var miss : Array = []
	for i in word.length():
		if not (sp.LETTER_GLYPHS as Dictionary).has(word[i]):
			miss.append(word[i])
	_check(miss.is_empty(), "глиф есть у каждой буквы слова «%s»: %s" % [word, str(miss)])

	var bad : Array = []
	for k in (sp.LETTER_GLYPHS as Dictionary).keys():
		var g : Array = sp.LETTER_GLYPHS[k]
		if g.size() != int(sp.LETTER_ROWS):
			bad.append(k)
			continue
		for line in g:
			if String(line).length() != int(sp.LETTER_COLS):
				bad.append(k)
				break
	_check(bad.is_empty(), "все глифы ровно %d×%d: %s"
		% [int(sp.LETTER_COLS), int(sp.LETTER_ROWS), str(bad)])

func _test_one_letter(sp: Node) -> void:
	sp.set("campaign_mode", true)
	sp.set("_frozen", false)
	sp.call("clear_items")
	await process_frame

	var vp : Vector2 = get_root().get_visible_rect().size
	sp.call("_run_letter")
	await process_frame

	var items : Array = sp.get_children()
	_check(items.size() > 8, "буква выложена из предметов: %d" % items.size())

	# Одна буква — ОДНА валюта. Смешанная читается как случайная россыпь, а не
	# как выложенный знак.
	var pizzas := 0
	var dollars := 0
	for it in items:
		if it.is_in_group("dollar"):
			dollars += 1
		elif it.is_in_group("pizza"):
			pizzas += 1
	_check(pizzas == 0 or dollars == 0,
		"и целиком из одного: пицц %d, долларов %d" % [pizzas, dollars])
	_check(pizzas + dollars == items.size(),
		"и в ней нет ничего постороннего: %d из %d" % [pizzas + dollars, items.size()])

	# Во весь экран по высоте: буква в четверть экрана — это уже не знак, а куча.
	var y0 := INF
	var y1 := -INF
	for it in items:
		y0 = minf(y0, (it as Node2D).position.y)
		y1 = maxf(y1, (it as Node2D).position.y)
	_check(y1 - y0 > vp.y * 0.7,
		"и во весь экран по высоте: %.0f из %.0f" % [y1 - y0, vp.y])

	# Стартует ИЗ-ЗА правого края целиком: половина буквы, появившаяся в кадре,
	# читается как обрывок.
	var x0 := INF
	for it in items:
		x0 = minf(x0, (it as Node2D).position.x)
	_check(x0 > vp.x, "и целиком из-за края: %.0f при экране %.0f" % [x0, vp.x])

	# Оазис: пока буква идёт, поток заморожен.
	_check(bool(sp.get("_frozen")), "пока буква идёт — поток заморожен")
	_check(bool(sp.get("_letter_active")), "и спавнер знает, что идёт буква")

	# И размораживается сам, без внешней команды.
	var t := 0.0
	while t < 8.0 and bool(sp.get("_letter_active")):
		await process_frame
		t += 1.0 / 60.0
	_check(not bool(sp.get("_frozen")), "буква прошла — поток пошёл дальше (%.1f с)" % t)

func _test_word(sp: Node) -> void:
	sp.call("clear_items")
	sp.set("campaign_mode", true)
	sp.set("_frozen", false)
	sp.set("_letter_idx", 0)
	await process_frame

	var got : Array = []
	sp.connect("boss_time", func() -> void: got.append(1))

	# Прогоняем всё слово подряд, без тридцатисекундных пауз: проверяется счёт,
	# а не таймер.
	var word_len : int = String(sp.LETTER_WORD).length()
	for i in word_len:
		sp.call("_run_letter")
		var t := 0.0
		while t < 10.0 and bool(sp.get("_letter_active")):
			await process_frame
			t += 1.0 / 60.0
		sp.call("clear_items")
		sp.set("_frozen", false)
		await process_frame
		if i < word_len - 1:
			_check(got.is_empty(), "буква %d из %d — босса ещё нет" % [i + 1, word_len]) \
				if i == word_len - 2 else null

	_check(int(sp.call("letters_done")) == word_len,
		"слово выложено целиком: %d из %d" % [int(sp.call("letters_done")), word_len])
	_check(got.size() == 1, "и ровно на последней букве пришёл босс: %d" % got.size())

func _finish() -> void:
	print("")
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок %d из %d — тест не отработал" % [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)
