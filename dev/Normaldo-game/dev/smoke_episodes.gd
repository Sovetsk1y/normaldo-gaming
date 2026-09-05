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
# разбиение и делалось терпимым — см. /Концепция/Уровни/Кампания — три уровня.md

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 21

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

	_done(3)
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
	_done(3)
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
	_done(3)
	_check((_hud.call("_mode_positions") as Array) == [1, 2, 3, 0],
		"после кампании — все четыре, бесконечный последним: %s"
			% [_hud.call("_mode_positions")])

	# Перебор идёт ПО КРУГУ и возвращается в начало, а не упирается в край.
	_hud.set("_mode_btn_pos", 3)
	_hud.call("_on_mode_btn_pressed")
	_check(int(_hud.get("_mode_btn_pos")) == 0,
		"с третьего эпизода нажатие ведёт на бесконечный: %d" % int(_hud.get("_mode_btn_pos")))
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
