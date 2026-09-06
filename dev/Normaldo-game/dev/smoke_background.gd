extends SceneTree

# Headless-проверка фона канализации.
#   godot --headless --path . --script res://dev/smoke_background.gd
#
# Фон устроен ДВУМЯ РАЗНЫМИ СПОСОБАМИ, и проверять их надо порознь:
#
#   • уровень 1 — ПЛИТКА с процедурным декором. Ломается тем, что декор перестаёт
#     появляться (стена едет голой) или, наоборот, не убирается при уходе на
#     следующий уровень — и крыса из канализации бежит по улице.
#   • уровни 2 и 3 — НАРИСОВАННЫЕ ПОЛОСЫ. Ломаются двумя тихими способами:
#     кусок подменили другого размера (полоса разъезжается, между кусками щель
#     или нахлёст — видно только в момент, когда шов проезжает по экрану), либо
#     куски пошли не в том порядке и у соседей разошёлся рисунок. Второе — ровно
#     то, что произойдёт при перерисовке кусков по одному: кладка и линия пола
#     обязаны сходиться, иначе посреди забега под ногами ступенька.
#
# Полос четыре, а уровней на них два: полосы 2 и 3 склеены в уровень 2, полосы
# 4 и 5 — в уровень 3. Нарезку проверяем по ПОЛОСАМ (режет их один и тот же
# скрипт, и ошибка нарезки одинаково тихая на любой), а склейку — по УРОВНЯМ,
# потому что стык полосы с полосой внутри уровня игрок видит, а отдельно взятую
# полосу — нет.
#
# См. /Концепция/Уровни/1-Канализация.md, /Концепция/Уровни/Кампания — три уровня.md

const BG := preload("res://scripts/background.gd")

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
	print("── Куски полосы ──")
	_test_slices()
	print("── Швы ──")
	_test_seams()
	print("── Прокрутка и затемнение ──")
	await _test_scene()
	_finish()

# Размер куска — не украшение: высота обязана быть высотой экрана (иначе поля
# или обрезка), а ширина одинаковой у всех (иначе шаг прокрутки врёт).
# Куски одной ПОЛОСЫ. Грузятся по пути, а не берутся из массива: в скрипте их
# больше нет — сто двадцать две предзагруженные текстуры не помещаются в память
# (см. background.gd).
func _slices(strip: int) -> Array:
	var out : Array = []
	for i in int(BG.STRIP_SLICES[strip]):
		out.append(load("res://assets/backgrounds/level%d/level%d_%02d.png"
			% [strip, strip, i + 1]))
	return out

# Куски УРОВНЯ — куски всех его полос подряд. Ровно эта лента и едет по экрану,
# поэтому склейку и порядок меряем по ней.
func _level_chain(level: int) -> Array:
	var out : Array = []
	for strip in (BG.LEVEL_STRIPS[level] as Array):
		out.append_array(_slices(int(strip)))
	return out

func _test_slices() -> void:
	var bad : Array = []
	var total : int = 0
	for strip in BG.STRIP_SLICES.keys():
		var arr : Array = _slices(int(strip))
		total += arr.size()
		if arr.size() != int(BG.STRIP_SLICES[strip]):
			bad.append("полоса %d: кусков %d" % [int(strip), arr.size()])
		for i in arr.size():
			var t : Texture2D = arr[i]
			if t == null or t.get_width() != int(BG.SLICE_W) or t.get_height() != int(BG.SLICE_H):
				bad.append("%d/%02d: %s" % [int(strip), i + 1, str(t.get_size()) if t != null else "нет"])
	_check(bad.is_empty(), "все %d кусков четырёх полос %d×%d: %s"
		% [total, BG.SLICE_W, BG.SLICE_H, bad])

	# Уровней три, но полосами покрыты ДВА: первый — на плитке. Проверка ловит
	# ровно тот промах, из-за которого её и завели: уровень, выпавший из
	# раскладки, показал бы стену чужого уровня и никак бы себя не выдал.
	_check(BG.LEVEL_STRIPS.size() == BG.LEVEL_COUNT - 1,
		"полосами покрыты все уровни кроме плиточного: %d при %d уровнях"
			% [BG.LEVEL_STRIPS.size(), BG.LEVEL_COUNT])
	_check(not BG.LEVEL_STRIPS.has(BG.TILE_LEVEL),
		"плиточный уровень %d не заявлен ещё и полосой" % BG.TILE_LEVEL)

	# Каждая полоса разложена РОВНО ПО ОДНОМУ РАЗУ. Полоса, забытая в раскладке,
	# — это кусок игры, который никто никогда не увидит; полоса, попавшая в два
	# уровня, — это два уровня с одинаковой стеной. Оба промаха на глаз не
	# ловятся вообще.
	var used : Array = []
	for level in BG.LEVEL_STRIPS.keys():
		for strip in (BG.LEVEL_STRIPS[level] as Array):
			used.append(int(strip))
	used.sort()
	var want : Array = []
	for strip in BG.STRIP_SLICES.keys():
		want.append(int(strip))
	want.sort()
	_check(used == want, "каждая полоса разложена ровно раз: %s при полосах %s"
		% [used, want])

	var vp : Vector2 = get_root().get_visible_rect().size
	_check(is_equal_approx(BG.SLICE_H, vp.y),
		"высота куска равна высоте экрана: %.0f и %.0f" % [BG.SLICE_H, vp.y])

# Правый край куска N обязан сходиться с левым краем куска N+1. Порог 48 из 255 —
# это «шов не бросается в глаза», а не «пиксель в пиксель»: рисунок пожат по
# горизонтали, и точного совпадения там быть не может. Худший замеренный
# соседский шов по всем полосам — 41 (полоса 4, куски 23→24), и это шов
# самого рисунка, а не нарезки.
#
# НЕНАРИСОВАННЫЕ стыки проверяются отдельным, более мягким порогом. Их в уровне
# ровно столько, сколько у него полос: переход с полосы на полосу (полосы не
# рисовались продолжением друг друга) и замыкание ленты уровня на её начало
# (полоса не зациклена, её хвост при нарезке отбрасывается). Измерено 29–87.
# Альтернатива циклу — пинг-понг — обходится дороже: см. background.gd.
const SEAM_LIMIT : float = 48.0
const WRAP_LIMIT : float = 95.0

func _test_seams() -> void:
	var worst : float = 0.0
	var worst_at : String = ""
	var broken : Array = []
	for strip in BG.STRIP_SLICES.keys():
		var arr : Array = _slices(int(strip))
		for i in arr.size() - 1:
			var a : Image = (arr[i] as Texture2D).get_image()
			var b : Image = (arr[i + 1] as Texture2D).get_image()
			var d : float = _edge_diff(a, b)
			if d > worst:
				worst = d
				worst_at = "пол.%d %02d→%02d" % [int(strip), i + 1, i + 2]
			if d > SEAM_LIMIT:
				broken.append("пол.%d %02d→%02d %.0f" % [int(strip), i + 1, i + 2, d])
	_check(broken.is_empty(), "все нарисованные швы сходятся, худший %s (%.0f из 255): %s"
		% [worst_at, worst, broken])

	# Стыки, которых художник не рисовал: конец полосы → начало следующей и
	# замыкание ленты уровня. Смысл проверки в том, чтобы они не уехали ЕЩЁ
	# дальше при перенарезке полос или при пересборке раскладки.
	var wrap_worst : float = 0.0
	var wrap_bad : Array = []
	for level in BG.LEVEL_STRIPS.keys():
		var strips : Array = BG.LEVEL_STRIPS[level]
		for i in strips.size():
			var st : int = int(strips[i])
			var nx : int = int(strips[(i + 1) % strips.size()])
			var tail : Array = _slices(st)
			var head : Array = _slices(nx)
			var d : float = _edge_diff((tail[tail.size() - 1] as Texture2D).get_image(),
				(head[0] as Texture2D).get_image())
			wrap_worst = maxf(wrap_worst, d)
			if d > WRAP_LIMIT:
				wrap_bad.append("ур.%d %d→%d %.0f" % [level, st, nx, d])
	_check(wrap_bad.is_empty(), "ненарисованные стыки в пределах %.0f, худший %.0f: %s"
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

# Живые дети узла декора — те, что ещё не поставлены в очередь на удаление.
# `queue_free` срабатывает в конце кадра, и без этого фильтра «декор снят» ловил
# бы не факт, а момент.
func _decor_live(decor: Node) -> Array:
	var out : Array = []
	for c in decor.get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out

# Куски города — единственный декор БЕЗ скрипта: обычный Sprite2D с текстурой
# панорамы. По этому и различаются.
func _city_count(decor: Node) -> int:
	var n := 0
	for c in _decor_live(decor):
		if c.get_script() == null:
			n += 1
	return n

func _decor_kinds(decor: Node) -> Dictionary:
	var kinds : Dictionary = {}
	for c in _decor_live(decor):
		var scr : Script = c.get_script()
		if scr == null:
			continue
		var k : String = String(scr.resource_path).get_file()
		kinds[k] = int(kinds.get(k, 0)) + 1
	return kinds

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

	# ── Первый уровень: плитка живая ─────────────────────────────────────────
	# Игра открывается на первом уровне, поэтому проверять его можно прямо
	# отсюда, ничего не переключая.
	_check(bool(bg.call("tile_mode")), "игра открывается на плиточном уровне")
	var decor : Node = bg.get_node_or_null("Decor")
	_check(decor != null, "узел декора на месте")

	# Пятнадцать секунд, а не четыре, и это не запас «на всякий случай».
	# Декор выпадает по вероятностям, поэтому проверять «сколько именно» нельзя —
	# но одно событие тут ДЕТЕРМИНИРОВАНО: первая лампа заводится по таймеру
	# 3.5–7.5 с и спавну ничто не мешает, соседей у неё ещё нет. Пятнадцать
	# секунд накрывают этот срок с запасом вдвое и заодно успевают перебросить
	# плитку (771 px при 68 px/с — 11.3 с), то есть проверяют и выдачу декора на
	# переработке. На четырёх секундах проверка проходила бы «почти всегда» —
	# худший вид теста: он не ловит поломку, зато иногда падает сам.
	bg.call("start_scrolling")
	for _i in 900:
		get_root().get_tree().paused = false
		await process_frame
	_check(_city_count(decor) == 2, "город за проёмами на месте: %d куска" % _city_count(decor))
	var kinds : Dictionary = _decor_kinds(decor)
	_check(not kinds.is_empty(),
		"за пятнадцать секунд плитка обросла декором: %s" % [kinds])

	# Плёнка на плитке ВЫКЛЮЧЕНА: она заведена под яркие нарисованные полосы, а
	# тёмную плитку только съела бы — вместе со светом ламп и окнами города.
	_check(not (last as ColorRect).visible, "на плитке плёнка затемнения выключена")

	# ── Переход на полосу: декор снят ────────────────────────────────────────
	# Крыса из канализации, доезжающая по улице второго уровня, — самый заметный
	# способ сломать переход, и он же самый вероятный: декор живёт своей жизнью и
	# сам про смену уровня не знает.
	bg.call("set_level", 2)
	await process_frame
	_check(_decor_live(decor).is_empty(),
		"на полосе декор снят подчистую: осталось %s" % [_decor_live(decor)])
	_check((last as ColorRect).visible, "и плёнка затемнения включена обратно")

	# И обратно на плитку — бесконечный режим заходит на новый круг и снова
	# приводит игрока на первый уровень. Меряется город: он ставится ровно двумя
	# кусками и всегда, тогда как лампы и крысы — по вероятностям.
	bg.call("set_level", 1)
	await process_frame
	_check(_city_count(decor) == 2,
		"возврат на плитку снова её оживляет: город %d куска" % _city_count(decor))

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
	# Берётся уровень 3 — самая короткая лента из полосатых: 40 + 10 = 50 кусков
	# против 72 у второго. Круг по ней успевает замкнуться дважды, а лишние
	# полсотни сравнений картинок дали бы ровно тот же ответ.
	const CHAIN_LEVEL : int = 3
	bg.call("set_level", CHAIN_LEVEL)
	var arr1 : Array = _level_chain(CHAIN_LEVEL)
	var n1 : int = arr1.size()
	var chain : Array = []
	for _i in n1 * 2 + 3:
		chain.append(int(bg.get("_next_idx")))
		bg.call("_take_next_slice")

	var cycled := true
	for i in range(1, chain.size()):
		if int(chain[i]) != (int(chain[i - 1]) + 1) % n1:
			cycled = false
	_check(cycled, "куски идут по кругу: %s…" % [chain.slice(0, 12)])

	var chain_worst : float = 0.0
	var chain_bad : Array = []
	for i in range(1, chain.size()):
		var a : Image = (arr1[int(chain[i - 1])] as Texture2D).get_image()
		var b : Image = (arr1[int(chain[i])] as Texture2D).get_image()
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
