extends SceneTree

# Headless-проверка КАМПАНИИ ИЗ ПЯТИ ЭПИЗОДОВ.
#   godot --headless --path . --script res://dev/smoke_levels.gd
#
# Кампания — это цепочка, и ломается она в стыках. Отдельно взятый эпизод
# работает, отдельно взятый босс работает, а забег всё равно кончается на
# первом же переходе: слово не сбросилось, фаза не поднялась, фон не сменился,
# следующий босс не тот. Каждый такой стык тут и проверяется.
#
# Второе — НАБОРЫ ПРЕДМЕТОВ. Локация локацией её и делает: канализация — это
# банан под ногами и полицейская машина, пляж — лежаки, зонты и костёр.
# Перепутать их местами нельзя, а на глаз это ловится только после долгой игры.
#
# См. /Концепция/Уровни/Кампания — пять эпизодов.md

const SP := preload("res://scripts/spawner.gd")
const BG := preload("res://scripts/background.gd")

# Эпизодов пять — по одному на нарисованный фон. Устроены фоны по-разному:
# первый на плитке, остальные четыре на нарисованных полосах, — но КАМПАНИЯ
# считается эпизодами, а не полосами и не плитками.
#
# ЭТО ЕДИНСТВЕННОЕ МЕСТО, ГДЕ ДЛИНА КАМПАНИИ НАПИСАНА ЧИСЛОМ, и написана она
# тут нарочно: тест обязан на что-то опираться, иначе `lv.size() == lv.size()`
# — тавтология, которая пройдёт при любой длине. Все остальные проверки ниже
# считают от `LEVELS`, а не повторяют пятёрку своими руками; менять длину
# кампании — значит поправить `CAMPAIGN_LEVELS` и эту строку, и больше нигде.
const LEVELS : int = 5

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 53

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Таблица уровней ──")
	_test_table()
	print("── Наборы предметов по уровням ──")
	await _test_pools()
	print("── Слово кончает уровень ──")
	await _test_letters_end_level()
	print("── Переход на следующий уровень ──")
	await _test_advance()
	print("── Фон: свой на каждый уровень ──")
	await _test_background()
	print("── Эпизод против бесконечного ──")
	await _test_chain()
	print("── Хвост бесконечного ──")
	await _test_hardcore()
	_finish()

# ── Таблица ──────────────────────────────────────────────────────────────────

func _test_table() -> void:
	var lv : Array = SP.CAMPAIGN_LEVELS
	_check(lv.size() == LEVELS, "эпизодов пять: %d" % lv.size())
	# Боссы стоят там же, где в старом проекте: нога ниндзя закрывает
	# канализацию, крокодил — реку, хозяин клуба — клуб.
	_check(String(lv[0]["boss"]) == "ninja", "канализацию закрывает Нога Ниндзя")
	_check(String(lv[1]["boss"]) == "croc", "реку — Крокодил")
	_check(String(lv[lv.size() - 1]["boss"]) == "club", "клуб — Хозяин клуба")

	# ВЗЯТЫХ ВЗАЙМЫ боссов ровно столько, сколько эпизодов осталось без своего:
	# нарисовано три боя, эпизодов пять — значит двое доигрывают чужим и помечены
	# `boss_tmp`. Нарисуют своего и забудут снять флаг — тест скажет.
	var tmp := 0
	var drawn : Dictionary = {}
	for i in lv.size():
		drawn[String((lv[i] as Dictionary)["boss"])] = true
		if bool((lv[i] as Dictionary).get("boss_tmp", false)):
			tmp += 1
	_check(tmp == LEVELS - drawn.size(),
		"боссов взаймы столько же, сколько эпизодов без своего: %d" % tmp)
	# Эпизод кончается боем: пустых финалов больше нет. Раньше два эпизода
	# доигрывались просто буквой, потому что боёв было меньше, чем эпизодов.
	var all_bossed := true
	for d in lv:
		if String(d["boss"]).is_empty():
			all_bossed = false
	_check(all_bossed, "каждый эпизод кончается боссом")

	# Планка старта НЕ ПАДАЕТ от эпизода к эпизоду. Не «строго растёт» нарочно:
	# фаз конечное число, и если эпизодов станет больше, соседям на хвосте
	# достанется одна и та же верхняя — выше просто нет.
	var falls : Array = []
	for i in range(1, lv.size()):
		if int(lv[i]["phase"]) < int(lv[i - 1]["phase"]):
			falls.append(i + 1)
	_check(falls.is_empty(), "планка старта не падает по эпизодам: %s" % [falls])
	_check(int(lv[lv.size() - 1]["phase"]) > int(lv[0]["phase"]),
		"и последний начинается труднее первого")
	# А уровни укорачиваются: к финалу темп плотнее.
	var shortens := true
	for i in range(1, lv.size()):
		if float(lv[i]["letter"]) > float(lv[i - 1]["letter"]):
			shortens = false
	_check(shortens, "период между буквами укорачивается")

# ── Наборы предметов ─────────────────────────────────────────────────────────
# У КАЖДОГО УРОВНЯ СВОЙ НАБОР — из этого локация и состоит. Проверяется не
# «набор непустой», а ПРИНАДЛЕЖНОСТЬ в обе стороны: заявленный предмет на своём
# уровне встречается, а на чужом — нет.
#
# Раскладка ниже — копия той, что в `spawner.HAZ_LEVEL`, и это не дублирование
# ради дублирования: таблица в спавнере — веса, а здесь — ЗАМЫСЕЛ. Поменяв вес,
# легко случайно уронить предмет с уровня или подсыпать его на чужой; тест
# ловит ровно это.
#
# См. /Концепция/Уровни/Раскладка по уровням.md
# ── Раскладка ────────────────────────────────────────────────────────────────
# Раньше здесь лежала ВТОРАЯ КОПИЯ раскладки: предмет → номера уровней, набитая
# руками. Она проверяла не игру, а совпадение двух списков, и при каждой правке
# `HAZ_LEVEL` её приходилось править следом — то есть подгонять тест под код,
# что и есть худший вид проверки. Перекройка кампании на пять эпизодов это и
# показала: копия разошлась целиком, и двадцать три строки провалов не значили
# ничего.
#
# Теперь ожидание СТРОИТСЯ ИЗ САМОЙ ТАБЛИЦЫ, а проверяется то, что руками не
# проверить: РЕАЛЬНЫЙ ПОТОК спавнера совпадает с тем, что в таблице написано.
# Опечатка в имени предмета ловится, разъезд копий — невозможен.

# Что летит ВЕЗДЕ и потому в набор уровня не входит: перчатка — ритм-событие,
# гриб — восемь секунд поломанной игры, и оба одинаковы на всех локациях.
const EVERYWHERE : Array = ["glove", "mushroom"]

func _test_pools() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	var seen : Array = []
	for lvl in LEVELS:
		sp.set("level", lvl)
		var kinds : Dictionary = {}
		for _i in 6000:
			kinds[String(sp.call("_pick_level_hazard"))] = true
		seen.append(kinds)

	var missing : Array = []
	var stray   : Array = []
	for lvl in LEVELS:
		var table : Dictionary = SP.HAZ_LEVEL[lvl]
		var here  : Dictionary = seen[lvl]
		for item in table:
			if not here.has(String(item)):
				missing.append("%s нет на %d" % [String(item), lvl + 1])
		for item in here:
			var it := String(item)
			if not table.has(it) and not (it in EVERYWHERE):
				stray.append("%s залетел на %d" % [it, lvl + 1])
	_check(missing.is_empty(), "весь набор уровня долетает: %s" % [missing])
	var poison_back : Array = []
	for lvl in LEVELS:
		if (seen[lvl] as Dictionary).has("poison"):
			poison_back.append(lvl + 1)
	_check(poison_back.is_empty(), "яда в потоке нет ни на одном уровне: %s" % [poison_back])
	_check(stray.is_empty(), "и не залетает на чужие: %s" % [stray])

	var all_ok := true
	for k in EVERYWHERE:
		for lvl in LEVELS:
			if not (seen[lvl] as Dictionary).has(k):
				all_ok = false
	_check(all_ok, "боксёрская перчатка летит на всех уровнях")

	# НИНДЗЯ НЕ ЛЕТИТ НА ПЕРВОМ. Там игрок его ещё не встречал: ниндзя ждёт
	# боссом в конце первого эпизода, и предмет, который объясняет себя этим
	# боем, до боя читается как непонятная фигура, зачем-то замирающая посреди
	# экрана.
	#
	# Проверяем ИМЕННО ЭТО, а не «есть на всех, кроме первого». Прежняя формула
	# требовала ниндзю на каждом эпизоде подряд, а это уже не про замысел, а про
	# текущие веса: захотим дать эпизоду передышку от знакомого предмета — тест
	# упадёт на замысле, которого у него нет.
	_check(not (seen[0] as Dictionary).has("ninja"), "на первом эпизоде ниндзи нет")
	var ninja_on := 0
	for lvl in range(1, LEVELS):
		if (seen[lvl] as Dictionary).has("ninja"):
			ninja_on += 1
	_check(ninja_on >= LEVELS / 2, "а дальше он в потоке: на %d эпизодах" % ninja_on)

	# И наборы РАЗНЫЕ: два уровня, совпавшие по составу, — это один уровень с
	# двумя задниками.
	var same : Array = []
	for a in range(LEVELS):
		for b in range(a + 1, LEVELS):
			var ka : Array = (seen[a] as Dictionary).keys()
			ka.sort()
			var kb : Array = (seen[b] as Dictionary).keys()
			kb.sort()
			if ka == kb:
				same.append("%d и %d" % [a + 1, b + 1])
	_check(same.is_empty(), "наборы уровней не повторяются: %s" % [same])
	e["game"].queue_free()
	await process_frame

# ── Слово кончает уровень ────────────────────────────────────────────────────

func _test_letters_end_level() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	# Цепочка целиком — это БЕСКОНЕЧНЫЙ режим: переходы между уровнями бывают
	# только в нём (эпизод — один уровень, и после него забег кончается).
	sp.set("endless_chain", true)
	sp.set_process(true)
	var got : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void:
		got.append([boss, nxt]))

	# Доводим слово до последней буквы напрямую: гонять восемь периодов по
	# четырнадцать секунд значило бы мерить секундомер, а не переход.
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	sp.call("_run_letter")
	await _tick(8.0)
	_check(got.size() == 1, "последняя буква кончает уровень: %d" % got.size())
	if not got.is_empty():
		_check(String(got[0][0]) == "ninja" and int(got[0][1]) == 1,
			"и говорит, кого звать и куда дальше: %s" % [got[0]])
	else:
		_check(false, "—")
	_check(not sp.is_processing(), "поток на время босса остановлен")
	e["game"].queue_free()
	await process_frame

# ── Переход ──────────────────────────────────────────────────────────────────

func _test_advance() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	sp.set("endless_chain", true)
	sp.set("_letter_idx", 8)
	sp.set("level", 0)
	sp.call("advance_level")
	await process_frame
	_check(int(sp.get("level")) == 1, "уровень стал вторым")
	_check(int(sp.call("letters_done")) == 0, "слово начинается ЗАНОВО")
	_check(int(sp.get("_phase")) == int(SP.CAMPAIGN_LEVELS[1]["phase"]),
		"фаза встала на планку уровня: %d" % int(sp.get("_phase")))
	_check(sp.is_processing(), "поток снова идёт")
	# И НЕ ЗАМОРОЖЕН. Проверка отдельная от «процесс идёт», потому что ломалось
	# именно это: `_start_level` снимал заморозку, а потом звал `clear_items()`,
	# который ставит её обратно. Процесс при этом возвращался, и снаружи всё
	# выглядело исправным — а поток молчал до первой буквы NORMALDO, то есть
	# четырнадцать секунд пустого экрана после победы над боссом.
	_check(not bool(sp.get("_frozen")), "и не заморожен")
	_check(float(sp.get("_spawn_timer")) <= 0.6,
		"первый предмет придёт скоро: через %.2f с" % float(sp.get("_spawn_timer")))
	_check(String(sp.call("level_name")) == String(SP.CAMPAIGN_LEVELS[1]["name"]),
		"и название сменилось: %s" % sp.call("level_name"))

	# Третий уровень — последний: дальше идти некуда.
	sp.set("level", LEVELS - 1)
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	var got : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void:
		got.append([boss, nxt]))
	sp.call("_run_letter")
	await _tick(8.0)
	_check(not got.is_empty() and int(got[0][1]) == -1,
		"а после третьего следующего уровня нет — дальше хвост: %s" % [got])
	e["game"].queue_free()
	await process_frame

# ── Фон ──────────────────────────────────────────────────────────────────────

func _test_background() -> void:
	var e : Dictionary = await _boot()
	var bg : Node = e["game"].get_node_or_null("Background")
	_check(bg != null and bg.has_method("set_level"), "фон умеет менять уровень")
	if bg == null:
		for _i in LEVELS + 1:
			_check(false, "—")
		e["game"].queue_free()
		await process_frame
		return
	# У каждого уровня СВОЙ фон, но устроены они по-разному: первый — плитка из
	# набора `bg_loop*`, второй и третий — куски своих нарисованных полос.
	# Проверяется не «текстуры разные», а ЧТО ИМЕННО стоит на каждом уровне:
	# «разные» прошло бы и на случайной плитке, подставленной второму уровню.
	var texs : Array = []
	for lvl in range(1, LEVELS + 1):
		bg.call("set_level", lvl)
		await process_frame
		var t : Texture2D = (bg.get_node("BgA") as Sprite2D).texture
		var f : String = String(t.resource_path).get_file() if t != null else ""
		texs.append(f)
		# Плиточных уровней теперь ДВА: канализация по замыслу и свалка — потому
		# что её полосу ещё не рисовали. Спрашиваем список, а не сравниваем с
		# единицей: нарисуют полосу свалки — тест поедет за раскладкой сам.
		if lvl in BG.TILE_LEVELS:
			_check(f.begins_with("bg_loop"), "уровень %d — плитка: %s" % [lvl, f])
		else:
			# Полосы уровня объявлены в раскладке; кусок обязан быть из них.
			var ok := false
			for strip in (BG.LEVEL_STRIPS.get(lvl, []) as Array):
				if f.begins_with("level%d_" % int(strip)):
					ok = true
			_check(ok, "уровень %d — кусок своей полосы %s: %s"
				% [lvl, BG.LEVEL_STRIPS.get(lvl, []), f])
	var distinct : Dictionary = {}
	for t in texs:
		distinct[t] = true
	_check(distinct.size() == LEVELS, "и у каждого эпизода фон свой: %d разных" % distinct.size())
	e["game"].queue_free()
	await process_frame

# ── Эпизод против бесконечного ───────────────────────────────────────────────
# Одна и та же машинерия уровней, разница ровно в одном: кончается ли цепочка
# после последнего уровня или заходит на новый круг. Ошибка тут тихая в обе
# стороны — эпизод, не желающий кончаться, читается как зависший забег, а
# бесконечный, кончившийся на третьем боссе, — как «игра сломалась на победе».
func _test_chain() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)

	# ЭПИЗОД. Ставим второй и доводим слово до конца: следующего уровня быть не
	# должно ни на первом эпизоде, ни на последнем.
	sp.set("endless_chain", false)
	for ep in LEVELS:
		sp.call("set_start_level", ep)
		sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
		var got : Array = []
		var h := func(boss: String, nxt: int) -> void: got.append([boss, nxt])
		sp.connect("level_cleared", h)
		sp.set_process(true)
		sp.call("_run_letter")
		await _tick(8.0)
		sp.disconnect("level_cleared", h)
		_check(got.size() == 1 and int(got[0][1]) == -1,
			"эпизод %d кончается сам: %s" % [ep + 1, got])

	# БЕСКОНЕЧНЫЙ. Между уровнями цепочка ведёт дальше, а после ПОСЛЕДНЕГО
	# следующего уровня нет: локации кончились, и дальше идёт хвост.
	sp.set("endless_chain", true)
	sp.call("set_start_level", 0)
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	var mid : Array = []
	var hm := func(boss: String, nxt: int) -> void: mid.append(nxt)
	sp.connect("level_cleared", hm)
	sp.set_process(true)
	sp.call("_run_letter")
	await _tick(8.0)
	sp.disconnect("level_cleared", hm)
	_check(mid.size() == 1 and int(mid[0]) == 1,
		"в бесконечном после первого уровня идёт второй: %s" % [mid])

	sp.call("set_start_level", LEVELS - 1)
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	var tail : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void: tail.append(nxt))
	sp.set_process(true)
	sp.call("_run_letter")
	await _tick(8.0)
	_check(tail.size() == 1 and int(tail[0]) == -1,
		"а после последнего уровня цепочка кончается: %s" % [tail])
	e["game"].queue_free()
	await process_frame

# ── Хвост бесконечного: СУПЕР ХАРД ───────────────────────────────────────────
# После последнего босса в бесконечном уровней больше нет: фон замирает, а поток
# идёт дальше и затягивается. Ломается это тихо в обе стороны — хвост, который
# не усложняется, читается как «игра забыла про меня», а хвост, оставшийся на
# предбоссовой фазе, отнимает еду и убивает голодом, а не трудностью.
func _test_hardcore() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	sp.set("endless_chain", true)
	sp.call("set_start_level", LEVELS - 1)

	sp.call("enter_hardcore")
	await process_frame
	_check(bool(sp.call("is_hardcore")), "хвост включился")
	# Фаза — ПОСЛЕДНЯЯ ИГРАБЕЛЬНАЯ, а не предбоссовая: у той стоит `no_pizza`,
	# и оставить её навсегда значит забрать у игрока жир, то есть жизни.
	var ph : int = int(sp.get("_phase"))
	_check(ph == SP.CAMPAIGN_PHASES.size() - 2,
		"фаза встала на последнюю играбельную: %d" % ph)
	_check(not bool(SP.CAMPAIGN_PHASES[ph]["no_pizza"]),
		"и пицца в хвосте продолжает летать")
	# Буквы кончились: слово — часы УРОВНЯ, а уровня больше нет. Оставленное,
	# оно выложилось бы до конца и позвало четвёртого босса.
	_check(int(sp.get("_letter_idx")) >= SP.LETTER_WORD.length(),
		"буквы в хвосте выключены: %d" % int(sp.get("_letter_idx")))

	# НАБОР — СУММА ВСЕХ УРОВНЕЙ. Ровно это и обещает «супер хард»: не «то же
	# самое, но быстрее», а всё, что игрок видел за игру, разом.
	var kinds : Dictionary = {}
	for _i in 8000:
		kinds[String(sp.call("_pick_level_hazard"))] = true
	var missing : Array = []
	for table in SP.HAZ_LEVEL:
		for item in (table as Dictionary):
			if not kinds.has(String(item)):
				missing.append(String(item))
	_check(missing.is_empty(), "в хвосте летит всё со всех уровней: нет %s" % [missing])

	# СТУПЕНЬКА. Плотность растёт, но не бесконечно: у неё есть пол, ниже
	# которого кадр перестаёт читаться.
	var t0 : float = float(sp.call("_hardcore_tighten"))
	_check(is_equal_approx(t0, 1.0), "на нулевой ступени плотность как была: %.2f" % t0)
	var seen : Array = []
	for i in SP.HARDCORE_TIERS + 4:
		sp.call("_bump_hardcore_tier")
		seen.append(float(sp.call("_hardcore_tighten")))
	_check(seen[0] < t0, "ступенька ужимает интервалы: %.2f → %.2f" % [t0, seen[0]])
	_check(int(sp.call("hardcore_tier")) == SP.HARDCORE_TIERS,
		"ступеньки упираются в потолок: %d" % int(sp.call("hardcore_tier")))
	_check(seen[seen.size() - 1] >= SP.HARDCORE_TIGHT_MIN - 0.001,
		"и не проваливаются ниже пола: %.2f при поле %.2f"
			% [seen[seen.size() - 1], SP.HARDCORE_TIGHT_MIN])

	# НАКАЛ ВОЛН растёт вместе со ступенькой: самые злые формы T5 (шахматка и
	# крест) жили у старого бесконечного на фазах 5+ и вместе с ним стали
	# недостижимы — в кампании до этой ветки доходит только фаза 4.
	_check(int(sp.call("_wave_intensity")) >= 7,
		"на потолке ступеньки накал волн достаёт до самых злых форм: %d"
			% int(sp.call("_wave_intensity")))

	# И СКОРОСТЬ растёт выше кампанийного потолка — иначе хвост отличался бы от
	# третьего уровня только плотностью.
	_check(float(sp.call("_speed_cap")) > SP.CAMPAIGN_SPEED_MAX,
		"потолок скорости в хвосте выше: %.0f против %.0f"
			% [float(sp.call("_speed_cap")), SP.CAMPAIGN_SPEED_MAX])

	# А в ЭПИЗОДЕ ничего этого нет: там хвоста не бывает.
	sp.set("_hardcore", false)
	sp.set("_hardcore_tier", 0)
	_check(is_equal_approx(float(sp.call("_speed_cap")), SP.CAMPAIGN_SPEED_MAX),
		"вне хвоста потолок прежний: %.0f" % float(sp.call("_speed_cap")))
	e["game"].queue_free()
	await process_frame

# ── Хелперы ──────────────────────────────────────────────────────────────────

func _boot() -> Dictionary:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	await process_frame
	return { "game": game, "sp": sp }

func _tick(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

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
