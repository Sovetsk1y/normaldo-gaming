extends SceneTree

# Headless-проверка бомжа с бочкой.
#   godot --headless --path . --script res://dev/smoke_bum_barrel.gd
#
# Смысл этого вида в ПОДГОТОВКЕ: сначала он неотличим от обычного предмета
# потока, потом вдруг тормозит, и только потом появляется угроза. Игрок успевает
# прочитать «сейчас оттуда вылетит». Если собака вылетает мгновенно или не
# вылетает вовсе — вид ничем не отличается от обычного предмета.
#
# См. /Концепция/Паттерны препятствий.md

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 27

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
	var n  : Node = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	# Вид ВЕРНУЛСЯ в забег: его убирали, пока хореография не читалась. Проверяется
	# именно выпадение, а не наличие в таблице фаз: вид из таблицы и не
	# вычёркивался, он гасился списком Spawner.SP_DISABLED, и вернуть его забыв
	# этот список — самый естественный способ «починить и не заметить».
	print("── Выпадает в кампании ──")
	var seen_in_campaign := false
	for phase in sp.CAMPAIGN_DIRECTOR:
		for i in 300:
			if String(sp.call("_pick_set_piece", phase["sp"])) == "bum_barrel":
				seen_in_campaign = true
				break
	_check(seen_in_campaign, "в кампании выпадает")

	print("── Дев-кнопка ──")
	# Кнопка в ряду забега уже была, но найти её было нечем: шесть тёмных
	# квадратов с иконками 36×36, и какая из них «бомж с бочкой», а какая «волна
	# бомжей», решалось перебором. Проверяется поэтому не только то, что вызов
	# поднимает сет-пис, но и то, что кнопка ПОДПИСАНА.
	var hud : Node = game.get_node_or_null("HUD")
	hud.call("_build_dev_bum_barrel_btn")
	await process_frame
	var caps : Array = []
	_labels(hud, caps)
	_check(caps.has("БОЧКА"), "кнопка подписана и её видно в ряду: %s" % [caps])

	sp.call("dev_send_bum_barrel")
	await process_frame
	_check(_find_barrel(sp) != null, "и по нажатию сет-пис поднимается")
	sp.call("clear_items")
	sp.set_process(false)
	await _wait(0.2)

	print("── Приезд, бочка, собака ──")
	var vp : Vector2 = get_root().get_visible_rect().size
	# Пять линий, как в настоящем забеге: сет-пис выбирает лейн случайно, и
	# массив из одного элемента ему не подходит.
	var lanes : Array = []
	for i in 5:
		lanes.append(vp.y * (float(i) + 0.5) / 5.0)
	(n as Node2D).position = Vector2(220.0, lanes[2])
	# Нормальдо бессмертен НАМЕРЕННО: тест меряет хореографию, а не выживание. У
	# бомжа и бочки теперь есть хитбоксы, лейн сет-пис выбирает случайно, и раз в
	# несколько прогонов он приходил ровно на линию Нормальдо — тот умирал, экран
	# смерти вставал поверх, и тест мерил уже не сцену.
	n.set("_dev_immortal", true)
	sp.call("_setpiece_bum_barrel", 250.0, lanes, vp.x)
	await process_frame

	var node : Node2D = _find_barrel(sp)
	_check(node != null, "бомж с бочкой появился")
	if node == null:
		_finish()
		return
	_check(node.position.x > vp.x, "стартует ИЗ-ЗА правого края: x=%.0f" % node.position.x)

	var bum : Sprite2D = node.get("_bum")
	var bar : Sprite2D = node.get("_barrel")
	_check(bum != null and bar != null, "в сцене есть и бомж, и бочка")
	if bum == null or bar == null:
		_finish()
		return

	# РАЗМЕР. Бомж обязан быть ровно таким же, как рядовой бомж из потока: от
	# обычного предмета он отличается не размером, а тем, что умеет отыграть сцену
	# и кинуть пса. Сравнивается с НАСТОЯЩИМ бомжом, а не с числом в комментарии —
	# поменяется размер потока, поменяется и здесь.
	var ref : Node2D = load("res://scenes/homeless.tscn").instantiate()
	sp.add_child(ref)
	await process_frame
	var ref_px : float = _drawn_h(ref.get_node("Sprite2D"))
	var bum_px : float = _drawn_h(bum)
	_check(absf(bum_px - ref_px) < 6.0,
		"бомж такой же, как рядовой из потока: %.0f против %.0f" % [bum_px, ref_px])
	ref.queue_free()

	# Бочка — размером с обычную бочку из потока, то есть НЕ НИЖЕ бомжа. Отзыв был
	# буквально «бочка осталась такой же маленькой»: она нормировалась по длинной
	# стороне рисунка, а у закрытого кадра длинная — это высота, и «52 по длинной»
	# означало 52 в высоту при 63 у мусорки из потока.
	var body_closed : float = _body_h(bar)
	_check(body_closed >= bum_px,
		"бочка не ниже бомжа: %.0f против %.0f" % [body_closed, bum_px])

	# И стоит она на ТОЙ ЖЕ ЗЕМЛЕ, что и бомж. Отзыв был «низ бочки выше низа
	# бомжа»: вертикаль задавалась числом, не связанным с ростом бомжа, и двое на
	# одной линии стояли на разных полах. Опора спрайта бочки — нижний угол
	# рисунка, поэтому её низ это ровно её `position.y`.
	var floor_y : float = bum.position.y + bum_px * 0.5
	_check(absf(bar.position.y - floor_y) < 2.0,
		"и стоит на одной земле с бомжом: низ %.0f против %.0f"
			% [bar.position.y, floor_y])

	# ХИТБОКСЫ. Бомж и бочка бьют, как любой предмет: без них сквозь сет-пис можно
	# было пролететь насквозь без урона, и угроза превращалась в декорацию,
	# которую достаточно переждать.
	var boxes : Array = []
	for c in node.get_children():
		if c is Area2D and c.is_in_group("obstacle"):
			boxes.append(c)
	_check(boxes.size() == 2, "у бомжа и у бочки есть хитбоксы: %d" % boxes.size())
	var dmg_ok := true
	for b in boxes:
		if int(b.get("damage")) < 1:
			dmg_ok = false
	_check(dmg_ok, "и оба бьют на урон")

	# Сначала — обычный предмет потока: летит с той же скоростью, ничего не
	# отыгрывает. Именно на фоне этого читается последующее торможение.
	var x0 : float = node.position.x
	await _wait(0.25)
	var x1 : float = node.position.x
	var v  : float = (x0 - x1) / 0.25
	_check(String(node.get("_phase")) == "enter", "пока не показался целиком — просто летит")
	_check(absf(v - 250.0) < 45.0, "и летит со скоростью потока: %.0f против 250" % v)
	_check(bar.texture == load("res://assets/items/barrel_open1.png"),
		"бочку несёт СТОЯЧЕЙ, крышка закрыта")

	# Собаки в первые полторы секунды быть не должно — идёт подготовка.
	await _wait(1.0)
	_check(_dogs(sp) == 0, "пока подъезжает и ставит — собаки нет")
	var x_mid : float = node.position.x if is_instance_valid(node) else -1.0
	_check(x_mid < vp.x, "успел затормозить в кадре: x=%.0f" % x_mid)

	# ТЫЧОК. Бомж коротко подаётся вперёд и возвращается — от этого бочка и
	# валится. Без него она заваливалась сама собой, и связи «уронил её ОН» на
	# экране не было: бомж просто стоял рядом с падающей бочкой. Проверяется
	# именно ВОЗВРАТ: подавшийся и не вернувшийся бомж — это не тычок, а сдвиг.
	var bx_home : float = -1e9
	var bx_min  : float =  1e9
	var t_s := 0.0
	while t_s < 1.6:
		await process_frame
		t_s += 1.0 / 60.0
		var bx : float = bum.position.x
		bx_home = maxf(bx_home, bx)
		bx_min  = minf(bx_min, bx)
	_check(bx_home - bx_min > 8.0,
		"бомж толкнул бочку: подался вперёд на %.0f px" % (bx_home - bx_min))
	_check(absf(bum.position.x - bx_home) < 3.0,
		"и вернулся назад: %.0f против %.0f" % [bum.position.x, bx_home])

	# А дальше — открытая бочка и собака из неё.
	# У бочки два кадра: закрыта и открыта. Третьим когда-то был `trash_bin.png` —
	# обычная мусорка из потока, нарисованная С КРАСНОЙ ОБВОДКОЙ, то есть с меткой
	# «этот бьёт». В сет-писе она врала: бьёт собака, а не бочка.
	_check(bar.texture == load("res://assets/items/barrel_open2.png"),
		"к выстрелу бочка ОТКРЫТА — вторым кадром, а не мусоркой из потока")
	# И лежит НА БОКУ: только лёжа у неё горло смотрит влево, туда, куда полетит
	# собака. Упавшая стоймя бочка читается как «поставил», а не «уронил».
	_check(absf(bar.rotation + PI * 0.5) < 0.1,
		"и лежит на боку: поворот %.2f при ожидаемом -1.57" % bar.rotation)
	_check(absf(_body_h(bar) - body_closed) < 2.0,
		"тело бочки на смене кадра не изменилось: %.0f и %.0f"
			% [body_closed, _body_h(bar)])
	# Опрокинулась она ЧЕРЕЗ РЕБРО, а не провалилась: низ остался на той же земле.
	# Раньше вместе с поворотом бочка проседала на треть своего роста и уходила
	# ниже пола, на котором стоял бомж.
	_check(absf(bar.position.y - floor_y) < 2.0,
		"и осталась на той же земле: низ %.0f против %.0f"
			% [bar.position.y, floor_y])
	# Хитбокс бочки завалился ВМЕСТЕ с ней: зона удара обязана ехать за рисунком,
	# иначе бьёт пустое место, а нарисованное не бьёт.
	var bar_box : Area2D = null
	for c in node.get_children():
		if c is Area2D and c.is_in_group("obstacle") \
				and absf(c.rotation) > 0.5:
			bar_box = c
	_check(bar_box != null, "и хитбокс лёг вместе с бочкой")
	if bar_box != null:
		_check(bar_box.global_position.distance_to(bar.global_position) < 90.0,
			"и стоит на ней, а не рядом: %.0f px"
				% bar_box.global_position.distance_to(bar.global_position))
	var dogs : Array = _dog_nodes(sp)
	_check(dogs.size() >= 1, "собака вылетела: %d" % dogs.size())
	if not dogs.is_empty():
		var d : Node2D = dogs[0]
		# По СВОЕЙ линии — той, что бомж занял и держал всю подготовку, — а не по
		# линии Нормальдо. Наведённая на голову собака обесценила бы подготовку:
		# сходить с линии было бы незачем, всё равно прилетит куда встал.
		var lane : float = float(node.get("lane_y"))
		_check(absf(d.position.y - lane) < 30.0,
			"и летит по СВОЕЙ линии: %.0f против %.0f" % [d.position.y, lane])
		# И быстрее потока: это выстрел, а не ещё один предмет.
		_check(float(d.get("speed")) > 250.0 * 1.4,
			"и заметно быстрее потока: %.0f против 250" % float(d.get("speed")))

	# Дальше он ЕДЕТ С ПОТОКОМ, а не улетает рывком за край. Отличие сет-писа от
	# обычного предмета — только в том, что по дороге он умеет отыграть сцену.
	var gap0 : float = bum.global_position.x - bar.global_position.x
	var sx0  : float = node.position.x
	await _wait(0.5)
	if is_instance_valid(node):
		var v_out : float = (sx0 - node.position.x) / 0.5
		_check(absf(v_out - 250.0) < 60.0,
			"дальше едет со скоростью потока: %.0f против 250" % v_out)
		var gap1 : float = bum.global_position.x - bar.global_position.x
		_check(absf(gap1 - gap0) < 4.0,
			"и везёт бочку с собой, не убегая от неё: зазор %.0f → %.0f" % [gap0, gap1])
	_finish()

func _labels(node: Node, out: Array) -> void:
	if node is Label and String((node as Label).text) != "":
		out.append(String((node as Label).text))
	for c in node.get_children():
		_labels(c, out)

# Высота ТЕЛА бочки — рисунка ЗАКРЫТОГО кадра, без сорванной крышки. Именно оно
# обязано совпадать между кадрами; общий контент у них разный по построению.
func _body_h(spr: Sprite2D) -> float:
	var r : Rect2i = ItemSizing.content_rect(load("res://assets/items/barrel_open1.png"))
	return float(r.size.y) * absf(spr.scale.y)

# Высота НАРИСОВАННОГО на экране, а не рамки кадра.
func _drawn_h(spr: Sprite2D) -> float:
	var r : Rect2i = ItemSizing.content_rect(spr.texture)
	return float(r.size.y) * absf(spr.scale.y)

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

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0

func _find_barrel(sp: Node) -> Node2D:
	for c in sp.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("bum_barrel.gd"):
			return c
	return null

func _dogs(sp: Node) -> int:
	return _dog_nodes(sp).size()

func _dog_nodes(sp: Node) -> Array:
	var out : Array = []
	for c in sp.get_children():
		if c.scene_file_path != "" and c.scene_file_path.ends_with("dog.tscn"):
			out.append(c)
	return out
