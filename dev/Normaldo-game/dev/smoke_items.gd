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

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# Ящик — это СТАВКА НА ПОЛЕ, а не кошелёк: он обязан уметь выплюнуть гадость.
# Жетон автомата из пула убран — валюта не создаёт на экране никакой ситуации,
# её просто подбирают; освободившаяся доля ушла замедляющим.
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

	var kinds := ["safe", "cocktail", "cop", "poison", "bird", "helm", "shaman"]
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

	# Побочные эффекты приходят метаданными.
	_check(made[1].has_meta("slow_duration"), "коктейль замедляет")
	_check(made[3].has_meta("slow_duration"), "яд травит")
	_check(made[6].has_meta("invert_duration"), "шаман разворачивает управление")
	_check(int(made[0].get("damage")) == 2, "сейф бьёт на 2")

	# Птица идёт синусоидой — проверяем ДО долгого ожидания, она улетает быстрее
	# всех остальных и успевает освободиться.
	var by := float(made[4].position.y)
	var t0 := 0.0
	while t0 < 0.5:
		await process_frame
		t0 += 1.0 / 60.0
	_check(is_instance_valid(made[4]) and absf(float(made[4].position.y) - by) > 1.0,
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
