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
# Проверяются ВСЕ ПЯТЬ уровней: полос теперь пять, режет их один и тот же
# скрипт, и ошибка нарезки одинаково тихая на любой из них.
#
# См. /Концепция/Уровни/1-Канализация.md, /Концепция/Уровни/Кампания — пять уровней.md

const BG := preload("res://scripts/background.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 10

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
# Куски одного уровня. Грузятся по пути, а не берутся из массива: в скрипте их
# больше нет — сто двадцать предзагруженных текстур не помещаются в память
# (см. background.gd).
func _slices(level: int) -> Array:
	var out : Array = []
	for i in int(BG.LEVEL_SLICES[level]):
		out.append(load("res://assets/backgrounds/level%d/level%d_%02d.png"
			% [level, level, i + 1]))
	return out

func _test_slices() -> void:
	var bad : Array = []
	var total : int = 0
	for level in range(1, BG.LEVEL_COUNT + 1):
		var arr : Array = _slices(level)
		total += arr.size()
		if arr.size() != int(BG.LEVEL_SLICES[level]):
			bad.append("уровень %d: кусков %d" % [level, arr.size()])
		for i in arr.size():
			var t : Texture2D = arr[i]
			if t == null or t.get_width() != int(BG.SLICE_W) or t.get_height() != int(BG.SLICE_H):
				bad.append("%d/%02d: %s" % [level, i + 1, str(t.get_size()) if t != null else "нет"])
	_check(bad.is_empty(), "все %d кусков пяти уровней %d×%d: %s"
		% [total, BG.SLICE_W, BG.SLICE_H, bad])
	_check(BG.LEVEL_SLICES.size() == BG.LEVEL_COUNT,
		"полос ровно пять: %d" % BG.LEVEL_SLICES.size())

	var vp : Vector2 = get_root().get_visible_rect().size
	_check(is_equal_approx(BG.SLICE_H, vp.y),
		"высота куска равна высоте экрана: %.0f и %.0f" % [BG.SLICE_H, vp.y])

# Правый край куска N обязан сходиться с левым краем куска N+1. Порог 48 из 255 —
# это «шов не бросается в глаза», а не «пиксель в пиксель»: рисунок пожат по
# горизонтали, и точного совпадения там быть не может. Худший замеренный
# соседский шов по всем пяти полосам — 41 (уровень 4, куски 23→24), и это шов
# самого рисунка, а не нарезки.
#
# Стык ПОСЛЕДНЕГО куска с ПЕРВЫМ проверяется отдельным, более мягким порогом:
# полоса не зациклена, её хвост при нарезке отбрасывается, и сходиться там
# нечему. Один такой стык на круг — цена цикла, и она измерена (29–87 по
# уровням). Альтернатива — пинг-понг — обходится дороже: см. background.gd.
const SEAM_LIMIT : float = 48.0
const WRAP_LIMIT : float = 95.0

func _test_seams() -> void:
	var worst : float = 0.0
	var worst_at : String = ""
	var broken : Array = []
	for level in range(1, BG.LEVEL_COUNT + 1):
		var arr : Array = _slices(level)
		for i in arr.size() - 1:
			var a : Image = (arr[i] as Texture2D).get_image()
			var b : Image = (arr[i + 1] as Texture2D).get_image()
			var d : float = _edge_diff(a, b)
			if d > worst:
				worst = d
				worst_at = "ур.%d %02d→%02d" % [level, i + 1, i + 2]
			if d > SEAM_LIMIT:
				broken.append("ур.%d %02d→%02d %.0f" % [level, i + 1, i + 2, d])
	_check(broken.is_empty(), "все швы сходятся, худший %s (%.0f из 255): %s"
		% [worst_at, worst, broken])

	# Замыкание круга. Порог свой и мягкий — это единственный стык, которого
	# художник не рисовал. Смысл проверки в том, чтобы он не уехал ЕЩЁ дальше
	# при перенарезке полос.
	var wrap_worst : float = 0.0
	var wrap_bad : Array = []
	for level in range(1, BG.LEVEL_COUNT + 1):
		var arr : Array = _slices(level)
		var d : float = _edge_diff((arr[arr.size() - 1] as Texture2D).get_image(),
			(arr[0] as Texture2D).get_image())
		wrap_worst = maxf(wrap_worst, d)
		if d > WRAP_LIMIT:
			wrap_bad.append("ур.%d %.0f" % [level, d])
	_check(wrap_bad.is_empty(), "замыкание круга в пределах %.0f, худшее %.0f: %s"
		% [WRAP_LIMIT, wrap_worst, wrap_bad])

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

	# Куски идут ПОДРЯД И ПО КРУГУ. Проверяется РЕАЛЬНАЯ выданная
	# последовательность, а не «соседние индексы соседи»: ровно на этом
	# проскочил пинг-понг. Он выдавал 1,2,…,N,N−1,…, и «соседние индексы
	# соседи» на такой цепочке ПРАВДА — а на экране при этом сходились правый
	# край куска i и левый край куска i−1, то есть НЕ те края, что рисовал
	# художник. Каждый стык обратного хода был порван, и это выглядело как
	# «уровень нарезан случайно».
	#
	# Поэтому теперь берётся сама цепочка и по ней МЕРЯЮТСЯ ШВЫ — тем же
	# _edge_diff, что и выше. Так проверка ловит любой порядок, который на
	# бумаге выглядит связным, а на экране рвёт картинку.
	bg.call("set_level", 5)          # самая короткая полоса: круг успеет замкнуться
	var n5 : int = int(BG.LEVEL_SLICES[5])
	var arr5 : Array = _slices(5)
	var chain : Array = []
	for i in n5 * 2 + 3:
		chain.append(int(bg.get("_next_idx")))
		bg.call("_take_next_slice")

	var cycled := true
	for i in range(1, chain.size()):
		if int(chain[i]) != (int(chain[i - 1]) + 1) % n5:
			cycled = false
	_check(cycled, "куски идут по кругу: %s…" % [chain.slice(0, 12)])

	var chain_worst : float = 0.0
	var chain_bad : Array = []
	for i in range(1, chain.size()):
		var a : Image = (arr5[int(chain[i - 1])] as Texture2D).get_image()
		var b : Image = (arr5[int(chain[i])] as Texture2D).get_image()
		var d : float = _edge_diff(a, b)
		chain_worst = maxf(chain_worst, d)
		if d > WRAP_LIMIT:
			chain_bad.append("%02d→%02d %.0f" % [int(chain[i - 1]) + 1, int(chain[i]) + 1, d])
	_check(chain_bad.is_empty(),
		"в выданной цепочке нет порванных швов, худший %.0f: %s" % [chain_worst, chain_bad])

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
