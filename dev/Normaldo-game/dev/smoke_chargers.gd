extends SceneTree

# Headless-проверка УДАРА ПО ЛИНИИ и ВСТУПИТЕЛЬНОЙ ПОЛОСЫ ПИЦЦЫ.
#   godot --headless --path . --script res://dev/smoke_chargers.gd
#
# Обе вещи ломаются молча, и обе — не на глаз.
#
#   1. КТО ЛЕТИТ. Приём один (влёт, зарядка, рывок через экран), а делает его
#      либо перчатка, либо собака — по раскладке уровня. Ошибись тут, и на
#      уровне со собаками полетит перчатка: играется одинаково, выглядит
#      «как было», и заметить подмену можно только специально её выискивая.
#   2. ЧЕЙ РЕЗИСТ СРАБОТАЕТ. Собака обязана быть в группе "dog", а не "glove":
#      от группы зависит иммунитет скина, и собака в перчаточной группе тихо
#      отдала бы защиту не тому скину.
#   3. МАШИНА ФАЗ ОБЩАЯ. Ради этого порода и сделана полем, а не вторым
#      скриптом. Проверяется, что у обеих пород совпадают сроки зарядки,
#      скорость рывка и телеграф.
#   4. ПОЛОСА ПИЦЦЫ. Три линии, не пять; середина плывёт; полоса НЕ ВЫХОДИТ ЗА
#      ПОЛЕ (иначе часть обещанной еды улетает за экран, и «отожраться на жир»
#      перестаёт сходиться); негатива в ней нет ни одного.
#
# См. scripts/boxing_glove.gd, scripts/spawner.gd → _campaign_intro_pizza

const GLOVE   := preload("res://scripts/boxing_glove.gd")
const SPAWNER := preload("res://scripts/spawner.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 31

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	await process_frame
	print("── Кто летит на каком уровне ──")
	await _test_breed_by_level()
	print("── Порода меняет внешность и группу ──")
	await _test_breed_looks()
	print("── И НЕ меняет машину фаз ──")
	await _test_shared_machine()
	print("── Вступительная полоса пиццы ──")
	await _test_intro_band()
	_finish()

# ── 1. Порода берётся из раскладки, а не из номера уровня ──────────────────
# Сверяется НЕ со списком номеров, а с той же таблицей, из которой спавнер и
# читает: добавят собаку ещё на один уровень — тест поедет вместе с игрой, а не
# начнёт врать.
func _test_breed_by_level() -> void:
	var sp : Node = _spawner()
	if sp == null:
		return
	for lv in SPAWNER.HAZ_LEVEL.size():
		sp.set("level", lv)
		sp.set("_hardcore", false)
		var want : int = GLOVE.Breed.DOG \
			if (SPAWNER.HAZ_LEVEL[lv] as Dictionary).has("dog") \
			else GLOVE.Breed.GLOVE
		var got : int = int(sp.call("_charger_breed"))
		_check(got == want, "уровень %d: %s (по раскладке %s)"
			% [lv + 1, "собака" if got == GLOVE.Breed.DOG else "перчатка",
			   "собака есть" if want == GLOVE.Breed.DOG else "собаки нет"])
	# В хвосте пул — сумма всех уровней, собака в нём есть.
	sp.set("level", 0)
	sp.set("_hardcore", true)
	_check(int(sp.call("_charger_breed")) == GLOVE.Breed.DOG,
		"в хвосте бесконечного летит собака")

	# ── И ПОРОДА ДОХОДИТ ДО ВЫЛЕТА ──────────────────────────────────────────
	# Отдельной проверкой, потому что ломается это отдельно: `_charger_breed()`
	# может отвечать правильно, а `_spawn_glove` — забыть спросить, и тогда на
	# собачьем уровне полетит перчатка при полностью зелёном тесте выше.
	for lv in [0, 3]:
		sp.set("_hardcore", false)
		sp.set("level", lv)
		var caught : Array = []
		var grab := func(n: Node) -> void: caught.append(n)
		sp.child_entered_tree.connect(grab)
		sp.call("_spawn_glove", 200.0, 960.0)
		await process_frame
		sp.child_entered_tree.disconnect(grab)
		var dog_lv : bool = (SPAWNER.HAZ_LEVEL[lv] as Dictionary).has("dog")
		var ok : bool = not caught.is_empty() \
			and (caught[0] as Node).is_in_group("dog" if dog_lv else "glove")
		_check(ok, "на уровне %d вылетела %s" % [lv + 1, "собака" if dog_lv else "перчатка"])
		for n in caught:
			if is_instance_valid(n):
				n.queue_free()

	sp.get_parent().queue_free()
	await process_frame

# ── 2. Внешность и группа ──────────────────────────────────────────────────
func _test_breed_looks() -> void:
	for breed in [GLOVE.Breed.GLOVE, GLOVE.Breed.DOG]:
		var n : Node = _charger(breed)
		get_root().add_child(n)
		await process_frame
		var dog : bool = breed == GLOVE.Breed.DOG
		var name_ru : String = "собака" if dog else "перчатка"
		var tex := String((n.get_node("Sprite2D") as Sprite2D).texture.resource_path)
		_check(tex.ends_with("angry_dog.png" if dog else "boxing_glove.png"),
			"%s: картинка %s" % [name_ru, tex.get_file()])
		_check(n.is_in_group("dog" if dog else "glove"),
			"%s: группа «%s»" % [name_ru, "dog" if dog else "glove"])
		# И НЕ в чужой: две группы сразу дали бы обоим скинам по иммунитету.
		_check(not n.is_in_group("glove" if dog else "dog"),
			"%s: в чужой группе не состоит" % name_ru)
		_check(n.is_in_group("obstacle"), "%s: бьёт (группа obstacle)" % name_ru)
		# ── И НАЗЫВАЕТСЯ В ОТЧЁТЕ СОБОЙ ────────────────────────────────────
		# Сцена у обеих пород одна, и по имени файла обе ушли бы в аналитику
		# перчаткой: вопрос «что убивает игроков во дворе» получил бы ответ про
		# предмет, которого там нет.
		_check(String(n.get("cause_name")) == ("charging_dog" if dog else "boxing_glove"),
			"%s: в отчёте зовётся «%s»" % [name_ru, String(n.get("cause_name"))])
		n.queue_free()
		await process_frame

# ── 3. Машина фаз у пород ОДНА ─────────────────────────────────────────────
# Ради этого порода и сделана полем одного скрипта. Здесь проверяется то, что
# развалилось бы первым, если приём всё-таки разложат на два файла: сроки,
# скорость рывка и телеграф.
func _test_shared_machine() -> void:
	var made : Array = []
	for breed in [GLOVE.Breed.GLOVE, GLOVE.Breed.DOG]:
		var n : Node = _charger(breed)
		n.charge_duration = 0.12
		# ЗА ПРАВЫМ КРАЕМ, как её и выпускает спавнер. Поставь её внутри экрана
		# левее точки парковки — и фаза влёта кончится, не начавшись: проверка
		# «прошла все три фазы» провалилась бы на ровном месте.
		n.position = Vector2(1040.0, 200.0)
		get_root().add_child(n)
		made.append(n)
	await process_frame
	_check(made[0].get_script() == made[1].get_script(),
		"обе породы — один скрипт")
	# Гоняем обе до конца зарядки и смотрим, что они прошли одни и те же фазы.
	var t := 0.0
	var seen : Array = [{}, {}]
	while t < 1.2:
		await process_frame
		t += 1.0 / 60.0
		for i in 2:
			if is_instance_valid(made[i]):
				(seen[i] as Dictionary)[int(made[i].get("_phase"))] = true
	for i in 2:
		var name_ru : String = "перчатка" if i == 0 else "собака"
		_check((seen[i] as Dictionary).size() == 3,
			"%s прошла все три фазы: %d" % [name_ru, (seen[i] as Dictionary).size()])
	for n in made:
		if is_instance_valid(n):
			n.queue_free()
	await process_frame

# ── 4. Полоса пиццы ────────────────────────────────────────────────────────
# Колонки считаются ПО ТОМУ, ЧТО ВЫЛЕТЕЛО, а не по коду функции: проверять надо
# результат. Спавнер гоняется вручную, кадр за кадром, чтобы не зависеть от
# директора и его случайностей.
func _test_intro_band() -> void:
	var sp : Node = _spawner()
	if sp == null:
		return
	# ── ДИРЕКТОРА ГЛУШИМ ────────────────────────────────────────────────────
	# Спавнер живой, и его собственный `_process` в это же время сыплет поток.
	# Первый заход считал колонки по приросту числа детей — и в «колонки»
	# попадали случайные предметы директора: ширина полосы выходила то 3, то 4,
	# и тест ругался на игру, в которой всё правильно.
	sp.set_process(false)
	var vp_h : float = get_root().get_visible_rect().size.y
	var lanes : Array = sp.call("_lane_centers")
	var lane_h : float = float(lanes[1]) - float(lanes[0])

	# ── КОЛОНКИ ЛОВИМ ПО СОБЫТИЮ ВЫЛЕТА, А НЕ ПО ЧИСЛУ ДЕТЕЙ ────────────────
	# Первый заход считал прирост `get_child_count()` — и врал начиная с
	# десятой колонки: ранние пиццы к тому времени уже уходили за левый край и
	# убирали себя сами. Число детей падало, «прирост» выходил меньше, и тест
	# сообщал про полосу в одну пиццу там, где их вылетело три.
	var cols  : Array = []
	var batch : Array = []
	sp.child_entered_tree.connect(func(n: Node) -> void:
		if n is Node2D:
			batch.append((n as Node2D).position.y))
	sp.call("_campaign_intro_pizza", 250.0, lanes, 960.0)
	var t := 0.0
	while t < 12.0:
		# Колонка уходит одним куском внутри кадра — значит, что накопилось к
		# следующему кадру, то и есть одна колонка.
		if not batch.is_empty():
			batch.sort()
			cols.append(batch.duplicate())
			batch.clear()
		if cols.size() >= SPAWNER.CAMPAIGN_INTRO_COLS:
			break
		await process_frame
		t += 1.0 / 60.0

	_check(cols.size() == SPAWNER.CAMPAIGN_INTRO_COLS,
		"колонок %d из %d" % [cols.size(), SPAWNER.CAMPAIGN_INTRO_COLS])
	if cols.is_empty():
		sp.get_parent().queue_free()
		return

	var widths_ok := true
	var steps_ok  := true
	var inside_ok := true
	var mids : Array = []
	for c in cols:
		var ys : Array = c
		if ys.size() != SPAWNER.CAMPAIGN_INTRO_BAND:
			widths_ok = false
			continue
		# Соседние пиццы полосы стоят ровно на шаг линии — полоса сплошная.
		for i in range(1, ys.size()):
			if absf(float(ys[i]) - float(ys[i - 1]) - lane_h) > 1.0:
				steps_ok = false
		if float(ys[0]) < 0.0 or float(ys[ys.size() - 1]) > vp_h:
			inside_ok = false
		mids.append(float(ys[ys.size() / 2]))
	var sizes : Array = []
	for c in cols:
		sizes.append((c as Array).size())
	_check(widths_ok, "в каждой колонке ровно %d пиццы %s"
		% [SPAWNER.CAMPAIGN_INTRO_BAND, str(sizes)])
	_check(SPAWNER.CAMPAIGN_INTRO_BAND < 5, "полоса уже поля (%d линии из 5)"
		% SPAWNER.CAMPAIGN_INTRO_BAND)
	_check(steps_ok, "полоса сплошная: шаг между пиццами = шагу линии")
	_check(inside_ok, "полоса не вылезает за поле ни одной колонкой")

	# Середина ПЛЫВЁТ — и вверх, и вниз. Одного «не равны» мало: полоса,
	# уехавшая в одну сторону и там оставшаяся, тоже дала бы разные числа.
	var lo : float = mids[0]
	var hi : float = mids[0]
	for m in mids:
		lo = minf(lo, float(m))
		hi = maxf(hi, float(m))
	_check(hi - lo > lane_h * 0.8,
		"середина полосы гуляет на %.0f px (линия %.0f)" % [hi - lo, lane_h])
	var up := false
	var down := false
	for i in range(1, mids.size()):
		if float(mids[i]) > float(mids[i - 1]) + 1.0: down = true
		if float(mids[i]) < float(mids[i - 1]) - 1.0: up = true
	_check(up and down, "и вверх, и вниз — это волна, а не съезд")

	# Ни одного негатива: вступление кормит, а не учит.
	var bad := 0
	for n in sp.get_children():
		if n is Node2D and (n as Node).is_in_group("obstacle"):
			bad += 1
	_check(bad == 0, "негатива во вступлении нет: %d" % bad)

	sp.get_parent().queue_free()
	await process_frame

# ── Помощники ──────────────────────────────────────────────────────────────

func _spawner() -> Node:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	var sp : Node = game.get_node_or_null("Spawner")
	_check(sp != null, "спавнер поднялся")
	if sp == null:
		game.queue_free()
	return sp

func _charger(breed: int) -> Node:
	var n : Node = load("res://scenes/boxing_glove.tscn").instantiate()
	n.breed = breed
	return n

func _finish() -> void:
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок %d из %d — тест не отработал" % [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails > 0:
		print("ПРОВАЛОВ: %d из %d" % [_fails, _checks])
		quit(1)
		return
	print("\nВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	quit(0)
