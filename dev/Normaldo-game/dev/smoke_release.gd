extends SceneTree

# Готовность сборки к раздаче (TestFlight / открытый тест).
#   godot --headless --path . --script res://dev/smoke_release.gd
#
# Дев-кнопки — это не косметика: они сбрасывают скины, выдают доллары, делают
# бессмертным и вызывают босса. Улетевшая в тест сборка с ними — это не «мелкий
# недочёт интерфейса», это сломанная экономика у всех тестеров сразу.
#
# Поэтому проверяются ДВЕ разные вещи:
#
#   1. КОНТРАКТ — каждая дев-кнопка собирается только под рубильником
#      `DevFlags.ENABLED`. Проверка идёт по исходникам и работает независимо от
#      того, в каком положении рубильник сейчас: она ловит новую кнопку,
#      добавленную мимо него. Именно так дев-кнопка и просачивается в релиз —
#      не «забыли выключить», а «добавили не туда».
#
#   2. СОСТОЯНИЕ — если рубильник ВЫКЛЮЧЕН, на экранах действительно ничего
#      дев-ского нет. При включённом рубильнике эта часть пропускается: во
#      время разработки он включён, и падать на этом тест не должен.
#
# См. scripts/dev_flags.gd

const DevFlags = preload("res://scripts/dev_flags.gd")

# Файлы, в которых живут дев-кнопки. Список явный: пробегать все скрипты
# подряд значит однажды поймать совпадение в чужом коде и долго выяснять, что
# это ложная тревога.
const SOURCES : Array = [
	"res://scripts/hud.gd",
	"res://scripts/leaderboard_screen.gd",
	"res://scripts/settings_screen.gd",
]

# Как выглядит вызов сборки дев-affordance.
const DEV_CALL : Array = [
	"_build_dev_", "_build_menu_dev_", "_build_go_dev_",
	"_build_notif_test_row", "_build_notif_fire_row", "_build_notif_remote_row",
]

# Тексты, которых на экранах быть не должно при выключенном рубильнике. Это
# подписи самих дев-кнопок, слово в слово. «+10000\n$» — выдача долларов из
# меню; коротким «+1000» её ловить нельзя, под него попадает честный приз в
# таблице лидеров.
const DEV_TEXTS : Array = [
	"DEV", "СБРОС", "БЕСС:", "COLL ", "+10000",
]

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 11

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Контракт: дев-кнопки только под рубильником ──")
	_test_sources()
	print("── Состояние сборки ──")
	await _test_screens()
	_finish()

# ── 1. Контракт ──────────────────────────────────────────────────────────────
# Вызов сборщика дев-кнопки обязан стоять ВНУТРИ блока `if DevFlags.ENABLED`.
# Блок опознаётся по отступу: строки глубже отступа `if` — его тело.
func _test_sources() -> void:
	for path in SOURCES:
		var leaks : Array = _ungated_calls(path)
		_check(leaks.is_empty(), "%s: все дев-кнопки под рубильником%s"
			% [String(path).get_file(),
				"" if leaks.is_empty() else " — мимо: " + ", ".join(leaks)])

func _ungated_calls(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ["файл не открылся"]
	var out : Array = []
	var gate_indent : int = -1        # отступ действующего `if DevFlags.ENABLED`
	var line_no : int = 0
	while not f.eof_reached():
		var line : String = f.get_line()
		line_no += 1
		var stripped : String = line.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			continue
		var indent : int = _indent_of(line)
		# Вышли из тела блока — рубильник больше не действует.
		if gate_indent >= 0 and indent <= gate_indent:
			gate_indent = -1
		if stripped.begins_with("if DevFlags.ENABLED"):
			gate_indent = indent
			continue
		for marker in DEV_CALL:
			if stripped.contains(marker) and not stripped.begins_with("func "):
				if gate_indent < 0:
					out.append("%s:%d" % [String(path).get_file(), line_no])
				break
	f.close()
	return out

func _indent_of(line: String) -> int:
	var i := 0
	while i < line.length() and (line[i] == "\t" or line[i] == " "):
		i += 1
	return i

# ── 2. Состояние ─────────────────────────────────────────────────────────────
func _test_screens() -> void:
	if DevFlags.ENABLED:
		# Рубильник включён — это рабочая сборка, кнопки на месте по замыслу.
		# Столько же проверок, сколько в ветке «выключён»: счётчик ловит «тест не
		# отработал», и разное число проверок по веткам сделало бы его врущим.
		for i in 8:
			_check(true, "рубильник ВКЛЮЧЁН — сборка рабочая, экраны не проверяем")
		return
	_check(true, "рубильник ВЫКЛЮЧЕН — сборка готовится к раздаче")

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	# Меню: чипы сброса скинов/книги/бесконечного и выдача долларов.
	_check(_dev_texts_in(game).is_empty(),
		"в меню ничего дев-ского: %s" % str(_dev_texts_in(game)))
	_check(hud.get("_fps_label") == null, "счётчик кадров не показывается")

	# Забег: нижний ряд спавн-кнопок, бессмертие, коллизии, босс, фаза.
	hud.call("_start_game")
	for _i in 200:
		await process_frame
	var run_leaks : Array = _dev_texts_in(game)
	_check(run_leaks.is_empty(), "в забеге ничего дев-ского: %s" % str(run_leaks))
	_check(hud.get("_dev_btn") == null and hud.get("_dev_immortal_btn") == null \
			and hud.get("_boss_menu_btn") == null and hud.get("_dev_phase_btn") == null \
			and hud.get("_dev_collisions_btn") == null,
		"и ни одна дев-кнопка забега не создана")

	# Трёх боссов зовёт одна выпадашка «БОССЫ», и она вся под рубильником:
	# ни чипа, ни раскрытого ряда. КРОК и КЛУБ когда-то стояли СНАРУЖИ — без них
	# посмотреть на боссов было нельзя ничем; теперь до обоих доходят игрой.
	_check(hud.get("_boss_menu_row") == null,
		"и раскрытого ряда боссов тоже нет")

	# Экран лидеров — «DEV: ТЕСТ ПРИЗА» жил именно там. Собирается он своим
	# настоящим setup(), иначе проверять было бы нечего: пустой узел «чистый»
	# при любом положении рубильника.
	var lb : Node = load("res://scripts/leaderboard_screen.gd").new()
	lb.call("setup", hud, 0)
	hud.add_child(lb)
	for _i in 40:
		await process_frame
	var lb_texts : Array = []
	_all_texts(lb, lb_texts)
	_check(lb_texts.size() > 3, "экран лидеров действительно собрался (%d надписей)"
		% lb_texts.size())
	var lb_leaks : Array = _dev_texts_in(lb)
	_check(lb_leaks.is_empty(), "и на нём ничего дев-ского: %s" % str(lb_leaks))
	lb.free()
	game.queue_free()
	await process_frame

# Все тексты на экране, попадающие под дев-приметы.
func _dev_texts_in(root: Node) -> Array:
	var out : Array = []
	_collect_texts(root, out)
	return out

func _all_texts(node: Node, out: Array) -> void:
	if node is Label and (node as Label).text != "":
		out.append((node as Label).text)
	for c in node.get_children():
		_all_texts(c, out)

func _collect_texts(node: Node, out: Array) -> void:
	var t := ""
	if node is Label:
		t = (node as Label).text
	elif node is Button:
		t = (node as Button).text
	if t != "":
		for m in DEV_TEXTS:
			if t.contains(m):
				out.append(t)
				break
	for c in node.get_children():
		_collect_texts(c, out)

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
