extends SceneTree

# Headless-проверка ЭПИЗОДОВ и чипа режима.
#   godot --headless --path . --script res://dev/smoke_episodes.gd
#
# Кампания разобрана на три эпизода: прошёл первый — забег кончился, открылся
# второй; пройдены все три — открылся бесконечный. Ломается это молча и обидно:
# чип встаёт не туда, кольцо перебора включает закрытую позицию, забег уходит не
# в тот эпизод. На глаз ловится только полным прохождением, то есть никогда.
#
# Отдельно проверяется САМО РЕШЕНИЕ навигации: чип обязан вставать на следующий
# неотыгранный эпизод сам, а перебор — идти только по открытому. Ради этого
# разбиение и делалось терпимым — см. /Концепция/Уровни/Кампания — пять эпизодов.md

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 29

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

var _hud  : Node = null
var _save : Node = null
var _qm   : Node = null

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	_hud  = game.get_node_or_null("HUD")
	_save = get_root().get_node_or_null("SaveData")
	_qm   = get_root().get_node_or_null("QuestManager")
	if _hud == null or _save == null or _qm == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Что открыто ──")
	_test_unlocks()
	print("── Куда встаёт чип ──")
	_test_default()
	print("── Кольцо перебора ──")
	_test_ring()
	print("── Прохождение эпизода ──")
	await _test_finish()
	print("── Занавес перед сменой локации ──")
	await _test_curtain()
	print("── Денежное облако первого эпизода ──")
	await _test_cloud()
	print("── Вход в хвост ──")
	await _test_hardcore_entry()
	_finish()

func _done(n: int) -> void:
	_save.set("episodes_done", n)

# Эпизод 1 открыт всегда — с него игра и начинается; эпизод N — после N−1;
# бесконечный — после всей кампании.
func _test_unlocks() -> void:
	_done(0)
	_check(bool(_hud.call("_is_episode_unlocked", 1))
		and not bool(_hud.call("_is_episode_unlocked", 2)),
		"на чистом сейве открыт только первый эпизод")
	_check(not _qm.call("is_endless_unlocked"), "и бесконечный закрыт")

	_done(1)
	_check(bool(_hud.call("_is_episode_unlocked", 2))
		and not bool(_hud.call("_is_episode_unlocked", 3)),
		"пройденный первый открывает второй, но не третий")
	_check(not _qm.call("is_endless_unlocked"),
		"бесконечный на середине кампании всё ещё закрыт")

	# «ВСЯ КАМПАНИЯ» — это столько эпизодов, сколько в таблице, а не тройка.
	# Длина менялась трижды (пять, три, шесть), и число, вписанное в тест,
	# каждый раз означало «проверка молчит».
	var all_eps : int = _qm.call("campaign_episodes")
	_done(all_eps - 1)
	_check(not _qm.call("is_endless_unlocked"),
		"за эпизод до конца бесконечный ещё закрыт")
	_done(all_eps)
	_check(_qm.call("is_endless_unlocked"),
		"пройденная кампания открывает бесконечный")

# Обычный путь «зашёл в меню и нажал ИГРАТЬ» обязан стоить НОЛЬ нажатий на чип.
func _test_default() -> void:
	_done(0)
	_check(int(_hud.call("_default_mode_position")) == 1,
		"на чистом сейве чип на первом эпизоде")
	_done(1)
	_check(int(_hud.call("_default_mode_position")) == 2,
		"после первого — сразу на втором")
	_done(2)
	_check(int(_hud.call("_default_mode_position")) == 3,
		"после второго — на третьем")
	_done(int(_qm.call("campaign_episodes")))
	_check(int(_hud.call("_default_mode_position")) == 0,
		"после всей кампании — на бесконечном")

# В кольце нет закрытых позиций: прощёлкивать нечего, и «дойти до последнего»
# стоит ровно столько нажатий, сколько ОТКРЫТО, а не сколько существует.
func _test_ring() -> void:
	_done(0)
	_check((_hud.call("_mode_positions") as Array) == [1],
		"на чистом сейве в кольце одна позиция: %s" % [_hud.call("_mode_positions")])
	_done(1)
	_check((_hud.call("_mode_positions") as Array) == [1, 2],
		"после первого эпизода — две: %s" % [_hud.call("_mode_positions")])
	var eps : int = _qm.call("campaign_episodes")
	_done(eps)
	var want : Array = []
	for e in range(1, eps + 1):
		want.append(e)
	want.append(0)
	_check((_hud.call("_mode_positions") as Array) == want,
		"после кампании — все эпизоды и бесконечный последним: %s"
			% [_hud.call("_mode_positions")])

	# Перебор идёт ПО КРУГУ и возвращается в начало, а не упирается в край.
	# С ПОСЛЕДНЕГО эпизода, а не с третьего: третий давно не последний, и число
	# в тесте держало проверку на кампании, которой уже нет.
	_hud.set("_mode_btn_pos", eps)
	_hud.call("_on_mode_btn_pressed")
	_check(int(_hud.get("_mode_btn_pos")) == 0,
		"с последнего эпизода нажатие ведёт на бесконечный: %d" % int(_hud.get("_mode_btn_pos")))
	_hud.call("_on_mode_btn_pressed")
	_check(int(_hud.get("_mode_btn_pos")) == 1,
		"а с бесконечного круг замыкается на первый: %d" % int(_hud.get("_mode_btn_pos")))

# Победа над боссом эпизода засчитывает ЭПИЗОД, а не кампанию: это и открывает
# следующий. Без записи в сейв игрок побеждал бы босса и возвращался в меню к
# тому же самому эпизоду.
func _test_finish() -> void:
	_done(0)
	_hud.set("_run_episode", 1)
	_hud.set("_next_level", -1)
	_hud.call("_on_boss_defeated")
	# Ждём только записи в сейв: до неё успевает проплыть WIN из долларов, а
	# после идёт вся хореография экрана смерти, и досматривать её здесь незачем.
	# Ждём по РЕАЛЬНОМУ времени, а не по кадрам: и слово, и пауза перед экраном
	# смерти живут на таймерах, а не на счётчике кадров.
	var t0 : int = Time.get_ticks_msec()
	while int(_save.get("episodes_done")) < 1 and Time.get_ticks_msec() - t0 < 30000:
		get_root().get_tree().paused = false
		await process_frame
	_check(int(_save.get("episodes_done")) == 1,
		"победа над боссом первого эпизода засчитала его: %d" % int(_save.get("episodes_done")))
	_check(not _qm.call("is_endless_unlocked"),
		"и бесконечный за один эпизод не открылся")
	# Глава книги закрывается ИМЕННО этим эпизодом. Раньше её закрывала общая
	# победа над боссом — с тремя боссами такое задание закрывалось бы первым же
	# из них, и книга шла бы впереди игры.
	_check(bool((_qm.get("story_completed") as Array)[_quest_idx("episode_done:1")]),
		"и задание книги за первый эпизод закрылось")

# В БЕСКОНЕЧНОМ третий босс не кончает забег, а переводит его в хвост: фон
# замирает, спавнер уходит в супер хард. Ошибка тут громкая для игрока и тихая
# для теста — забег просто оборвался бы экраном смерти на победе.
func _test_hardcore_entry() -> void:
	var game : Node = _hud.get_parent()
	var sp   : Node = game.get_node_or_null("Spawner")
	var bg   : Node = game.get_node_or_null("Background")
	sp.set("campaign_mode", true)
	sp.set("endless_chain", true)
	sp.call("set_start_level", 2)
	bg.call("start_scrolling")

	_hud.set("_run_episode", 0)     # бесконечный
	_hud.set("_next_level", -1)     # цепочка уровней кончилась
	var done_before : int = int(_save.get("episodes_done"))
	_hud.call("_on_boss_defeated")

	var t0 : int = Time.get_ticks_msec()
	while not bool(sp.call("is_hardcore")) and Time.get_ticks_msec() - t0 < 30000:
		get_root().get_tree().paused = false
		await process_frame
	_check(bool(sp.call("is_hardcore")), "третий босс в бесконечном включил хвост")
	_check(not bool(bg.get("_scrolling")), "и фон остановился")
	_check(int(_save.get("episodes_done")) == done_before,
		"бесконечный не засчитывает эпизоды: %d" % int(_save.get("episodes_done")))
	_check(bool((_qm.get("story_completed") as Array)[_quest_idx("hardcore_reached")]),
		"и задание книги «Всё и сразу» закрылось хвостом")

# Занавес «НЕМНОГО ПОЗДНЕЕ…» стоит между интро на диване и уровнем, фон
# которого не квартира. Ломается это молча в обе стороны: не показался — игрок
# видит подмену фона под собой; показался там, где менять нечего, — полторы
# секунды пустого ожидания перед первым эпизодом.
# Насколько переход закрыл экран, от 0 до 1. У шторки это заливка по шейдеру, у
# облака денег — непрозрачность подложки: у знака доллара внутри дырки, и
# сплошность держит именно она, а не плотность кучи.
func _transition_cover(t: Node) -> float:
	var r = t.get("_rect")
	if r != null and is_instance_valid(r) and r.material is ShaderMaterial:
		return float((r.material as ShaderMaterial).get_shader_parameter("factor"))
	for c in t.get_children():
		if c is ColorRect:
			return (c as ColorRect).color.a
	return 0.0

func _test_curtain() -> void:
	_check(not _hud.call("_needs_curtain", 1), "перед первым эпизодом занавеса нет")
	_check(not _hud.call("_needs_curtain", 0), "и перед бесконечным тоже — он начинается с первого уровня")
	_check(bool(_hud.call("_needs_curtain", 2)) and bool(_hud.call("_needs_curtain", 3)),
		"а перед вторым и третьим — есть")

	# Занавес обязан ЗАКРЫТЬ ЭКРАН ПОЛНОСТЬЮ и только потом отдать смену фона: в
	# этом весь его смысл. Позвал бы `on_covered` раньше — подмену было бы видно
	# сквозь незакрытый переход.
	#
	# ЗАМЕРЯЕТСЯ ЭТО ПО-РАЗНОМУ У РАЗНЫХ СТИЛЕЙ, и первая версия проверки этого
	# не знала: она читала `factor` шейдера шторки, а при включённом облаке денег
	# шторки нет вовсе — `_rect` не создаётся, замер оставался нулевым, и тест
	# падал на рабочем переходе. Стилей два и оба живые (`LevelTransition.STYLE`),
	# значит и мерить надо то, чем каждый из них закрывает экран: шторка —
	# заливкой по шейдеру, облако — своей подложкой.
	var covered : Array = [false]
	var seen_alpha : Array = [0.0]
	var t = load("res://scripts/level_transition.gd").new()
	_hud.add_child(t)
	t.call("_run", "НЕМНОГО ПОЗДНЕЕ…", func() -> void: covered[0] = true)
	var t0 : int = Time.get_ticks_msec()
	while not covered[0] and Time.get_ticks_msec() - t0 < 6000:
		get_root().get_tree().paused = false
		await process_frame
		seen_alpha[0] = maxf(seen_alpha[0], _transition_cover(t))
	_check(covered[0], "занавес отдал смену фона")
	_check(seen_alpha[0] >= 0.999,
		"и отдал её ЗАКРЫТЫМ: экран закрыт на %.2f из 1.00" % seen_alpha[0])
	if is_instance_valid(t):
		t.queue_free()
	await process_frame

	# За занавесом уезжает не только фон: диван и телевизор — мебель квартиры, и
	# на улице им делать нечего. Сами они уползают влево вместе с фоном, но
	# занавес поднимается раньше, и первые секунды нового эпизода игрок смотрел
	# на квартиру, переехавшую на улицу.
	var game : Node = _hud.get_parent()
	_check(_on_screen(game, "Couch") or _on_screen(game, "Tv"),
		"до смены уровня мебель на сцене есть")
	_hud.call("_clear_apartment", 2)
	await process_frame
	await process_frame
	# Спрашиваем «не видно», а не «узла нет»: телевизор доводит свой звук
	# затуханием и живёт ещё долю секунды после того, как исчез с экрана. Игроку
	# важно первое.
	_check(not _on_screen(game, "Couch") and not _on_screen(game, "Tv"),
		"а на втором уровне её не видно")

	# На ПЕРВОМ уровне мебель остаётся: там комната и есть фон.
	var game2 : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game2)
	await process_frame
	var hud2 : Node = game2.get_node_or_null("HUD")
	hud2.call("_clear_apartment", 1)
	await process_frame
	_check(_on_screen(game2, "Couch"),
		"а на первом уровне диван остаётся — там квартира и есть фон")
	game2.queue_free()
	await process_frame

func _on_screen(game: Node, name: String) -> bool:
	var n := game.get_node_or_null(name)
	return n != null and is_instance_valid(n) and (n as CanvasItem).visible

# Индекс сюжетного задания по его условию. По номеру искать нельзя: главы
# книги перетасовывались уже дважды, и тест, прибитый к числу, переживает
# перестановку молча — проверяя не то задание.
func _quest_idx(cond: String) -> int:
	var qs : Array = _qm.STORY_QUESTS
	for i in qs.size():
		if (qs[i] as Dictionary).get("cond", "") == cond:
			return i
	_check(false, "в книге нет задания с условием %s" % cond)
	return 0

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


# ── ДЕНЕЖНОЕ ОБЛАКО ПЕРВОГО ЭПИЗОДА ──────────────────────────────────────────
# Сюжетную строку эпизода показывает занавес — но у первого эпизода занавеса
# нет и быть не должно: он прикрывает подмену фона, а первый начинается на том
# же фоне, на котором доиграло интро.
#
# Поэтому первому нужен свой способ сказать то же самое, и он не должен
# останавливать забег. Проверяется ровно эта развилка: у кого занавес — у того
# нет облака, и наоборот. Сломается она молча: игрок первого эпизода просто
# никогда не узнает, зачем он бежит, а игрок второго увидит одно и то же дважды.
func _test_cloud() -> void:
	# Само облако: собирается, несёт текст и не имеет столкновений — поймать его
	# нельзя, иначе первые секунды забега стали бы ловушкой из ничего.
	var cloud_script := load("res://scripts/money_cloud.gd")
	var host := Node2D.new()
	get_root().add_child(host)
	var c : Node2D = cloud_script.call("spawn", host, "Выберись из канализации")
	_check(c != null, "облако собралось")
	if c != null:
		await process_frame
		var texts : Array = []
		var areas : int = 0
		for n in c.get_children():
			if n is Label:
				texts.append(String((n as Label).text))
			if n is Area2D:
				areas += 1
		_check(texts.has("Выберись из канализации"), "и несёт сюжетную строку: %s" % [texts])
		_check(areas == 0, "и не ловит столкновений: зон %d" % areas)
	# Пустая строка облака не даёт вовсе: облако без текста — просто мусор,
	# пролетевший через экран.
	_check(cloud_script.call("spawn", host, "  ") == null, "без текста облака нет")
	host.free()
	await process_frame
