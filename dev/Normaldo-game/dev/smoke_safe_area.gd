extends SceneTree

# Headless smoke-тест безопасной области — островка, чёлки и полоски «домой».
#   godot --headless --path . --script res://dev/smoke_safe_area.gd
#
# Проверяется НЕ то, что где-то присвоен масштаб, а само обещание: весь холст
# 960 × 430 после отступа лежит внутри безопасного прямоугольника, все слои
# интерфейса получили ОДИН И ТОТ ЖЕ отступ, поворот телефона пересчитывает уже
# выданные слои, а мир остаётся во весь экран.

const CANVAS : Vector2 = Vector2(960.0, 430.0)

# Слои, которые обязаны остаться ВО ВЕСЬ ЭКРАН. Вспышка с полями по краям — не
# вспышка, а шторка сирены, не доходящая до края, — не шторка.
#
# Список именно разрешительный: новый CanvasLayer без отступа обязан попасть
# сюда руками, то есть решение «этот во весь экран» будет принято, а не забыто.
const FULLBLEED_FUNCS : Array = [
	"_screen_flash",   # club_boss, leatherhead, ninja_foot
	"_cast_expecto",   # normaldo — белая вспышка спелла
	"_siren",          # club_boss — шторки по краям экрана
	"_strobe",         # club_boss — стробоскоп танцпола
	"_draw_safe_sim",  # дев-подсветка САМОГО островка
]

# Сколько проверок обязано отработать. Упавшая корутина обрывается молча: её
# `_check`-и просто не случаются, счётчик провалов остаётся нулём, и набор
# рапортует «всё зелёное», не проверив ничего. Так уже было один раз.
const EXPECTED_CHECKS : int = 12

var _fails  : int = 0
var _checks : int = 0

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Без выреза интерфейс не трогается ──")
	await _test_no_cutout()
	print("── Островок слева и справа ──")
	await _test_both_sides()
	print("── Все слои интерфейса с одним отступом ──")
	await _test_layers_agree()
	print("── Поворот пересчитывает выданные слои ──")
	await _test_rotation()
	print("── Мир остаётся во весь экран ──")
	await _test_world_full_bleed()
	print("── Каждый новый слой решает про отступ ──")
	_test_every_layer_decides()

	print("")
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("ПРОВЕРОК ВСЕГО %d, А ЖДАЛИ %d — какая-то оборвалась"
			% [_checks, EXPECTED_CHECKS])
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

func _sa() -> Node:
	return get_root().get_node_or_null("SafeArea")

# Прямоугольник, в который слой превращает весь холст.
func _mapped(cl: CanvasLayer) -> Rect2:
	return Rect2(cl.offset, CANVAS * cl.scale)

func _test_no_cutout() -> void:
	var sa := _sa()
	sa.call("simulate", Vector4.ZERO)
	await process_frame
	var r : Rect2 = sa.call("rect")
	_check(r.position.is_equal_approx(Vector2.ZERO)
		and r.size.is_equal_approx(CANVAS),
		"на машине без выреза безопасен весь холст: %s" % [r])
	var cl := CanvasLayer.new()
	get_root().add_child(cl)
	sa.call("apply", cl)
	await process_frame
	_check(cl.scale.is_equal_approx(Vector2.ONE)
		and cl.offset.is_equal_approx(Vector2.ZERO),
		"и слой остаётся нетронутым: масштаб %s, сдвиг %s" % [cl.scale, cl.offset])
	cl.queue_free()
	await process_frame

# ГЛАВНОЕ ОБЕЩАНИЕ: что бы разметка ни нарисовала в пределах холста, оно
# окажется внутри безопасной области. Проверяется на обеих сторонах, потому что
# поворот разрешён в обе, и одна сторона — это половина проверки.
func _test_both_sides() -> void:
	var sa := _sa()
	for side in [["слева", Vector4(66.0, 0.0, 0.0, 18.0)],
			["справа", Vector4(0.0, 0.0, 66.0, 18.0)]]:
		sa.call("simulate", (side as Array)[1])
		await process_frame
		var cl := CanvasLayer.new()
		get_root().add_child(cl)
		sa.call("apply", cl)
		await process_frame
		var safe : Rect2 = sa.call("rect")
		var got  : Rect2 = _mapped(cl)
		# Внутри — с запасом в полпикселя на округление.
		var inside : bool = got.position.x >= safe.position.x - 0.5 \
			and got.position.y >= safe.position.y - 0.5 \
			and got.end.x <= safe.end.x + 0.5 \
			and got.end.y <= safe.end.y + 0.5
		_check(inside, "островок %s: холст лёг внутрь — %s в %s"
			% [(side as Array)[0], got, safe])
		# И НЕ УЖАЛСЯ СИЛЬНЕЕ НУЖНОГО: масштаб равномерный и равен меньшей доле.
		var want : float = minf(safe.size.x / CANVAS.x, safe.size.y / CANVAS.y)
		_check(is_equal_approx(cl.scale.x, cl.scale.y)
			and absf(cl.scale.x - want) < 0.001,
			"и ужался ровно настолько, насколько надо: %.4f при %.4f"
			% [cl.scale.x, want])
		cl.queue_free()
		await process_frame

# Добыча из мини-игры летит в счётчики, которые живут в ДРУГОМ слое. Пока
# отступ у всех один, координаты слоёв сравнимы между собой — как и было до
# островка. Разъедутся отступы — добыча улетит мимо, и молча.
func _test_layers_agree() -> void:
	var sa := _sa()
	sa.call("simulate", Vector4(66.0, 0.0, 0.0, 18.0))
	await process_frame
	var a := CanvasLayer.new()
	var b := CanvasLayer.new()
	get_root().add_child(a)
	get_root().add_child(b)
	sa.call("apply", a)
	sa.call("apply", b)
	await process_frame
	_check(a.scale.is_equal_approx(b.scale) and a.offset.is_equal_approx(b.offset),
		"два слоя получили один отступ: %s / %s" % [a.offset, b.offset])
	a.queue_free()
	b.queue_free()
	await process_frame

# Телефон поворачивают в руках, и островок переезжает с одного бока на другой.
# Слой, выданный ДО поворота, обязан переехать вместе с ним.
func _test_rotation() -> void:
	var sa := _sa()
	sa.call("simulate", Vector4(66.0, 0.0, 0.0, 18.0))
	await process_frame
	var cl := CanvasLayer.new()
	get_root().add_child(cl)
	sa.call("apply", cl)
	await process_frame
	var before : Vector2 = cl.offset
	sa.call("simulate", Vector4(0.0, 0.0, 66.0, 18.0))
	await process_frame
	_check(not cl.offset.is_equal_approx(before),
		"после поворота слой переехал сам: %s → %s" % [before, cl.offset])
	var safe : Rect2 = sa.call("rect")
	_check(_mapped(cl).end.x <= safe.end.x + 0.5,
		"и снова лежит внутри: %s в %s" % [_mapped(cl), safe])
	cl.queue_free()
	await process_frame

# Полосы обязаны доходить до краёв экрана: поле по бокам читалось бы как рамка,
# а предметы влетали бы «из ниоткуда» в десятке пикселей от края.
func _test_world_full_bleed() -> void:
	var sa := _sa()
	sa.call("simulate", Vector4(66.0, 0.0, 0.0, 18.0))
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : CanvasLayer = game.get_node_or_null("HUD")
	var sp  : Node2D      = game.get_node_or_null("Spawner")
	var nd  : Node2D      = game.get_node_or_null("Normaldo")
	var bg  : Node2D      = game.get_node_or_null("Background")
	await process_frame
	_check(sp.scale.is_equal_approx(Vector2.ONE)
		and nd.scale.is_equal_approx(Vector2.ONE)
		and bg.scale.is_equal_approx(Vector2.ONE),
		"спавнер, Нормальдо и фон не ужаты: %s / %s / %s"
		% [sp.scale, nd.scale, bg.scale])
	# Полосы считает спавнер — крайние обязаны остаться на своих местах.
	var lanes : Array = sp.call("_lane_centers")
	_check(lanes.size() > 0 and float(lanes[0]) < CANVAS.y * 0.2
		and float(lanes[lanes.size() - 1]) > CANVAS.y * 0.8,
		"и полосы по-прежнему от края до края: %s" % [lanes])
	# А интерфейс — ужат, и это тот же слой, что и у всех.
	_check(hud.offset.x > 60.0,
		"а интерфейс отступил от островка: сдвиг %s" % [hud.offset])
	sa.call("simulate", Vector4.ZERO)
	game.queue_free()
	await process_frame

# ── НОВЫЙ СЛОЙ ОБЯЗАН РЕШИТЬ, ВО ВЕСЬ ЭКРАН ОН ИЛИ НЕТ ─────────────────────
# Слоёв в игре два десятка, и заводятся новые. Забытый `SafeArea.apply` — это
# баннер босса, наполовину уехавший под островок, и заметить это можно только
# на устройстве и только если повернуть телефон нужной стороной.
#
# Поэтому проверка идёт ПО ТЕКСТУ: каждый `CanvasLayer.new()` либо берёт
# отступ следующей же строкой, либо стоит в функции из списка полноэкранных.
func _test_every_layer_decides() -> void:
	var missed : Array = []
	var seen : int = 0
	for path in _scripts():
		var src := FileAccess.get_file_as_string(path)
		if src == "":
			continue
		var lines := src.split("\n")
		for i in lines.size():
			if String(lines[i]).find("CanvasLayer.new()") < 0:
				continue
			seen += 1
			var applied := false
			for j in range(i + 1, mini(i + 4, lines.size())):
				if String(lines[j]).find("SafeArea.apply(") >= 0:
					applied = true
					break
			if applied:
				continue
			if FULLBLEED_FUNCS.has(_func_at(lines, i)):
				continue
			missed.append("%s:%d (%s)" % [path.get_file(), i + 1, _func_at(lines, i)])
	_check(seen >= 15, "слоёв в игре найдено: %d" % seen)
	_check(missed.is_empty(), "и у каждого решён отступ: %s" % [missed])

# Имя функции, внутри которой стоит строка.
func _func_at(lines: PackedStringArray, idx: int) -> String:
	for i in range(idx, -1, -1):
		var l := String(lines[i])
		if l.begins_with("func ") or l.begins_with("static func "):
			var head := l.substr(l.find("func ") + 5)
			return head.substr(0, head.find("("))
	return "<вне функции>"

func _scripts() -> Array:
	var out : Array = []
	var d := DirAccess.open("res://scripts")
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append("res://scripts/" + f)
	return out
