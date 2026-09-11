extends SceneTree

# Английская сборка — по экранам.
#   godot --headless --path . --script res://dev/smoke_i18n_screens.gd
#
# ── ЗАЧЕМ ОТДЕЛЬНО ОТ smoke_i18n ───────────────────────────────────────────
# Тот тест сверяет ТАБЛИЦУ С ИСХОДНИКАМИ: каждый ключ жив, подстановки сходятся,
# надпись не склеена и не переиначена. Всё это — про текст, который написан в
# коде.
#
# А на экран попадает не он. Между надписью в коде и надписью под пальцем игрока
# лежит дорога: значение достали из словаря данных, подставили в шаблон,
# прогнали через `to_upper`, собрали в две строки. Любой её участок способен
# увести строку мимо перевода, и ни один из них по исходникам не виден.
#
# Поэтому здесь игра ЗАПУСКАЕТСЯ на английском, открываются экраны, и по дереву
# собирается ВЕСЬ показанный текст. Кириллица в нём — непереведённое место, с
# точным адресом узла.
#
# Так уже ловилось: половина экрана скинов осталась русской при полной таблице —
# `title + "\n" + desc` уходил в словарь склейкой. По исходникам это выглядело
# безупречно.

var _fails  : int = 0
var _checks : int = 0

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

# ── ЧТО ОСТАЁТСЯ РУССКИМ НАРОЧНО ──────────────────────────────────────────
# Имена собственные: Нормальдо и на английском Нормальдо. Дев-кнопки вообще не
# для игрока — они уезжают из релиза рубильником DevFlags.ENABLED.
const NAMES : Array = ["НОРМАЛЬДО", "ГАРРИ", "КУСС", "ГЛАЙД", "ТАЙСОН",
	# Название языка пишется НА САМОМ ЯЗЫКЕ: список языков читает тот, кто
	# текущего как раз и не понимает (см. Loc.NAMES).
	"РУССКИЙ"]
const DEV_MARKS : Array = ["DEV", "СБРОС", "БОССЫ", "ОСТР", "ОБУЧ", "БЕСС",
	"СЕТКА", "КАРТОЧКИ", "ВОЛНА", "БОЧКА", "СТЕНА", "МЕШОК", "КРОК", "СВАТ",
	"ТАЧКА", "ОСТРОВ", "МИНИ", "УР."]

const CYR := "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var save := get_root().get_node_or_null("SaveData")
	var hud  : Node = game.get_node_or_null("HUD")
	if save == null or hud == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	# Открыть надо ВСЁ, а заперто по прогрессу почти всё: без этого проверка
	# посмотрит на три экрана из десяти и отрапортует «чисто».
	save.set("tutorial_done", true)
	save.set("dollars", 99000)
	save.set("tokens", 40)
	save.set("episodes_done", 5)

	# ЯЗЫК СТАВИТСЯ ЛОКАЛЬЮ ПРОЦЕССА, а не `Loc.set_language`: тот пишет выбор в
	# сохранение на диске, и прогон оставил бы английский язык всей батарее и
	# разработчику заодно.
	TranslationServer.set_locale("en")
	await process_frame

	print("── Главное меню ──")
	await _sweep("меню", "СКИНЫ")

	# ── РАЗДЕЛЫ ПЕРЕКЛЮЧАЮТСЯ НА САМОМ ЭКРАНЕ ─────────────────────────────
	# `_show_settings_modal` при уже открытых настройках просто выходит — второй
	# и третий вызовы не делали ничего, и три раздела из четырёх проверялись
	# вхолостую. Поэтому раздел меняется там же, где его меняет палец игрока.
	print("── Настройки ──")
	hud.call("_show_settings_modal", "sound")
	await _tick(0.4)
	var scr : Node = hud.get("_settings_screen")
	var sections : Array = load("res://scripts/settings_screen.gd") \
		.get_script_constant_map().get("SECTIONS", [])
	_check(scr != null and sections.size() >= 5,
		"экран настроек открылся, разделов: %d" % sections.size())
	for s in sections:
		var sec := String((s as Dictionary).get("key", ""))
		var ttl := String((s as Dictionary).get("title", ""))
		if scr != null:
			scr.set("_sel", sec)
			scr.call("_rebuild")
		await _tick(0.3)
		await _sweep("настройки · " + sec, ttl)

	print("── Книга и достижения ──")
	hud.call("_show_achievements")
	await _tick(0.6)
	await _sweep("достижения", "КНИГА УЧИТЕЛЯ")

	print("── Таблица лидеров ──")
	hud.call("_show_leaderboard")
	await _tick(0.8)
	await _sweep("лидеры", "ЛИДЕРЫ")

	print("── Задания ──")
	hud.call("_show_quests")
	await _tick(0.6)
	await _sweep("задания", "ЗАДАНИЯ")

	print("── Скины ──")
	hud.call("_on_shop_tapped")
	await _tick(0.8)
	await _sweep("скины", "СКИНЫ")

	print("── Слоты ──")
	hud.call("_show_slots")
	await _tick(0.6)
	await _sweep("слоты", "СЛОТЫ")

	# ── КАРТОЧКА СКИНА ───────────────────────────────────────────────────
	# Самый плотный текст в игре: способность, резисты, пассивка, лестница
	# уровней — и почти всё собрано подстановкой. Берётся не один скин, а
	# несколько: у каждого свои способности, и русское слово прячется ровно в
	# том, которого не посмотрели.
	print("── Карточки скинов ──")
	# Скины берутся ВСЕ до одного: `get_skin` на незнакомый идентификатор молча
	# отдаёт первый в списке, так что выборочный список проверял бы один и тот
	# же скин четырежды и ничего об остальных не сказал.
	var skins : Array = load("res://scripts/skin_registry.gd") \
		.get_script_constant_map().get("SKINS", [])
	_check(skins.size() >= 10, "скинов в списке: %d" % skins.size())
	for sk in skins:
		hud.call("_show_skin_detail", sk, true, null, true)
		await _tick(0.45)
		await _sweep("карточка · " + String((sk as Dictionary).get("id", "?")),
			"СПОСОБНОСТИ")

	# ── ЭКРАН СМЕРТИ ─────────────────────────────────────────────────────
	# Самое опасное место для перевода во всей игре: тут почти нет надписей,
	# написанных целиком, — всё собирается подстановкой из наград, уровней и
	# имён предметов. Награды передаются нарочно: без них половина экрана не
	# строится вовсе.
	print("── Экран смерти ──")
	save.set("skin_xp", 120)
	save.set("skin_level", 2)
	hud.set("_dollars_this_run", 640)
	hud.set("_elapsed_time", 96.0)
	hud.set("_go_best_before", 310)
	hud.call("_show_game_over", 420, [
		{ "level": 2, "dollars": 300, "tokens": 0 },
		{ "level": 3, "dollars": 500, "tokens": 1 },
	], 40, 1)
	await _tick(1.2)
	await _sweep("смерть", "ЕЩЁ РАЗ")

	# ── ПУШ-УВЕДОМЛЕНИЯ ──────────────────────────────────────────────────
	# Единственный текст игры, который НЕ проходит через Control: пуш уходит в
	# систему обычной строкой, и автоперевод Godot до него не достаёт. Причём
	# текст вшивается в момент ПОСТАНОВКИ В ОЧЕРЕДЬ, а всплывёт через день —
	# увидеть это глазами нельзя почти никак.
	#
	# Планы собираются настоящие, все восемь: половина из них была переведена, а
	# половина нет, и в логе прогона они стояли рядом.
	print("── Уведомления ──")
	save.set("last_session_end_at", int(Time.get_unix_time_from_system()) - 3 * 86400)
	var planner := get_root().get_node_or_null("NotifPlanner")
	var specs : Array = []
	if planner != null:
		for f in ["_plan_a", "_plan_b", "_plan_c", "_plan_d",
				"_plan_e", "_plan_f", "_plan_g", "_plan_h"]:
			if planner.has_method(f):
				specs.append_array(planner.call(f) as Array)
	# Пустой план прошёл бы проверку не глядя — а он же и означает, что ни одно
	# уведомление не собралось и смотреть было не на что.
	_check(specs.size() > 0, "уведомлений запланировано: %d" % specs.size())
	var ru_notif : Array = []
	for sp in specs:
		for key in ["title", "body"]:
			var txt := _strip_nick(String((sp as Dictionary).get(key, "")))
			if _has_cyr(txt) and not _allowed(txt):
				ru_notif.append(txt)
	_check(ru_notif.is_empty(), "уведомления переведены: %s" % [ru_notif])

	# ── ПУШИ ОТ СЕРВЕРА ──────────────────────────────────────────────────
	# «Тебя обогнали» и «итоги недели» собираются НА СЕРВЕРЕ: когда они
	# приходят, игра не запущена, и переводить некому. Язык сервер знает только
	# из регистрации токена — и узнаёт его ровно тогда, когда клиент решит
	# зарегистрироваться заново.
	#
	# Вот это решение здесь и проверяется. Сверка по одному токену (как было)
	# смену языка пропускала целиком: токен не меняется, регистрация не идёт,
	# сервер навсегда остаётся при русском. Увидеть это можно было бы только на
	# живом устройстве, с настоящим сервером и через неделю ожидания.
	print("── Язык уезжает на сервер вместе с токеном ──")
	var notif := get_root().get_node_or_null("Notifications")
	if notif == null:
		_check(false, "автолоад Notifications не поднялся")
	else:
		var was_token := String(save.get("registered_push_token"))
		var was_lang  := String(save.get("registered_push_lang"))
		save.set("registered_push_token", "TOKEN-1")
		save.set("registered_push_lang",  "ru")
		_check(not notif.call("push_registration_stale", "TOKEN-1", "ru"),
			"тот же токен и тот же язык — сервер не дёргаем")
		_check(notif.call("push_registration_stale", "TOKEN-1", "en"),
			"язык сменился — регистрируемся заново, хотя токен прежний")
		_check(notif.call("push_registration_stale", "TOKEN-2", "ru"),
			"токен сменился — тоже заново")
		save.set("registered_push_token", was_token)
		save.set("registered_push_lang",  was_lang)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Сбор текста со всего, что сейчас видно ────────────────────────────────
# ── ПУСТОЙ ЭКРАН ПРОХОДИТ ЛЮБУЮ ПРОВЕРКУ ──────────────────────────────────
# Не открывшийся экран кириллицы не показывает — и сбор радостно зеленеет. Так
# и вышло в первый раз: три раздела настроек из четырёх не открылись, а тест
# отрапортовал «чисто».
#
# Поэтому вместе с кириллицей ищется ОПОЗНАВАТЕЛЬНАЯ НАДПИСЬ экрана — и ищется
# в переведённом виде, потому что на английском её русского написания на экране
# уже нет.
func _sweep(where: String, marker: String) -> void:
	await process_frame
	var bad   : Array = []
	var shown : Array = []
	_walk(get_root(), bad, shown)
	var want := TranslationServer.translate(marker)
	var here := false
	for s in shown:
		if String(s).contains(want):
			here = true
			break
	if not here:
		print("      (надписей на экране: %d) %s" % [shown.size(), shown.slice(0, 40)])
	_check(here, "%s — экран на месте, видно «%s»" % [where, want])
	_check(bad.is_empty(), "%s — русского не осталось: %s"
		% [where, bad.slice(0, 12)])

func _walk(n: Node, bad: Array, shown: Array) -> void:
	if n is Control:
		var c := n as Control
		if not c.is_visible_in_tree():
			return   # спрятанное не показывается — и спрашивать с него нечего
		var t = c.get("text")
		# ── СПРАШИВАТЬ НАДО НЕ `text` ───────────────────────────────────────
		# `text` отдаёт ИСХОДНУЮ строку — ту, что записали в код. Перевод Godot
		# делает позже и наружу не показывает: в свойстве навсегда остаётся
		# русский, даже когда на экране английский.
		#
		# Проверка по `text` поэтому ровно бесполезна — она краснеет на всей
		# игре и на переведённой тоже. Что реально увидит игрок, отдаёт
		# `atr()`: та же дорога, которой Control идёт перед отрисовкой.
		if t is String and String(t) != "":
			var vis := _strip_nick(c.atr(String(t)))
			shown.append(vis)
			if _has_cyr(vis) and not _allowed(vis):
				bad.append("%s: «%s»" % [c.name, vis.replace("\n", " / ")])
	elif n is CanvasItem and not (n as CanvasItem).visible:
		return
	for ch in n.get_children():
		_walk(ch, bad, shown)

func _has_cyr(s: String) -> bool:
	for ch in s:
		if CYR.contains(ch):
			return true
	return false

# ИМЯ ИГРОКА не переводится никогда: он написал его сам, и на любом языке оно
# остаётся тем же. Вырезается ИМЕННО ОНО, а не прощается вся строка целиком, —
# иначе ник из двух букв помиловал бы половину экрана вместе с собой.
func _strip_nick(s: String) -> String:
	var save := get_root().get_node_or_null("SaveData")
	if save == null:
		return s
	var nick := String(save.get("display_name"))
	return s if nick == "" else s.replace(nick, "")

func _allowed(s: String) -> bool:
	var up := s.to_upper()
	for nm in NAMES:
		if up.contains(String(nm)):
			return true
	for d in DEV_MARKS:
		if up.contains(String(d)):
			return true
	return false

# ── Мелочи ────────────────────────────────────────────────────────────────
# Экраны НЕ ЗАКРЫВАЮТСЯ между сборами нарочно: открытый поверх предыдущего, он
# оставляет под собой и его надписи — проверка от этого только шире.

func _tick(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
