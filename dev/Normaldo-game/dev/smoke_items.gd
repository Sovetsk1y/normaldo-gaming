extends SceneTree

# Headless smoke-тест новых предметов и системы размеров.
#   godot --headless --path . --script res://dev/smoke_items.gd
#
# Не заменяет игровой прогон: проверяет, что каждый новый предмет собирается,
# тикает и не падает, что размеры укладываются в лейн, а резервы места
# действительно запрещают наложение.

const EFFECT_ITEM := preload("res://scripts/effect_item.gd")
const MAGIC_BOX   := preload("res://scripts/magic_box.gd")
const NINJA       := preload("res://scripts/ninja_item.gd")
const SPAWNER     := preload("res://scripts/spawner.gd")

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── ItemSizing ──")
	_test_sizing()
	print("── LootMultiplier ──")
	_test_multiplier()
	print("── Предметы ──")
	await _test_items()
	print("── Резервы места ──")
	_test_spans()
	print("── Песочные часы ──")
	await _test_slow_mo()
	print("── Угрозы под резисты скинов ──")
	await _test_hazards()
	print("── Пул мэджик бокса ──")
	await _test_box_pool()
	print("── Три вида ниндзя ──")
	await _test_ninja_kinds()
	print("── Конус просит тапать ──")
	await _test_cone_tap()
	print("── Дев-выпадашка мини-боссов ──")
	await _test_dev_mini_bosses()
	print("── Дев-кнопки не стоят одна на другой ──")
	_test_dev_column_slots()
	print("── СВАТ в потоке ──")
	await _test_swat_in_stream()
	print("── Крокодил в потоке ростом в линию ──")
	await _test_croc_size()
	print("── Мешок выкладывает знак валюты ──")
	await _test_money_bag_glyph()
	print("── Тапы по мешку замедляют время ──")
	await _test_money_bag_slowmo()
	print("── Тачка копов ──")
	await _test_police_car()
	print("── Рыжий и седой бомж ──")
	await _test_bum_variety()
	print("── Сейф вскрывается ударом ──")
	await _test_safe_crack()
	print("── Замедляющие не бьют ──")
	await _test_slowers_dont_hit()
	print("── Люди покачиваются ──")
	await _test_human_sway()
	print("── Пиво мутит экран ──")
	await _test_beer_blur()

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# Ящик — это СТАВКА НА ПОЛЕ, а не кошелёк: он обязан уметь выплюнуть гадость.
# Жетон автомата из пула убран — валюта не создаёт на экране никакой ситуации,
# её просто подбирают; освободившаяся доля ушла замедляющим.
# Три вида отвечают на три РАЗНЫХ вопроса: чёрный — «куда он бросил», красный —
# «где он пройдёт», жёлтый — «куда мне теперь нельзя». Проверяется именно это:
# что каждый делает своё, а не что все трое собираются.
func _test_ninja_kinds() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	var n  : Node = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	# Меню игры ставит дерево на паузу, а ниндзя живёт на _process и тюинах:
	# под паузой он замирает на месте, и тест меряет не поведение, а паузу.
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(180.0, vp.y * 0.5)
	await process_frame

	# Спавнер обязан выдавать все три: вид, который не выпадает, всё равно что
	# не написан.
	var seen : Dictionary = {}
	for i in 400:
		sp.call("_spawn_ninja", vp.y * 0.5, vp.x, 250.0)
	for c in sp.get_children():
		if c.get("kind") != null and c.is_in_group("ninja"):
			seen[String(c.get("kind"))] = true
	_check(seen.size() == 3, "спавнер выдаёт все три вида: %s" % str(seen.keys()))
	sp.call("clear_items")
	await process_frame

	# Красный: доходит до места, замахивается и УХОДИТ ЗА ЛЕВЫЙ КРАЙ сквозь
	# точку, где стоял Нормальдо. Ключевое — что он не останавливается.
	var red : Node2D = _put_ninja(sp, "predator", vp)
	await _tick(2.4)
	var gone : bool = not is_instance_valid(red) or red.global_position.x < 40.0
	_check(gone, "красный прошёл насквозь и ушёл")
	sp.call("clear_items")
	await process_frame

	# Жёлтый: кидает шашки в ЛЕТЯЩИЕ ПРЕДМЕТЫ и завешивает их. Ставим ему мишени,
	# иначе кидать не во что и проверять нечего.
	# Мишени СТОЯТ на месте. Ниндзя не кидает шашку в предмет левее десятой доли
	# экрана — за три секунды акта летящие мишени успевали уехать за эту границу,
	# шашки уходили в пустые лейны, и тест мигал «накрыто 0 из 2» без всякой
	# поломки в игре. Проверяется здесь «облако садится на предмет», и скорость
	# самих предметов к этому вопросу отношения не имеет.
	var marks : Array = []
	for i in 4:
		var it : Node2D = sp.call("build_random_item", 120.0)
		if it == null:
			continue
		it.set("speed", 0.0)
		# Мишени СПРАВА от ниндзя: он завешивает то, что игроку ЕЩЁ предстоит
		# прочитать, а не то, что уже пролетело мимо. Ниндзя паркуется на
		# PARK_X_RATIO ширины экрана — ставим мишени за ним.
		it.position = Vector2(vp.x * (float(NINJA.PARK_X_RATIO) + 0.06 + 0.09 * float(i)),
			vp.y * (0.2 + 0.2 * float(i)))
		sp.add_child(it)
		marks.append(it)
	var yellow : Node2D = _put_ninja(sp, "smoke", vp)

	# Ждём НЕ фиксированное число кадров, а САМО СОБЫТИЕ — облако, севшее на
	# мишень. Ниндзя живёт на таймерах реального времени, а тест считает кадры:
	# под нагрузкой 2.6 «секунды» кадров растягивались в шесть секунд реальных,
	# облака успевали дожить своё и начать растворяться, — а растворяющееся
	# облако отлипает от предмета и уезжает с потоком (см. smoke_screen.gd).
	# Тест мигал «накрыто 0 из 2», не поймав при этом ничего сломанного.
	#
	# Поэтому смотрим каждый кадр и запоминаем ЛУЧШЕЕ увиденное: облако село на
	# предмет хотя бы раз — вопрос закрыт, дальше оно имеет полное право уехать.
	var seen_clouds : int = 0
	var covering    : int = 0
	var harmless  := true
	var over_head := true
	var t0 : int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		get_root().get_tree().paused = false
		await process_frame
		var smoke : Array = get_root().get_tree().get_nodes_in_group("smoke")
		seen_clouds = maxi(seen_clouds, smoke.size())

		# ДЫМ НЕ БЬЁТ. Он закрывает обзор, и всё: ни группы препятствий, ни
		# хитбокса, ни урона. Иначе жёлтый превращается в третий вид стены, а от
		# стен в игре и так уворачиваются одинаково.
		var on_marks : int = 0
		for c in smoke:
			if c.is_in_group("obstacle") or c is CollisionObject2D:
				harmless = false
			# Нормальдо в сцене на z_index 3 — дым обязан быть выше: он
			# пролетает ПОД ним, а не появляется поверх.
			if int(c.get("z_index")) <= 3:
				over_head = false
			# И садится он НА ПРЕДМЕТ, а не в пустой лейн: смысл в том, что под
			# ним не видно, что летит.
			for m in marks:
				if is_instance_valid(m) \
						and (c as Node2D).global_position.distance_to((m as Node2D).global_position) < 6.0:
					on_marks += 1
					break
		covering = maxi(covering, on_marks)
		if covering >= 1:
			break

	_check(seen_clouds >= 1, "жёлтый поставил дым: облаков %d" % seen_clouds)
	_check(harmless, "дым безвреден: ни группы препятствия, ни хитбокса")
	_check(over_head, "и рисуется поверх Нормальдо — тот проходит под ним")
	_check(covering >= 1, "и завешивает предметы: накрыто %d из %d" % [covering, seen_clouds])

	# ДЫМ ЕДЕТ ВЛЕВО вместе с потоком. Проверяется самый честный случай — облако
	# БЕЗ цели (шашка ушла в пустой лейн): облако с целью ездит за ней и потому
	# ничего не доказывает. Раньше беспризорное облако висело в точке падения всю
	# свою жизнь и читалось как грязь на стекле, а не как дым в кадре.
	var lone := Node2D.new()
	lone.set_script(load("res://scripts/smoke_screen.gd"))
	lone.position = Vector2(vp.x * 0.60, vp.y * 0.5)
	sp.add_child(lone)
	var puff := Sprite2D.new()
	puff.texture = load("res://assets/bosses/ninja_foot/smoke.png")
	lone.call("setup", puff, null, 6.0, 250.0)
	var x0 : float = lone.position.x
	var ms : int   = Time.get_ticks_msec()
	await _tick(0.5)
	# Меряем ПРОЙДЕННОЕ ВРЕМЯ, а не число кадров: дым едет по delta, а тест
	# считает кадрами, и на просевшей частоте фиксированный порог врал бы.
	var dt : float = float(Time.get_ticks_msec() - ms) / 1000.0
	var moved : float = x0 - lone.position.x
	_check(moved > 250.0 * dt * 0.6,
		"дым без цели уезжает влево с потоком: %.0f px за %.2f c" % [moved, dt])
	lone.queue_free()
	await process_frame

	# И облако не висит вечно: иначе лейн превращается в стену до конца забега.
	# Ждём СОБЫТИЯ, а не отсчитываем секунды: облако тает по таймеру реального
	# времени, а счётчик теста считает кадры, и стоит игре просесть по частоте —
	# фиксированная пауза начинает мерить не жизнь дыма, а скорость машины.
	var t := 0.0
	while t < 12.0 and not get_root().get_tree().get_nodes_in_group("smoke").is_empty():
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	_check(get_root().get_tree().get_nodes_in_group("smoke").is_empty(),
		"а потом рассеивается (%.1f)" % t)
	game.queue_free()
	await process_frame

# КОНУС — ТРИ РАЗМЕРА И НИКАКИХ ТАПОВ.
#
# Раньше конус был единственным предметом потока, который разбирали тапами:
# число на нём, подсказка «тапай», сжатие на ряд при обнулении. Механика убрана
# — она перебивала основное управление (палец ведёт голову) ради частного
# случая в одном-единственном месте игры.
#
# Проверяется три вещи, и все три ломаются молча:
#  • размер вообще СЛУШАЕТСЯ — иначе весь смысл предмета сводится к одному
#    трёхрядному, как было раньше;
#  • вместе с картинкой растёт КОЛЛИЗИЯ. Их считают в разных строках `_resize`,
#    и разъехавшись они дают конус, который бьёт мимо себя;
#  • на конусе не осталось ни числа, ни подсказки, ни ловли тапов: забытая
#    ловля превратила бы высокий конус в мёртвую зону для дабл-тапа спелла.
func _test_cone_tap() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size

	var heights : Array = []
	var widths  : Array = []
	for rows in [1, 2, 3]:
		sp.call("clear_items")
		await process_frame
		sp.call("_spawn_cone", vp.x, 0.0, rows)
		await process_frame
		var c : Node2D = null
		for n in sp.get_children():
			if n.is_in_group("cone"):
				c = n
		if c == null:
			_check(false, "конус в %d ряда появился" % rows)
			game.queue_free()
			return
		_check(int(c.call("rows")) == rows, "конус слушается размера: просили %d" % rows)
		var shape : Node = null
		for n in c.get_children():
			if n is CollisionShape2D:
				shape = n
		var sz : Vector2 = ((shape as CollisionShape2D).shape as RectangleShape2D).size
		heights.append(sz.y)
		widths.append(sz.x)
		# Ни числа, ни подсказки, ни ловли тапов.
		_check(c.get("_lbl") == null and c.get("_prompt") == null,
			"на конусе нет ни числа, ни подсказки")
		_check(not bool(c.get("input_pickable")), "и он не ловит тапы")

	# Коллизия РАСТЁТ ВМЕСТЕ С РЯДАМИ и ровно пропорционально: высота ряда одна
	# и та же, значит два ряда обязаны дать вдвое больше первого.
	_check(heights[1] > heights[0] and heights[2] > heights[1],
		"коллизия растёт с размером: %s" % [heights])
	_check(is_equal_approx(float(heights[1]) / float(heights[0]), 2.0)
		and is_equal_approx(float(heights[2]) / float(heights[0]), 3.0),
		"и растёт ровно по рядам: %s" % [heights])
	# Ширина конуса — от той же картинки, поэтому тоже пропорциональна: рисунок
	# масштабируется целиком, а не растягивается по высоте.
	_check(is_equal_approx(float(widths[2]) / float(widths[0]), 3.0),
		"картинка масштабируется целиком, а не тянется: %s" % [widths])

	# И СБИТЫЙ ПАДАЕТ, как любой другой предмет. Раньше `knock_down` у конуса не
	# было вовсе, и `_kill_item` сносил его через `queue_free()`: трёхрядная
	# махина просто исчезала из кадра.
	var cone : Node2D = null
	for n in sp.get_children():
		if n.is_in_group("cone"):
			cone = n
	_check(cone != null and cone.has_method("knock_down"), "конус умеет падать")
	if cone != null:
		var y0 : float = cone.position.y
		cone.call("knock_down")
		for _i in 20:
			await process_frame
		var y1 : float = cone.position.y if is_instance_valid(cone) else y0
		_check(is_instance_valid(cone) and y1 > y0,
			"сбитый конус уходит вниз: %.0f → %.0f" % [y0, y1])
	game.queue_free()
	await process_frame

# ── МЕШОК ДЕНЕГ: ТАП РАСТИТ МЕШОК И ВЫПЛАТУ ──────────────────────────────────
# Мешок летит небольшим, с числом «1» на боку. Каждый тап прибавляет к числу
# единицу и раздувает мешок; поймал — получил столько долларов, сколько натапал.
#
# Проверяются четыре вещи, и все четыре ломаются молча:
#  • число и размер идут ВМЕСТЕ. Разъедутся — мешок будет платить не за то, что
#    видно, а такое расхождение глазами не поймать;
#  • вместе с рисунком растёт КОЛЛИЗИЯ. Отстанет — мешок начнёт ловиться мимо
#    себя, и это худший вид несправедливости у ресурса;
#  • поимка платит РОВНО столько, сколько на боку, и второй раз не платит;
#  • раздутый мешок НЕ СГОРАЕТ. Он таран, и горящий предмет ломает сам.
# ── КАЖДЫЙ ПУНКТ ВЫПАДАШКИ И ПРАВДА КОГО-ТО ЗОВЁТ ──────────────────────────
# Чипы подписаны словами, а зовут по КЛЮЧУ из таблиц HAZ_LEVEL. Ключ — обычная
# строка, и разъезжается она молча: переименовали угрозу в спавнере, забыли в
# списке — и кнопка жмётся, звук играет, а на арене ничего. Именно так дев-панель
# и врёт: не падает, а тихо перестаёт работать.
#
# Список берётся ИЗ САМОГО HUD, а не переписывается сюда: копия рядом с
# оригиналом разошлась бы с ним на первой же правке, и тест продолжил бы
# проверять то, чего в игре уже нет.
#
# `hud.gd` тут не грузится через preload намеренно — он ссылается на автолоады, и
# в тесте-SceneTree такой preload молча не компилируется. Берём карту констант у
# ЖИВОГО скрипта из собранной сцены.
func _test_dev_mini_bosses() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	var consts : Dictionary = hud.get_script().get_script_constant_map()
	var list : Array = consts.get("MINI_BOSSES", [])
	_check(not list.is_empty(), "список мини-боссов взят из HUD: %d штук" % list.size())

	var silent : Array = []
	for it in list:
		var kind : String = String((it as Array)[1])
		sp.call("clear_items")
		await process_frame
		var before : int = sp.get_child_count()
		sp.call("dev_send_hazard", kind)
		await process_frame
		if sp.get_child_count() <= before:
			silent.append(kind)
	_check(silent.is_empty(), "и все они действительно спавнятся: молчат %s" % [silent])

	# И У КАЖДОГО ЕСТЬ ПОДПИСЬ И ЦВЕТ. Пустая подпись даёт чип-невидимку: он есть,
	# он нажимается, и понять, кто это, нельзя.
	var noname : Array = []
	for it in list:
		if String((it as Array)[0]).strip_edges() == "":
			noname.append(String((it as Array)[1]))
	_check(noname.is_empty(), "и у каждого подпись словом: %s" % [noname])

	game.queue_free()
	await process_frame

# ЛЕВЫЙ СТОЛБЕЦ ДЕВ-КНОПОК: КАЖДОЙ СВОЁ МЕСТО.
#
# «МИНИ» получила номер, уже занятый «ФЗ». «ФЗ» строится позже — и просто
# накрыла новую кнопку собой: в игре её не было вовсе. Ни один тест этого не
# заметил, потому что спавн мини-боссов работал прекрасно, а кнопки, которая его
# зовёт, никто не искал глазами.
#
# Проверка идёт ПО ТЕКСТУ hud.gd, а не по собранному экрану, и намеренно.
# Кнопки столбца висят на двух рубильниках DevFlags, «ФЗ» вдобавок только в
# кампании, а строится всё это внутри `_start_game` — то есть собранный столбец
# в тесте почти всегда неполон, и как раз без той кнопки, из-за которой всё
# случилось. Номер места — свойство исходника, там его и надо смотреть.
func _test_dev_column_slots() -> void:
	var src : String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	_check(not src.is_empty(), "исходник HUD прочитан: %d байт" % src.length())

	var re := RegEx.new()
	re.compile("_dev_col_pos\\((\\d+)\\)")
	var slots : Dictionary = {}   # номер места → сколько кнопок его заняли
	for m in re.search_all(src):
		var slot : int = int(m.get_string(1))
		slots[slot] = int(slots.get(slot, 0)) + 1
	_check(slots.size() >= 6, "мест в столбце занято: %s" % [slots.keys()])

	var taken_twice : Array = []
	for slot in slots.keys():
		if int(slots[slot]) > 1:
			taken_twice.append("№%d: %d кнопки" % [int(slot), int(slots[slot])])
	_check(taken_twice.is_empty(), "и ни одно не занято дважды: %s" % [taken_twice])

# ── СВАТ В ПОТОКЕ: ИДЁТ ПО ЛИНИИ СО СКОРОСТЬЮ ПОТОКА ───────────────────────
# Правило простое и оттого легко ломающееся молча: боец едет РОВНО со скоростью
# потока — не своим боевым шагом в 46 px/c и не быстрее соседей, — а разница
# между тремя видами только в том, что он при этом делает.
#
# Щитоносец не делает НИЧЕГО: он и есть проверка того, что скорость — это
# скорость, а не побочный эффект стрельбы.
func _test_swat_in_stream() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node   = game.get_node_or_null("Spawner")
	var nd : Node2D = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size
	await process_frame

	# ВСЕ ТРИ ВИДА ДОСТИЖИМЫ. Вид, который не выпадает, всё равно что не написан.
	var seen : Dictionary = {}
	for i in 200:
		sp.call("_spawn_swat", vp.y * 0.5, vp.x, 250.0)
	for c in sp.get_children():
		if c.is_in_group("swat"):
			seen[String(c.get("kind"))] = true
	_check(seen.size() == 3, "поток выдаёт все три вида: %s" % str(seen.keys()))
	sp.call("clear_items")
	await process_frame

	# СКОРОСТЬ. Меряется перемещением за секунду, а не полем `walk_speed`: поле
	# можно поставить и не использовать, и ровно так этот баг и выглядел бы.
	var stream_v : float = 250.0
	var slow : Array = []
	for kind in ["shield", "rifle", "grenade"]:
		var s : Node2D = _put_swat(sp, kind, nd, vp, stream_v)
		var x0 : float = s.position.x
		await _tick(0.60)
		if not is_instance_valid(s):
			slow.append("%s исчез" % kind)
			continue
		var v : float = (x0 - s.position.x) / 0.60
		# Отдача стрелка дёргает его на 6 px туда-обратно — допуск шире неё.
		if absf(v - stream_v) > 24.0:
			slow.append("%s: %.0f px/c" % [kind, v])
		sp.call("clear_items")
		await process_frame
	_check(slow.is_empty(), "и каждый идёт со скоростью потока: отстают %s" % [slow])

	# ЩИТОНОСЕЦ ПРОСТО ИДЁТ. Полторы секунды — дольше, чем первый выстрел
	# стрелка (1.05) и бросок гранатомётчика (0.85): будь у щита хоть один из
	# этих ходов, он бы к этому моменту уже случился.
	var shield : Node2D = _put_swat(sp, "shield", nd, vp, stream_v)
	await _tick(1.60)
	_check(_swat_shots(sp) == 0 and is_instance_valid(shield),
		"щитоносец за полторы секунды не выпустил ничего: %d" % _swat_shots(sp))
	sp.call("clear_items")
	await process_frame

	# А ОСТАЛЬНЫЕ ДВОЕ — СО СВОИМИ ЭФФЕКТАМИ, и это тот же ход, что в бою.
	_put_swat(sp, "rifle", nd, vp, stream_v)
	await _tick(1.60)
	_check(_swat_shots(sp) > 0, "стрелок на ходу стреляет: %d" % _swat_shots(sp))
	sp.call("clear_items")
	await process_frame

	_put_swat(sp, "grenade", nd, vp, stream_v)
	await _tick(1.30)
	_check(_swat_shots(sp) > 0, "гранатомётчик на ходу бросает: %d" % _swat_shots(sp))

	game.queue_free()
	await process_frame

# Боец в потоке ставится тем же путём, что и спавнером: kind ДО add_child,
# скорость потока, цель — Нормальдо, вход без вертолёта.
func _put_swat(sp: Node, kind: String, nd: Node2D, vp: Vector2,
		speed: float) -> Node2D:
	var node := Area2D.new()
	node.set_script(load("res://scripts/police_swat.gd"))
	node.set("kind", kind)
	node.set("walk_speed", speed)
	node.set("target", nd)
	node.position = Vector2(vp.x * 0.80, vp.y * 0.5)
	sp.add_child(node)
	node.call("enter_from_edge")
	return node

# Всё, что боец выпустил из рук: пули по группе, граната — по своему полю.
func _swat_shots(sp: Node) -> int:
	var n : int = 0
	for c in sp.get_children():
		if c.is_in_group("bullet") or c.get("from_pos") != null:
			n += 1
	return n

# ── КРОКОДИЛ РОСТОМ ПОЧТИ В ЛИНИЮ ──────────────────────────────────────────
# Он нарисован ЛЁЖА — вдвое шире, чем выше, — и пока размер считался по длинной
# стороне, на экран он выходил высотой в 42 пикселя при линии в 86. Проверяется
# поэтому именно ВЫСОТА РИСУНКА относительно полосы, а не константа: константу
# можно поставить какую угодно и снова померить не ту сторону.
func _test_croc_size() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size
	var lane : float = vp.y / 5.0
	sp.call("dev_send_hazard", "croc")
	await process_frame

	var croc : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("croc"):
			croc = c
	_check(croc != null, "крокодил в потоке появился")
	if croc != null:
		var spr : Sprite2D = null
		for k in croc.get_children():
			if k is Sprite2D:
				spr = k
		var drawn := Vector2(ItemSizing.content_rect(spr.texture).size) * spr.scale
		_check(drawn.y >= lane * 0.85 and drawn.y <= lane,
			"и ростом почти в линию: %.0f при линии %.0f" % [drawn.y, lane])
		# Хитбокс обязан ехать за ростом: крокодил длинный, и коробка «по росту»
		# оставила бы половину туши проходимой насквозь.
		var box : RectangleShape2D = null
		for k in croc.get_children():
			if k is CollisionShape2D:
				box = (k as CollisionShape2D).shape as RectangleShape2D
		_check(box != null and box.size.x > drawn.y,
			"а хитбокс шире, чем высок: %s" % [box.size if box != null else Vector2.ZERO])

	game.queue_free()
	await process_frame

func _test_money_bag_glyph() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	var nd : Node = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)

	sp.call("dev_spawn_money_bag")
	await process_frame
	var bag : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("money_bag"):
			bag = c
	_check(bag != null, "мешок появился")
	if bag == null:
		game.queue_free()
		return

	var shape : CollisionShape2D = null
	for c in bag.get_children():
		if c is CollisionShape2D:
			shape = c
	_check(shape != null, "и у него есть зона подбора")
	if shape == null:
		game.queue_free()
		return

	_check(int(bag.call("payout")) == 1, "нетронутый стоит один доллар")
	_check(not bool(bag.call("is_ram")), "и тараном ещё не является")
	var r0 : float = (shape.shape as CircleShape2D).radius

	# Пять тапов: число +5, размер и коллизия выросли вместе с ним.
	for _i in 5:
		bag.call("tap")
	await process_frame
	_check(int(bag.call("payout")) == 6, "пять тапов → шесть долларов: %d" % int(bag.call("payout")))
	var r1 : float = (shape.shape as CircleShape2D).radius
	_check(r1 > r0, "зона подбора выросла вместе с мешком: %.1f → %.1f" % [r0, r1])
	_check(bool(bag.call("is_ram")), "раздутый стал тараном")
	# Число на боку — то же самое, что выплата. Иначе мешок платит не за то, что
	# показывает, и спорить с ним игроку нечем.
	var shown : Array = []
	for c in bag.get_children():
		if c is Label:
			shown.append(String((c as Label).text))
	_check(shown.has("6"), "и на боку написано то же число: %s" % [shown])

	# ── РОСТ НЕ КОНЧАЕТСЯ, НО ВЫДЫХАЕТСЯ ────────────────────────────────────
	# Потолка нет: тут стояла проверка, что после двухсот тапов мешок замирает.
	# Теперь он растёт всегда — просто всё скупее, и проверять надо ровно это.
	# Иначе выйдет одно из двух вранья: «остановился» (его нет) или «растёт как
	# раньше» (тогда при сотне тапов он был бы выше экрана).
	for _i in 30:
		bag.call("tap")
	await process_frame
	var r_30 : float = (shape.shape as CircleShape2D).radius
	for _i in 30:
		bag.call("tap")
	await process_frame
	var r_60 : float = (shape.shape as CircleShape2D).radius
	for _i in 30:
		bag.call("tap")
	await process_frame
	var r_90 : float = (shape.shape as CircleShape2D).radius
	_check(r_60 > r_30 and r_90 > r_60,
		"мешок растёт и после сотни тапов: %.0f → %.0f → %.0f" % [r_30, r_60, r_90])
	# Каждая следующая тридцатка прибавляет МЕНЬШЕ предыдущей — на этом и держится
	# то, что мешок не съедает экран.
	_check((r_90 - r_60) < (r_60 - r_30),
		"но прибавка убывает: +%.0f, потом +%.0f" % [r_60 - r_30, r_90 - r_60])

	# РАЗДУТЫЙ НЕ СГОРАЕТ: огонь зовёт `burst()` без ловца.
	_check(int(bag.call("burst", 1, null)) == 0, "раздутый мешок огню не поддался")
	_check(is_instance_valid(bag) and not bool(bag.get("_spent")),
		"и остался в кадре")

	# ПОИМКА платит ровно столько, сколько на боку, и один раз.
	var due : int = int(bag.call("payout"))
	var paid : int = int(bag.call("burst", 1, nd))
	_check(paid == due, "поимка заплатила по числу: %d при %d" % [paid, due])
	_check(int(bag.call("burst", 1, nd)) == 0, "а второй раз не платит")

	# ОБЫЧНЫЙ мешок огню поддаётся — он ресурс, а не таран.
	sp.call("clear_items")
	sp.call("dev_spawn_money_bag")
	await process_frame
	var plain : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("money_bag"):
			plain = c
	_check(plain != null and int(plain.call("burst", 1, null)) == 0,
		"нетронутый мешок сгорает без выплаты")
	_check(plain != null and bool(plain.get("_spent")), "и после огня уже потрачен")

	game.queue_free()
	await process_frame

# ── ТАПЫ ПО МЕШКУ ЗАМЕДЛЯЮТ ВРЕМЯ ──────────────────────────────────────────
# Три поведения, и все три обязаны выйти из ОДНОГО заряда, а не из трёх правил:
# частый стук держит замедление, редкий его отпускает, и отпущенным мир обязан
# вернуться ровно к единице.
#
# Последнее — самое опасное. Мешок берёт паузу потока и вычитает её обратно; не
# вернуть её значит заморозить поток до конца забега, а такое лечится только
# следующим боссом и выглядит не как баг, а как «игра кончилась».
func _test_money_bag_slowmo() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")

	sp.call("dev_spawn_money_bag")
	await process_frame
	var bag : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("money_bag"):
			bag = c
	if bag == null:
		_check(false, "мешок появился для замера времени")
		game.queue_free()
		return

	# СТУЧИМ ПО-ЧЕЛОВЕЧЕСКИ — раз в семь кадров, это около восьми тапов в секунду.
	# Каждый кадр — не проверка механики, а проверка машины: живой палец так не
	# умеет, и заряд, который держится только от такой частоты, в руках не
	# удержался бы.
	var t := 0.0
	var f := 0
	while t < 0.9:
		f += 1
		if f % 7 == 0:
			bag.call("tap")
		await process_frame
		t += 1.0 / 60.0
	var fast : float = float(sp.get("world_speed_mult"))
	_check(fast < 0.75, "от тапов время замедлилось: ×%.2f" % fast)

	# ДЕРЖИМ ЕЩЁ — и оно не отползает обратно, пока стучат.
	t = 0.0
	while t < 0.8:
		f += 1
		if f % 7 == 0:
			bag.call("tap")
		await process_frame
		t += 1.0 / 60.0
	var held : float = float(sp.get("world_speed_mult"))
	_check(held <= fast + 0.05, "и держится, пока стучат: ×%.2f" % held)

	# ── ПОТОЛКА НЕТ ──────────────────────────────────────────────────────────
	# Ни на числе, ни на размере. Прежний потолок стоял на пятнадцати тапах и был
	# заодно потолком заработка — а мешок и заводился ради того, чтобы за него
	# работать. Стучим заведомо больше и проверяем, что счёт идёт РОВНО ПО
	# ЕДИНИЦЕ: убывать должен только рисунок, но не выплата.
	var before : int = int(bag.call("payout"))
	for _i in 40:
		bag.call("tap")
		await process_frame
	_check(int(bag.call("payout")) == before + 40,
		"сорок тапов сверх прежнего потолка — сорок долларов: %d → %d"
			% [before, int(bag.call("payout"))])
	# А рисунок при этом остаётся ПРЕДМЕТОМ. Линейный рост без потолка дал бы
	# при таком числе тапов мешок выше экрана; убывающая прибавка держит его в
	# рамках, не ставя никакой границы.
	var px : float = 52.0 * float(bag.get("_grow"))
	_check(px < 260.0, "и мешок остался предметом, а не задником: %.0f px" % px)

	# И ЧБ НА МЕШОК НЕ ВЕШАЕТСЯ. Чёрно-белый экран — знак песочных часов; надетый
	# на каждый тап по мешку, он перестал бы что-либо значить.
	var gray : Node = game.get_node_or_null("WorldGray")
	_check(gray == null or not bool(gray.call("is_gray")),
		"а экран при этом не чёрно-белый — это знак часов, не мешка")

	# ПЕРЕСТАЛИ — возвращается само, без чужой помощи.
	t = 0.0
	while t < 3.0 and float(sp.get("world_speed_mult")) < 0.999:
		await process_frame
		t += 1.0 / 60.0
	_check(is_equal_approx(float(sp.get("world_speed_mult")), 1.0),
		"перестали стучать — время вернулось за %.1f c" % t)
	# И ПОТОК СНОВА ИДЁТ. Пауза, взятая мешком, обязана быть отдана.
	_check(not bool(sp.get("_frozen")), "и поток снова идёт, а не стоит замороженным")

	# ── УЕХАВШИЙ МЕШОК ЗАБИРАЕТ ЗАМЕДЛЕНИЕ С СОБОЙ ───────────────────────────
	# Потолка больше нет, и единственное, что кончает взаимодействие, — это сам
	# мешок, уезжающий за край. Значит именно его исчезновение обязано вернуть и
	# скорость мира, и паузу потока: иначе «тапай сколько успеешь» превращается в
	# «поток стоит до конца забега».
	for _i in 20:
		bag.call("tap")
		await process_frame
	_check(float(sp.get("world_speed_mult")) < 0.999, "снова настучали — снова медленно")
	bag.queue_free()
	for _i in 5:
		await process_frame
	_check(is_equal_approx(float(sp.get("world_speed_mult")), 1.0),
		"мешок уехал — время вернулось")
	_check(not bool(sp.get("_frozen")), "и паузу он забрал с собой")

	game.queue_free()
	await process_frame

# Сейф — единственный предмет, за удар о который ПЛАТЯТ: бьёт на 2 и тем же
# ударом вскрывается, высыпая доллары. Ломается это по частям и молча: урон
# может остаться без выплаты (и сейф снова станет самым дорогим способом
# потерять жир), выплата — без урона (и он станет бесплатным банкоматом), а сам
# он может залипнуть на голове навсегда.
#
# Проверяется поэтому весь такт: цена, товар, и то, что сейф после этого
# ОТВАЛИВАЕТСЯ.
func _test_safe_crack() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	var n  : Node2D = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size

	# Сейф в игре ОДИН: строки в таблице угроз у него больше нет, иначе рядом с
	# настоящим летал бы второй — тихий и бесплатный.
	var hz = load("res://scripts/hazard_item.gd")
	_check(not (hz.KINDS as Dictionary).has("safe"),
		"сейфа нет среди рядовых угроз — он свой скрипт")

	sp.call("_spawn_safe", vp.y * 0.5, vp.x, 250.0)
	await process_frame
	var safe : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("safe"):
			safe = c
	_check(safe != null, "сейф появился")
	if safe == null:
		game.queue_free()
		return
	# Группа `safe` — то, по чему его узнаёт резист скина; `obstacle` — ветка
	# удара. Потеряй он любую, и он либо перестанет бить, либо перестанет
	# резаться.
	_check(safe.is_in_group("obstacle"), "и лежит в обычной ветке удара")
	_check(int(safe.get("damage")) == 2, "бьёт на два: %d" % int(safe.get("damage")))

	# Настоящий удар головой: жир падает И деньги высыпаются.
	var save : Node = get_root().get_node_or_null("SaveData")
	save.active_skin = "classic"       # без резистов: проверяем цену, а не защиту
	save.skin_level  = 1
	n.call("reload_skin")
	n.call("_build_skin_runtime")
	# Ставим полный жир: на нулевом удар в два просто убивает, и «сколько стоил
	# сейф» проверить уже нечем.
	n.set("fat_state", 3)
	n.call("_apply_skin_to_sprite")
	await process_frame
	var fat0 : int = int(n.get("fat_state"))
	safe.position = n.position
	await _tick(0.3)
	_check(int(n.get("fat_state")) < fat0 or bool(n.get("_dead")),
		"удар о сейф стоит жира: %d → %d" % [fat0, int(n.get("fat_state"))])

	# Деньги: считаем НАКОПИТЕЛЬНО, по номерам узлов. Одновременно на экране их
	# столько не бывает — доллары летят влево прямо в голову и собираются на
	# ходу, так что «сколько сейчас лежит» меряет не выплату, а скорость еды.
	var want : int = int(load("res://scripts/safe.gd").COIN_COUNT)
	var seen_coins : Dictionary = {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		get_root().get_tree().paused = false
		await process_frame
		for c in sp.get_children():
			if c.is_in_group("dollar") or c.is_in_group("money_bag"):
				seen_coins[c.get_instance_id()] = true
		if seen_coins.size() >= want:
			break
	_check(seen_coins.size() >= want,
		"и высыпает пачку: %d штук" % seen_coins.size())

	# И ОТВАЛИВАЕТСЯ: пустой сейф не остаётся висеть на голове.
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 5000:
		get_root().get_tree().paused = false
		await process_frame
		if not is_instance_valid(safe) or bool(safe.get("_falling")):
			break
	_check(not is_instance_valid(safe) or bool(safe.get("_falling")),
		"пустой сейф отваливается и падает")
	if is_instance_valid(safe):
		_check(int(safe.get("collision_layer")) == 0,
			"и по дороге вниз уже не бьёт")

	# И ПО РЕЗИСТУ ТОЖЕ. Резист (венец викинга, десятый уровень) отменяет урон,
	# но не отменяет того, что по ящику ударили: деньги высыпаются, а платит за
	# них не жир, а прокачанный до конца скин.
	sp.call("clear_items")
	await process_frame
	save.active_skin = "viking"
	save.skin_level  = 10
	n.call("reload_skin")
	n.call("_build_skin_runtime")
	n.set("fat_state", 3)
	n.call("_apply_skin_to_sprite")
	await process_frame
	_check(bool(n.call("is_skill_ready", "resist:safe")),
		"у прокачанного викинга резист на сейф готов")

	sp.call("_spawn_safe", vp.y * 0.5, vp.x, 250.0)
	await process_frame
	var safe2 : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("safe"):
			safe2 = c
	if safe2 != null:
		var fat_r : int = int(n.get("fat_state"))
		safe2.position = n.position
		var want2 : int = int(load("res://scripts/safe.gd").COIN_COUNT)
		var seen2 : Dictionary = {}
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 6000:
			get_root().get_tree().paused = false
			await process_frame
			for c in sp.get_children():
				if c.is_in_group("dollar") or c.is_in_group("money_bag"):
					seen2[c.get_instance_id()] = true
			if seen2.size() >= want2:
				break
		_check(int(n.get("fat_state")) == fat_r,
			"резист удар отменил: жир %d → %d" % [fat_r, int(n.get("fat_state"))])
		_check(seen2.size() >= want2,
			"но сейф всё равно вскрылся: %d штук" % seen2.size())

	# И ЧЕРЕЗ МАСКУ КЕЙСИ. Маска поглощает удар и слетает — но по ящику ударили,
	# а чем именно приняли удар, ящику всё равно.
	sp.call("clear_items")
	await process_frame
	save.active_skin = "classic"
	save.skin_level  = 1
	n.call("reload_skin")
	n.call("_build_skin_runtime")
	n.set("fat_state", 3)
	n.call("_apply_skin_to_sprite")
	n.call("_begin_scars", 8.0, false)
	await process_frame
	_check(bool(n.get("_scars_active")), "маска Кейси надета")

	sp.call("_spawn_safe", vp.y * 0.5, vp.x, 250.0)
	await process_frame
	var safe3 : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("safe"):
			safe3 = c
	if safe3 != null:
		var fat_m : int = int(n.get("fat_state"))
		safe3.position = n.position
		var want3 : int = int(load("res://scripts/safe.gd").COIN_COUNT)
		var seen3 : Dictionary = {}
		var t3 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t3 < 6000:
			get_root().get_tree().paused = false
			await process_frame
			for c in sp.get_children():
				if c.is_in_group("dollar") or c.is_in_group("money_bag"):
					seen3[c.get_instance_id()] = true
			if seen3.size() >= want3:
				break
		_check(int(n.get("fat_state")) == fat_m, "маска удар приняла: жир не упал")
		_check(seen3.size() >= want3,
			"и сейф всё равно вскрылся: %d штук" % seen3.size())

	game.queue_free()
	await process_frame

# ПРАВИЛО: из замедляющих бьёт только змея. Всё остальное, что замедляет, —
# коктейль, бутылка, банан, пиво, яд, девочка-зазывала — урона не наносит вовсе.
#
# «Не наносит» здесь означает БОЛЬШЕ, чем `damage = 0`. Ноль всё равно уходил в
# `_take_hit`, а тот на нулевом жире зовёт смерть и в любом случае обнуляет
# счётчик пиццы: бутылка съедала прогресс к следующему жиру, а на последнем
# делении просто убивала. Отсюда и жалоба «замедляющие тоже наносят урон».
#
# Проверяется поэтому и таблица, и поведение на нулевом жире.
func _test_slowers_dont_hit() -> void:
	var hz = load("res://scripts/hazard_item.gd")
	var bad : Array = []
	for k in (hz.KINDS as Dictionary):
		var cfg : Dictionary = hz.KINDS[k]
		if float(cfg.get("slow", 0.0)) > 0.0 and int(cfg.get("dmg", 0)) > 0:
			bad.append(k)
	_check(bad.is_empty(), "в таблице угроз замедляющие не бьют: %s" % [bad])

	# Змея — исключение, и оно ЖИВОЕ: она и замедляет, и бьёт.
	var snake : Node = load("res://scenes/snake.tscn").instantiate()
	_check(bool(snake.get("slow_on_hit")) and int(snake.get("damage")) > 0,
		"а змея бьёт и замедляет — она одна такая")
	snake.free()

	# И поведение: нулевой урон НЕ убивает на пустом жире.
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	var n  : Node2D = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var save : Node = get_root().get_node_or_null("SaveData")
	save.active_skin = "classic"
	save.skin_level  = 1
	n.call("reload_skin")
	n.call("_build_skin_runtime")
	n.set("fat_state", 0)
	n.set("_dev_immortal", false)
	await process_frame

	var vp : Vector2 = get_root().get_visible_rect().size
	sp.call("_spawn_hazard", "bottle", n.position.y, vp.x, 250.0)
	await process_frame
	for c in sp.get_children():
		if c.get("kind") != null and String(c.get("kind")) == "bottle":
			(c as Node2D).position = n.position
	await _tick(0.4)
	_check(not bool(n.get("_dead")),
		"бутылка на пустом жире не убивает")
	_check(float(n.get("_slow_remaining")) > 0.0,
		"но замедляет: %.1f с" % float(n.get("_slow_remaining")))

	game.queue_free()
	await process_frame

# Люди в потоке ПОКАЧИВАЮТСЯ. Неподвижная фигура рядом с ползущей змеёй и
# пляшущим костром читается не как человек, а как картонка с человеком.
#
# Проверяется общий кирпич (`human_sway.gd`) и то, что фаза у каждого СВОЯ:
# синхронная волна бомжей выглядит строем на параде — ровно обратное тому,
# зачем покачивание вводилось.
func _test_human_sway() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size

	for i in 6:
		sp.call("_spawn_homeless", vp.y * (0.15 + 0.12 * float(i)), vp.x, 250.0)
	sp.call("_spawn_hazard", "cop", vp.y * 0.5, vp.x, 250.0)
	sp.call("_spawn_hazard", "shaman", vp.y * 0.7, vp.x, 250.0)
	await _tick(0.35)

	var rots : Array = []
	var bums : Array = []
	for c in sp.get_children():
		var sc = c.get_script()
		if sc == null:
			continue
		var nm := String(sc.resource_path).get_file().get_basename()
		if nm == "homeless":
			bums.append(c)
		if nm == "homeless" or nm == "hazard_item":
			for d in c.get_children():
				if d is Sprite2D:
					rots.append(float((d as Sprite2D).rotation))
	var moving := 0
	for r in rots:
		if absf(r) > 0.001:
			moving += 1
	_check(moving >= 3, "люди в потоке качаются: %d из %d" % [moving, rots.size()])

	# Фазы РАЗНЫЕ: у бомжей из одной волны углы не должны совпадать.
	var phases : Dictionary = {}
	for b in bums:
		phases[snappedf(float(b.get("_sway_ph")), 0.01)] = true
	_check(phases.size() >= maxi(2, bums.size() - 1),
		"и у каждого своя фаза: %d разных на %d бомжей" % [phases.size(), bums.size()])

	game.queue_free()
	await process_frame

# Бомжей ДВА — рыжий и седой, — и они равноправны: это разнообразие, а не два
# разных врага. Спавнится каждый случайно, и ломается это молча: набор из одного
# кадра выглядит исправно работающим, просто все бомжи на экране одинаковые.
#
# Проверяются все три места, где бомж появляется: одиночный из потока, бомж со
# знаком и бомж с бочкой. Каждое хранит свой список кадров, и достаточно одному
# из них разъехаться, чтобы половина бомжей в игре стала одноликой.
func _test_bum_variety() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size

	# Сорок спавнов на каждый источник: при честной монетке шанс не увидеть
	# второй кадр — один на пятьсот миллиардов.
	#
	# Каждый источник считается СРАЗУ, без ожидания кадра. Кадр здесь не нужен:
	# спрайт ставится в `_ready`, то есть уже на add_child. А вреден он тем, что
	# сет-пис с бочкой за это время успевает доиграть свой такт и подчистить
	# поток — тест мигал «кадров 0» на исправном коде.
	const TRIES : int = 40
	var seen_solo : Dictionary = {}
	for i in TRIES:
		sp.call("_spawn_homeless", vp.y * 0.5, vp.x, 250.0)
	_collect_tex(sp, seen_solo)
	sp.call("clear_items")

	var seen_sign : Dictionary = {}
	for i in TRIES:
		sp.call("_spawn_scripted", load("res://scripts/roadsign_bum.gd"),
			vp.y * 0.5, vp.x, 250.0)
	_collect_tex(sp, seen_sign)
	sp.call("clear_items")

	# Бочку держим в СВОЁМ узле: сет-пис по ходу такта чистит поток спавнера, и
	# сложенные туда сорок штук сносят друг друга.
	var pen := Node2D.new()
	sp.add_child(pen)
	var seen_barrel : Dictionary = {}
	for i in TRIES:
		var bb := Node2D.new()
		bb.set_script(load("res://scripts/bum_barrel.gd"))
		bb.call("setup", null, vp.y * 0.5, 250.0)
		pen.add_child(bb)
	_collect_tex(pen, seen_barrel)
	pen.queue_free()

	_check(seen_solo.size() == 2,
		"одиночный бомж бывает и рыжим, и седым: кадров %d" % seen_solo.size())
	_check(seen_sign.size() == 2,
		"бомж со знаком — тоже: кадров %d" % seen_sign.size())
	_check(seen_barrel.size() == 2,
		"и бомж с бочкой: кадров %d" % seen_barrel.size())

	game.queue_free()
	await process_frame

# Все текстуры бомжей внутри узла — у знака и у бочки спрайт тела лежит глубже.
func _collect_tex(node: Node, out: Dictionary) -> void:
	if node is Sprite2D and (node as Sprite2D).texture != null:
		var path := String((node as Sprite2D).texture.resource_path)
		if path.contains("homeless"):
			out[path] = true
	for c in node.get_children():
		_collect_tex(c, out)

# Тачка копов — не предмет, а событие в три такта: пашет, разбивается, роняет
# копов. Ломается это молча и по частям: машина, пролетевшая мимо, всё равно
# выглядит машиной, просто ничего не делает.
#
# Проверяется поэтому каждый такт отдельно, и главное — ЧТО ОСТАЁТСЯ ПОСЛЕ:
# два копа на соседних линиях, а не на той же, и не один.
func _test_police_car() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size
	var lane_h : float = vp.y / 5.0
	# Голову убираем с поля. Она стоит на третьей линии — ровно там, куда падает
	# один из копов, — и честно его ЛОМАЕТ: сбитый коп начинает падать, а тест
	# меряет линию по координате и видит её съехавшей вниз. Проверяется здесь
	# машина, а не столкновения.
	var nd : Node2D = game.get_node_or_null("Normaldo")
	if nd != null:
		nd.position = Vector2(-600.0, vp.y * 0.5)

	sp.call("_spawn_police_car", 0.0, vp.x, 250.0)
	await process_frame
	var car : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("police_car"):
			car = c
	_check(car != null, "машина появилась")
	if car == null:
		game.queue_free()
		return

	# Две линии, а не одна: машина в один лейн — это просто длинный предмет.
	var box : CollisionShape2D = null
	for c in car.get_children():
		if c is CollisionShape2D:
			box = c
	var h : float = 0.0 if box == null else float((box.shape as RectangleShape2D).size.y)
	_check(h > lane_h * 1.0 and h < lane_h * 2.0,
		"достаёт до обеих линий пары: %.0f при лейне %.0f" % [h, lane_h])
	# Размер — тот же, что у машины на финале хозяина клуба: в глазах игрока это
	# одна и та же машина, а не две разного роста.
	var spr : Sprite2D = null
	for c in car.get_children():
		if c is Sprite2D:
			spr = c
	var body_w : float = 0.0 if spr == null \
		else float(ItemSizing.content_rect(spr.texture).size.x) * spr.scale.x
	_check(absf(body_w - float(load("res://scripts/club_boss.gd").CAR_PX)) < 2.0,
		"и ростом с боссовую: %.0f при %.0f" % [body_w, float(load("res://scripts/club_boss.gd").CAR_PX)])
	_check(float(car.get("speed")) > 250.0,
		"идёт быстрее потока: %.0f против 250" % float(car.get("speed")))

	# Пашет: предмет, поставленный ей в лоб, сносится.
	var mark : Node2D = sp.call("build_random_item", 0.0)
	_check(mark != null, "мишень собрана")
	if mark != null:
		mark.position = car.position
		sp.add_child(mark)
		await process_frame
		await process_frame
		var swept : bool = not is_instance_valid(mark) or bool(mark.get("_falling"))
		_check(swept, "и сносит всё, что попалось на пути")

	# Разбивается, не долетев до левого края. Подводим её к самой черте вручную:
	# ждать честного пролёта через весь экран здесь незачем, а машина после
	# аварии живёт меньше секунды и успевала освободиться прямо посреди опроса —
	# тест падал на `get` у мёртвого узла и МОЛЧА обрывался, показывая зелёное.
	var lane : int = int(car.get("lane"))
	# Запоминаем, кто был на экране ДО аварии: сбитая машиной мишень тоже могла
	# бы попасть в подсчёт «кто вылез».
	var before_ids : Dictionary = {}
	for c in sp.get_children():
		before_ids[c.get_instance_id()] = true

	car.position.x = vp.x * 0.32
	var crashed  := false
	var crash_x  := -1.0
	var no_hit   := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		get_root().get_tree().paused = false
		await process_frame
		if not is_instance_valid(car):
			break
		if bool(car.get("_crashed")):
			crashed = true
			crash_x = car.position.x
			no_hit  = int(car.get("collision_layer")) == 0
			break
	_check(crashed, "разбивается сама, а не улетает за край")
	_check(crash_x > 0.0, "и разбивается В КАДРЕ: x = %.0f" % crash_x)
	_check(no_hit, "разбитая машина больше не бьёт")

	# И роняет двух копов на РАЗНЫЕ линии рядом с занятой парой.
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 900:
		get_root().get_tree().paused = false
		await process_frame
	var cops : Array = []
	for c in sp.get_children():
		if before_ids.has(c.get_instance_id()):
			continue
		if c.get("kind") == null or String(c.get("kind")) != "cop":
			continue
		cops.append(c)
	_check(cops.size() == 2, "из неё вылезли двое: %d" % cops.size())
	if cops.size() == 2:
		var rows : Array = []
		var ys   : Array = []
		for c in cops:
			if is_instance_valid(c):
				rows.append(int(floor((c as Node2D).position.y / lane_h)))
				ys.append(int((c as Node2D).position.y))
		rows.sort()
		_check(rows.size() == 2 and rows[0] != rows[1],
			"и встали на разные линии: %s" % [rows])
		# Соседние линии — это lane-1 и lane+2. У края соседа с одной стороны
		# нет, и коп садится внутрь освободившейся пары: это тоже честно.
		var beside := true
		for r in rows:
			if r == lane or r == lane + 1:
				continue
			if r != lane - 1 and r != lane + 2:
				beside = false
		_check(beside, "рядом с занятой парой (%d–%d): %s (y=%s)"
			% [lane, lane + 1, rows, ys])

	game.queue_free()
	await process_frame

func _all_landed(dollars: Array) -> bool:
	for d in dollars:
		if not is_instance_valid(d) or not (d as Node).is_processing():
			return false
	return true

func _dollars(sp: Node) -> Array:
	var out : Array = []
	for c in sp.get_children():
		if c.is_in_group("dollar"):
			out.append(c)
	return out

func _put_ninja(sp: Node, kind: String, vp: Vector2) -> Node2D:
	var node := Area2D.new()
	node.set_script(NINJA)
	node.set("speed", 250.0)
	node.set("kind", kind)
	node.position = Vector2(vp.x + 40.0, vp.y * 0.5)
	sp.add_child(node)
	return node

# Пауза снимается КАЖДЫЙ кадр, а не один раз на входе: меню игры ставит дерево
# на паузу отложенно и может сделать это посреди прогона. Ниндзя живёт на
# _process и тюинах, и под паузой тест меряет не поведение, а паузу.
func _tick(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _test_box_pool() -> void:
	var sp : Node = Node2D.new()
	sp.set_script(SPAWNER)
	get_root().add_child(sp)
	await process_frame
	var kinds : Dictionary = {}
	for i in 1200:
		var n : Node2D = sp.call("build_random_item", 250.0)
		var k : String = String(n.get("kind")) if n.get("kind") != null else n.name
		if n.get("item_group") != null and String(n.get("item_group")) != "":
			k = String(n.get("item_group"))
		elif n.get("script") != null:
			k = String(n.get_script().resource_path).get_file().get_basename() if k == n.name else k
		kinds[k] = int(kinds.get(k, 0)) + 1
		n.free()
	_check(not kinds.has("casino_chip"), "жетона автомата в пуле нет: %s" % str(kinds))
	# Банан и пиво — один скрипт slowing_item.gd, коктейль — hazard_item с
	# kind="cocktail". Считаем всех троих.
	var slow : int = int(kinds.get("slowing_item", 0)) + int(kinds.get("cocktail", 0))
	_check(slow > 60, "замедляющие выпадают: %d из 1200" % slow)
	_check(int(kinds.get("cocktail", 0)) > 0, "и коктейль среди них: %d" % kinds.get("cocktail", 0))
	sp.queue_free()
	await process_frame

func _test_sizing() -> void:
	# Ради этого всё и затевалось: исходники различаются в разы, на экране —
	# одинаковые.
	var paths := [
		"res://assets/items/pizza.png",        # 511×449
		"res://assets/items/token.png",        #  89×89
		"res://assets/items/magic_hat.png",    # 536×615
		"res://assets/items/handcuffs.png",    # 435×352
		"res://assets/items/hourglass.png",    # 500×500
	]
	for p in paths:
		var tex : Texture2D = load(p)
		var sc  := ItemSizing.fit_scale(tex)
		var on_screen : float = maxf(tex.get_size().x, tex.get_size().y) * sc
		_check(absf(on_screen - ItemSizing.BASE_PX) < 0.5,
			"%s → %.1f px" % [p.get_file(), on_screen])

	# ── Мерить надо РИСУНОК, а не кадр ───────────────────────────────────────
	# `fit_scale` приводит к BASE_PX длинную сторону КАДРА, и у ассетов с полями
	# вокруг рисунка предмет выходит заметно мельче соседей: у знака и шляпы мага
	# рисунок занимает 0.70–0.74 длинной стороны, то есть на экране они были на
	# четверть мельче пиццы при формально одинаковом размере.
	#
	# Проверяем не «поля есть», а РЕЗУЛЬТАТ: после `content_scale` нарисованная
	# часть у всех приходит к заданному размеру. Порог полей — 0.85: ассет с
	# бо́льшими полями пройдёт мимо `fit_scale` незаметно, и это ловится здесь.
	var thin : Array = []
	for p in ["res://assets/items/road_sign.png", "res://assets/items/magic_hat.png",
			"res://assets/items/casey_mask.png", "res://assets/items/handcuffs.png",
			"res://assets/skills/ship_wheel.png"]:
		var tex : Texture2D = load(p)
		var r := ItemSizing.content_rect(tex)
		var frac : float = float(maxi(r.size.x, r.size.y)) \
			/ maxf(tex.get_size().x, tex.get_size().y)
		var drawn : float = float(maxi(r.size.x, r.size.y)) \
			* ItemSizing.content_scale(tex, ItemSizing.BASE_PX)
		if absf(drawn - ItemSizing.BASE_PX) > 0.5:
			thin.append("%s %.1f" % [p.get_file(), drawn])
	_check(thin.is_empty(),
		"рисунок приводится к %.0f px независимо от полей кадра: %s"
			% [ItemSizing.BASE_PX, thin])

	var mults : Array = []
	for i in 4000:
		mults.append(ItemSizing.roll_hazard_mult())
	var mn : float = mults.min()
	var mx : float = mults.max()
	var big : int = 0
	for m in mults:
		if m > 1.0:
			big += 1
	_check(mn >= ItemSizing.MULT_MIN and mx <= ItemSizing.MULT_MAX,
		"размер в границах [%.2f, %.2f]" % [mn, mx])
	_check(big > 800 and big < 1600, "крупных ≈30%% (%d из 4000)" % big)

func _test_multiplier() -> void:
	var seen : Dictionary = {}
	for i in 5000:
		var r := LootMultiplier.roll()
		seen[r] = int(seen.get(r, 0)) + 1
	_check(seen.size() == 5, "выпадают все пять множителей: %s" % [seen.keys()])
	var total : float = 0.0
	for k in seen:
		total += float(k) * float(seen[k])
	var avg := total / 5000.0
	_check(avg > 1.9 and avg < 2.6, "средний бросок %.2f" % avg)

func _test_items() -> void:
	var host := Node2D.new()
	get_root().add_child(host)

	# Спавнер нужен и как родитель (мэджик бокс просит у него предметы), и как
	# владелец резервов.
	var spawner := Node2D.new()
	spawner.set_script(SPAWNER)
	host.add_child(spawner)

	var kinds := ["hourglass", "casey_mask", "magic_hat", "cola",
		"loser_ticket", "handcuffs", "black_ace", "casino_chip"]
	var made : Array = []
	for kind in kinds:
		var node := Area2D.new()
		node.set_script(EFFECT_ITEM)
		node.set("kind", kind)
		node.position = Vector2(900.0, 200.0)
		spawner.add_child(node)
		made.append(node)

	var box := Area2D.new()
	box.set_script(MAGIC_BOX)
	box.position = Vector2(900.0, 200.0)
	spawner.add_child(box)

	var ninja := Area2D.new()
	ninja.set_script(NINJA)
	ninja.position = Vector2(900.0, 200.0)
	spawner.add_child(ninja)

	# Узлы, добавленные до старта дерева, получают _ready только на первом
	# кадре — проверять группы раньше бессмысленно.
	await process_frame

	for i in kinds.size():
		_check(made[i].is_in_group(kinds[i]),
			"предмет «%s» собран и в своей группе" % kinds[i])
	_check(box.is_in_group("magic_box"), "мэджик бокс собран")
	_check(ninja.is_in_group("ninja") and ninja.is_in_group("obstacle"),
		"ниндзя собран и бьёт при касании")

	# Пул мэджик бокса: каждый бросок обязан собираться в живой узел.
	var built_ok := true
	for i in 200:
		var n : Node2D = spawner.build_random_item(250.0)
		if n == null:
			built_ok = false
			break
		n.queue_free()
	_check(built_ok, "пул мэджик бокса собирает предметы (200 бросков)")

	# Пара секунд тиков — ловим падения в _process у всех сразу.
	for i in 120:
		await process_frame
	_check(true, "120 кадров без падений")

	host.queue_free()

# Часы обязаны не только замедлить летящее, но и остановить поток: иначе
# оставшиеся колонки текущего паттерна вылетят с прежним темпом и налезут на
# уже замедленные предметы (см. spawner.apply_slow_mo).
func _test_slow_mo() -> void:
	var host := Node2D.new()
	get_root().add_child(host)
	var spawner := Node2D.new()
	spawner.set_script(SPAWNER)
	host.add_child(spawner)
	await process_frame

	spawner.set("_frozen", false)
	spawner.set_process(true)

	# Живой предмет, чтобы проверить, что ему сбавили скорость.
	var item := Area2D.new()   # effect_item.gd наследует Area2D — иначе _ready падает
	item.set_script(EFFECT_ITEM)
	item.set("kind", "hourglass")
	item.set("speed", 250.0)
	spawner.add_child(item)
	await process_frame

	spawner.call("apply_slow_mo", 0.45, 0.4)
	await process_frame
	_check(is_equal_approx(float(spawner.get("world_speed_mult")), 0.45), "мир замедлен")
	_check(bool(spawner.get("_frozen")), "поток предметов остановлен на время эффекта")
	_check(absf(float(item.get("speed")) - 112.5) < 0.5,
		"летящему предмету сбавили скорость: %.1f" % float(item.get("speed")))

	# Ждём конца эффекта.
	var t := 0.0
	while t < 0.9:
		await process_frame
		t += 1.0 / 60.0
	_check(is_equal_approx(float(spawner.get("world_speed_mult")), 1.0), "мир вернулся к норме")
	_check(not bool(spawner.get("_frozen")), "поток предметов возобновлён")
	if is_instance_valid(item):
		_check(absf(float(item.get("speed")) - 250.0) < 0.5,
			"скорость предмета восстановлена: %.1f" % float(item.get("speed")))

	host.queue_free()

const HAZARD := preload("res://scripts/hazard_item.gd")

# Семь предметов, ради которых резисты 4–10 уровней перестали быть пустыми
# обещаниями. Проверяем, что каждый собирается, попадает в СВОЮ группу (иначе
# резист скина его не узнает) и что коп действительно роняет наручники.
func _test_hazards() -> void:
	var host := Node2D.new()
	get_root().add_child(host)
	var spawner := Node2D.new()
	spawner.set_script(SPAWNER)
	host.add_child(spawner)
	await process_frame

	# Сейфа в списке нет: у него свой скрипт и своя проверка — он давно не
	# «строка в таблице угроз».
	var kinds := ["cocktail", "cop", "poison", "bird", "helm", "shaman"]
	var made : Array = []
	for k in kinds:
		var n := Area2D.new()
		n.set_script(HAZARD)
		n.set("kind", k)
		n.set("speed", 250.0)
		# Правее края: у копа есть окно «не зовём подмогу за экраном», а быстрая
		# птица за пару секунд успевает улететь и освободиться.
		n.position = Vector2(1400.0, 200.0)
		spawner.add_child(n)
		made.append(n)
	await process_frame

	for i in kinds.size():
		var n : Area2D = made[i]
		var own := n.is_in_group(kinds[i])
		# Коктейль замедляет, остальные бьют — группы разные.
		var cls := n.is_in_group("slowing") if kinds[i] == "cocktail" else n.is_in_group("obstacle")
		_check(own and cls, "«%s» в своей группе и в правильном классе" % kinds[i])

	# Побочные эффекты приходят метаданными. Ищем ПО ИМЕНИ, а не по номеру в
	# списке: номера жили тут раньше и разъехались на первой же правке списка —
	# «яд травит» падало на исправном яде, потому что из списка уехал сейф.
	var by_kind : Dictionary = {}
	for i in kinds.size():
		by_kind[kinds[i]] = made[i]
	_check(by_kind["cocktail"].has_meta("slow_duration"), "коктейль замедляет")
	_check(by_kind["poison"].has_meta("slow_duration"), "яд травит")
	_check(by_kind["shaman"].has_meta("invert_duration"), "шаман разворачивает управление")

	# Птица идёт синусоидой — проверяем ДО долгого ожидания, она улетает быстрее
	# всех остальных и успевает освободиться.
	var bird : Area2D = by_kind["bird"]
	var by := float(bird.position.y)
	var t0 := 0.0
	while t0 < 0.5:
		await process_frame
		t0 += 1.0 / 60.0
	_check(is_instance_valid(bird) and absf(float(bird.position.y) - by) > 1.0,
		"птица летит по синусоиде")

	# Коп зовёт подмогу: через период на поле появляются наручники.
	var before := 0
	for c in spawner.get_children():
		if c.is_in_group("handcuffs"):
			before += 1
	var t := 0.0
	while t < 3.2:
		await process_frame
		t += 1.0 / 60.0
	var after := 0
	for c in spawner.get_children():
		if c.is_in_group("handcuffs"):
			after += 1
	_check(after > before, "коп вызвал подмогу: наручников %d → %d" % [before, after])

	host.queue_free()

func _test_spans() -> void:
	# Главная гарантия: после того как спавнер выдал размеры, ни одна пара
	# предметов не пересекается по кругам.
	var host := Node2D.new()
	get_root().add_child(host)
	var spawner := Node2D.new()
	spawner.set_script(SPAWNER)
	host.add_child(spawner)

	var vp_h := 430.0
	var lanes : Array = []
	for i in 5:
		lanes.append(vp_h / 5.0 * (i + 0.5))

	var speed := 250.0
	var placed : Array = []          # [y, r, t]
	var t : float = 0.0
	var overlaps : int = 0

	# Инварианты, из которых выведен PATTERN_MULT_MAX (см. spawner.gd).
	var col_spacing : float = spawner.get("COL_SPACING")
	var pat_max     : float = spawner.get("PATTERN_MULT_MAX")
	var lane_h      : float = vp_h / 5.0
	_check(2.0 * ItemSizing.BASE_R * pat_max < col_spacing,
		"два подряд в лейне влезают: %.1f < %.1f" % [2.0 * ItemSizing.BASE_R * pat_max, col_spacing])
	_check(ItemSizing.BASE_R * (1.0 + pat_max) < lane_h,
		"два соседних лейна не пересекаются: %.1f < %.1f" % [ItemSizing.BASE_R * (1.0 + pat_max), lane_h])

	# Имитируем поток: то плотный ряд паттерна (одновременно), то одиночка.
	for step in 600:
		var solo := randf() < 0.45
		# Спавнер после гиганта придерживает следующую единицу, пока тот не
		# уедет на свой диаметр (_await_big_clear). Здесь это тот же сдвиг
		# времени — без него тест проверял бы поведение, которого в игре нет.
		var clear_t : float = float(spawner.get("_big_clear_t"))
		if clear_t > t:
			t = clear_t
			spawner.set("_big_clear_t", -1.0)
		spawner.set("_elapsed", t)
		if solo:
			var y : float = lanes[randi() % 5]
			var node := Node2D.new()
			spawner.call("_size_hazard", node, y, speed, true)
			placed.append([y, ItemSizing.radius_for(node.scale.x if node.scale.x > 0.0 else 1.0), t])
			node.queue_free()
		else:
			for lane in [0, 1, 3, 4]:
				var y : float = lanes[lane]
				var node := Node2D.new()
				spawner.call("_size_hazard", node, y, speed, false)
				placed.append([y, ItemSizing.radius_for(node.scale.x if node.scale.x > 0.0 else 1.0), t])
				node.queue_free()
		t += randf_range(col_spacing / speed, 0.9)

	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a : Array = placed[i]
			var b : Array = placed[j]
			var dy : float = absf(float(a[0]) - float(b[0]))
			var dx : float = speed * absf(float(a[2]) - float(b[2]))
			var sum_r : float = float(a[1]) + float(b[1])
			# Пересечение только если оба расстояния меньше суммы радиусов.
			if dy < sum_r and dx < sum_r:
				overlaps += 1
				if overlaps <= 6:
					print("    наложение: rA=%.1f rB=%.1f dy=%.1f dx=%.1f (tA=%.2f tB=%.2f)"
						% [a[1], b[1], dy, dx, a[2], b[2]])

	_check(overlaps == 0, "наложений среди %d предметов: %d" % [placed.size(), overlaps])
	host.queue_free()

# ── ПИВО МУТИТ ЭКРАН ─────────────────────────────────────────────────────────
# У пива было два признака, и оба на самом герое: фиолетовый оттенок и качание
# головы. Размером с ладонь, среди летящих предметов их не видно — на слух
# эффект есть, на глаз его нет. Расфокус берёт весь кадр.
#
# Проверяется ДВЕ вещи, и вторая важнее первой:
#   1. от пива экран мутнеет;
#   2. ОТ БАНАНА — НЕТ. Банан роняет так же, но он не про опьянение, и общий
#      таймер замедления сам по себе не должен ничего мутить. Забыть про это
#      легко: код замедления у них один.
func _test_beer_blur() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var n : Node2D = game.get_node_or_null("Normaldo")
	get_root().get_tree().paused = false

	# Банан — сначала: он обязан НЕ поднимать слой вовсе.
	n.call("apply_slow", 3.0, "banana")
	await _tick(0.2)
	var after_banana : Node = game.get_node_or_null("WorldBlur")
	_check(after_banana == null,
		"от банана слой расфокуса даже не собирается")

	n.set("_slow_remaining", 0.0)
	await _tick(0.1)
	n.call("apply_slow", 3.0, "beer")
	await _tick(0.2)
	var layer : Node = game.get_node_or_null("WorldBlur")
	_check(layer != null and bool(layer.call("is_blurred")),
		"а от пива экран мутнеет: %.2f" % (float(layer.call("amount")) if layer != null else -1.0))

	# И ОТПУСКАЕТ. Эффект, который включается и не выключается, — это не эффект,
	# а сломанный кадр до конца забега.
	n.set("_slow_remaining", 0.0)
	await _tick(0.3)
	_check(layer != null and not bool(layer.call("is_blurred")),
		"и отпускает вместе с замедлением: %.2f" % (float(layer.call("amount")) if layer != null else -1.0))

	game.queue_free()
	await process_frame

	# ── А ТЕПЕРЬ НАСТОЯЩАЯ КРУЖКА ────────────────────────────────────────────
	# Всё выше проверяло связку начиная с `apply_slow`. Но метку кладёт САМ
	# ПРЕДМЕТ, а читает её ветка подбора, и порваться цепочка может именно там:
	# переименовали звук — метка стала «banana», и расфокус тихо исчез, пока
	# каждая отдельная проверка остаётся зелёной.
	var game2 : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game2)
	await process_frame
	var n2 : Node2D = game2.get_node_or_null("Normaldo")
	var sp2 : Node = game2.get_node_or_null("Spawner")
	get_root().get_tree().paused = false
	sp2.call("clear_items")
	sp2.set_process(false)
	n2.set("_dev_immortal", true)

	var beer : Node2D = load("res://scenes/beer.tscn").instantiate()
	beer.set("speed", 0.0)
	sp2.add_child(beer)
	await process_frame
	beer.position = n2.position
	await _tick(0.4)

	var layer2 : Node = game2.get_node_or_null("WorldBlur")
	_check(layer2 != null and bool(layer2.call("is_blurred")),
		"и подобранная В ЗАБЕГЕ кружка мутит экран так же")

	game2.queue_free()
	await process_frame
