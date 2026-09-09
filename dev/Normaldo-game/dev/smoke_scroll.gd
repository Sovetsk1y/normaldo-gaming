extends SceneTree

# Прокрутка списков пальцем.
#   godot --headless --path . --script res://dev/smoke_scroll.gd
#
# ── ЧТО ЗДЕСЬ ЛОВИТСЯ ────────────────────────────────────────────────────────
# Внутрь ScrollContainer кладут ОДИН Control, а в него — строки. У этого
# Control фильтр мыши по умолчанию `STOP`: он принимает касание и на себе его и
# заканчивает. Протяжка до контейнера не доходит — список не листается ВОВСЕ.
#
# Ошибка тихая вдвойне:
#   * экран выглядит собранным правильно, в консоль ничего не сыпется;
#   * на компьютере колесо мыши идёт мимо этой цепочки и всё «работает».
#
# Поэтому и дошло до игрока словами «на телефонах вообще нет скролла».
#
# ── ПОЧЕМУ ПРОВЕРКА НЕ ПРОТЯГИВАЕТ ПАЛЬЦЕМ ───────────────────────────────────
# В headless НЕТ разбора ввода интерфейса: `Input.parse_input_event` доходит до
# дерева, но до Control'ов события не доводятся — окна нет. Настоящая протяжка
# проверяется только под xvfb (см. историю правки), и держать такой тест в
# общем прогоне нельзя.
#
# Зато состояние, из которого беда растёт, видно и без окна: фильтр тела. Его
# и сторожим — на ВСЕХ экранах сразу, а не на том одном, где заметили.

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 5

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

# Экраны со списками. Каждый строится своим `setup`, поэтому здесь пара
# «скрипт → как поднять».
const SCREENS : Array = [
	["res://scripts/achievements_screen.gd", "достижения"],
	["res://scripts/awards_screen.gd",       "призы"],
	["res://scripts/leaderboard_screen.gd",  "лидеры"],
	["res://scripts/settings_screen.gd",     "настройки"],
]

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	if hud == null:
		_check(false, "HUD не поднялся — проверять нечего")
		_finish()
		return

	print("── Тело списка пропускает протяжку ──")
	for pair in SCREENS:
		await _test_screen(hud, String(pair[0]), String(pair[1]))

	print("── Контракт: тело списка собирается одним способом ──")
	_test_sources()
	_finish()

func _test_screen(hud: Node, path: String, title: String) -> void:
	var scr : Node = load(path).new()
	# Таблица лидеров просит режим вторым доводом, остальные — только HUD.
	if path.ends_with("leaderboard_screen.gd"):
		scr.call("setup", hud, 0)
	else:
		scr.call("setup", hud)
	hud.add_child(scr)
	for _i in 20:
		await process_frame

	var bad : Array = []
	var seen : int = 0
	for sc in _find_scrolls(scr):
		for ch in sc.get_children():
			if not (ch is Control):
				continue
			# Полосы прокрутки — родные дети контейнера, они и должны ловить
			# касание на себе. Речь только о теле списка.
			if ch is ScrollBar:
				continue
			seen += 1
			if (ch as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				bad.append("%s/%s" % [sc.name, ch.name])
	_check(seen > 0 and bad.is_empty(),
		"%s: тел списка %d, глухих %d %s" % [title, seen, bad.size(), bad])

	scr.queue_free()
	await process_frame

func _find_scrolls(root: Node) -> Array:
	var out : Array = []
	var stack : Array = [root]
	while not stack.is_empty():
		var n : Node = stack.pop_back()
		if n is ScrollContainer:
			out.append(n)
		for ch in n.get_children():
			stack.append(ch)
	return out

# Проверка по исходникам ловит СЛЕДУЮЩИЙ экран — тот, которого ещё нет.
# Состояние выше говорит «сейчас всё хорошо», а это — «и завтра тоже»: новый
# список, собранный мимо `UiKit.scroll_body`, виден сразу, без запуска экрана.
func _test_sources() -> void:
	var files : Array = []
	var dir := DirAccess.open("res://scripts")
	if dir == null:
		_check(false, "папка scripts не открылась")
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			files.append("res://scripts/" + f)

	var offenders : Array = []
	for f in files:
		var txt : String = FileAccess.get_file_as_string(f)
		var scrolls : int = txt.count("ScrollContainer.new()")
		if scrolls == 0:
			continue
		# Тело кладут ТОЛЬКО через помощника. Прямой add_child в контейнер —
		# ровно тот способ, каким глухое тело и появляется.
		#
		# Сравниваются ЧИСЛА, а не «хоть один вызов есть»: в hud.gd семь
		# прокручиваемых списков, и шесть правильных прекрасно прикрывали
		# седьмой — список способностей в карточке скина, который не листался.
		var bodies : int = txt.count("UiKit.scroll_body(")
		if bodies < scrolls:
			offenders.append("%s (%d из %d)" % [f.get_file(), bodies, scrolls])
	_check(offenders.is_empty(),
		"у каждого списка тело через UiKit.scroll_body, мимо: %s" % [offenders])

func _finish() -> void:
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок %d из %d — тест не отработал" % [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails == 0:
		print("ГОТОВО: проверок %d, провалов нет" % _checks)
		quit(0)
	else:
		print("ПРОВАЛ: %d из %d" % [_fails, _checks])
		quit(1)
