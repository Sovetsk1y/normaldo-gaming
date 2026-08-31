extends SceneTree

# Headless-проверка фона канализации.
#   godot --headless --path . --script res://dev/smoke_background.gd
#
# Фон — не плитка, а НАРИСОВАННАЯ ПОЛОСА из четырнадцати кусков, и ломается она
# ровно двумя способами, оба тихие:
#
#   1. Кусок подменили другого размера. Полоса разъезжается, между кусками
#      появляется щель или нахлёст — а на глаз это видно только в тот момент,
#      когда шов проезжает по экрану.
#   2. Куски пошли не в том порядке или у соседей разошёлся рисунок. Это ровно
#      то, что произойдёт при перерисовке кусков по одному (см.
#      dev/art/level1/README.md): кладка и линия пола обязаны сходиться, иначе
#      посреди забега под ногами ступенька.
#
# См. /Концепция/Уровни/1-Канализация.md

const BG := preload("res://scripts/background.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 8

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Куски полосы ──")
	_test_slices()
	print("── Швы ──")
	_test_seams()
	print("── Прокрутка и затемнение ──")
	await _test_scene()
	_finish()

# Размер куска — не украшение: высота обязана быть высотой экрана (иначе поля
# или обрезка), а ширина одинаковой у всех (иначе шаг прокрутки врёт).
func _test_slices() -> void:
	_check(BG.SLICES.size() == int(BG.SLICE_COUNT),
		"кусков ровно %d (%d)" % [BG.SLICE_COUNT, BG.SLICES.size()])
	var bad : Array = []
	for i in BG.SLICES.size():
		var t : Texture2D = BG.SLICES[i]
		if t == null or t.get_width() != int(BG.SLICE_W) or t.get_height() != int(BG.SLICE_H):
			bad.append("%02d: %s" % [i + 1, str(t.get_size()) if t != null else "нет"])
	_check(bad.is_empty(), "и все %d×%d: %s" % [BG.SLICE_W, BG.SLICE_H, bad])

	var vp : Vector2 = get_root().get_visible_rect().size
	_check(is_equal_approx(BG.SLICE_H, vp.y),
		"высота куска равна высоте экрана: %.0f и %.0f" % [BG.SLICE_H, vp.y])

# Правый край куска N обязан сходиться с левым краем куска N+1, и кусок 14 — с
# куском 01: полоса зациклена. Порог 40 из 255 — это «шов не бросается в глаза»,
# а не «пиксель в пиксель»: рисунок пожат по горизонтали, и точного совпадения
# там быть не может.
const SEAM_LIMIT : float = 40.0

func _test_seams() -> void:
	var worst : float = 0.0
	var worst_at : String = ""
	var broken : Array = []
	for i in BG.SLICES.size():
		var a : Image = (BG.SLICES[i] as Texture2D).get_image()
		var b : Image = (BG.SLICES[(i + 1) % BG.SLICES.size()] as Texture2D).get_image()
		var d : float = _edge_diff(a, b)
		if d > worst:
			worst = d
			worst_at = "%02d→%02d" % [i + 1, (i + 1) % BG.SLICES.size() + 1]
		if d > SEAM_LIMIT:
			broken.append("%02d→%02d %.0f" % [i + 1, (i + 1) % BG.SLICES.size() + 1, d])
	_check(broken.is_empty(), "все швы сходятся, худший %s (%.0f из 255): %s"
		% [worst_at, worst, broken])

func _edge_diff(a: Image, b: Image) -> float:
	var h : int = mini(a.get_height(), b.get_height())
	var ax : int = a.get_width() - 1
	var sum : float = 0.0
	for y in h:
		var p := a.get_pixel(ax, y)
		var q := b.get_pixel(0, y)
		sum += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
	return sum / float(h * 3) * 255.0

func _test_scene() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var bg : Node2D = game.get_node_or_null("Background")
	var vp : Vector2 = get_root().get_visible_rect().size

	# Плёнка затемнения — ПОСЛЕДНИЙ ребёнок: так она накрывает фон и только его.
	# Уехав выше по списку, она перестала бы накрывать часть кусков; уехав в
	# сцену — накрыла бы Нормальдо и предметы, ради которых её и ставили.
	var kids : Array = bg.get_children()
	var last : Node = kids[kids.size() - 1]
	_check(last is ColorRect, "плёнка затемнения — последний узел фона (%s)" % last.get_class())
	if last is ColorRect:
		var c : Color = (last as ColorRect).color
		_check(c.a > 0.05 and c.a < 0.5, "и затемняет умеренно: %.2f" % c.a)
		_check((last as ColorRect).size.x >= vp.x and (last as ColorRect).size.y >= vp.y,
			"и накрывает экран целиком: %s при экране %s"
				% [str((last as ColorRect).size), str(vp)])

	# Декора больше нет. Проверяется не «крыс нет в кадре», а что у фона вообще
	# нет посторонних узлов: процедурный декор плодил спрайты пачками, и
	# вернувшись, он вернётся именно так.
	bg.call("start_scrolling")
	for _i in 240:
		get_root().get_tree().paused = false
		await process_frame
	var extra : Array = []
	for c in bg.get_children():
		if c is ColorRect:
			continue
		if c is Sprite2D and String(c.name).begins_with("Bg"):
			continue
		extra.append("%s (%s)" % [c.name, c.get_class()])
	_check(extra.is_empty(), "у фона нет декора: %s" % [extra])

	# Куски идут ПО ПОРЯДКУ. Иначе полоса рассыпается на четырнадцать случайных
	# картинок, и все замеры швов выше становятся бессмысленными.
	var order_ok := true
	var seen : Array = []
	for i in 40:
		seen.append(int(bg.get("_next_idx")))
		bg.call("_take_next_slice")
	for i in range(1, seen.size()):
		if int(seen[i]) != (int(seen[i - 1]) + 1) % int(BG.SLICE_COUNT):
			order_ok = false
	_check(order_ok, "куски выдаются по кругу и по порядку: %s…" % [seen.slice(0, 6)])
	game.queue_free()
	await process_frame

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
