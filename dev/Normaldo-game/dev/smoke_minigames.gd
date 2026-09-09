extends SceneTree

# Headless-проверка СТЫКОВ между мини-играми.
#   godot --headless --path . --script res://dev/smoke_minigames.gd
#
# Каждая мини-game по отдельности проверена своим тестом. Ломается же обычно не
# мини-игра, а переход из одной в другую: пицца-пати кончилась, прилетел автомат,
# автоматы развернулись на весь экран — а поверх них всё ещё летят спиты пачки.
#
# Причина этого класса ошибок одна: снаряды мини-игры лежат У НЕЁ, а не в
# спавнере, и `Spawner.collapse_items()` их не видит — он перебирает своих
# детей. Поэтому у каждой мини-игры есть `drop_flying()`, а замораживающая забег
# зовёт `Spawner.collapse_minigame_debris(self)`.

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud   : Node = game.get_node_or_null("HUD")
	var party : Node = game.get_node_or_null("PizzaParty")
	var slots : Node = game.get_node_or_null("SlotsGame")
	var boss  : Node = game.get_node_or_null("FatBoss")
	var sp    : Node = game.get_node_or_null("Spawner")
	if party == null or slots == null or boss == null or sp == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return
	hud.call("_start_game")
	for _i in 10:
		await process_frame

	print("── У каждой мини-игры есть чем убрать своё ──")
	for pair in [["PizzaParty", party], ["SlotsGame", slots], ["FatBoss", boss]]:
		_check((pair[1] as Node).has_method("drop_flying"),
			"%s умеет drop_flying()" % pair[0])
	_check(sp.has_method("collapse_minigame_debris"),
		"спавнер умеет собрать чужой мусор")

	print("── Автоматы гасят спиты пицца-пати ──")
	await _test_slots_over_party(game, party, slots, sp)

	# СВОЯ СЦЕНА: предыдущая проверка освобождает игру в конце, и работать с ней
	# дальше нельзя — Godot ругается «previously freed» на первом же доводе.
	print("── Пицца-пати включается ПОЙМАННЫМ ключом ──")
	await _test_pizza_key()

	print("── Оба ключа светятся одинаково, но разным цветом ──")
	_test_keys_look_alike()

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── ПИЦЦА-ПАТИ ВКЛЮЧАЕТСЯ КЛЮЧОМ, А НЕ САМА ─────────────────────────────────
# Раньше мини-игра стартовала по броску кубика раз в кадр: игрок бежит, и вдруг
# экран замирает и прилетает гигантская пачка. Ни причины, ни его участия.
#
# Теперь кубик выпускает КЛЮЧ — светящуюся коробку в потоке, — а игру включает
# только пойманный. Проверяются обе половины договора, и вторая важнее:
#   1. ключ вылетает и сам по себе игру НЕ запускает;
#   2. пойманный — запускает.
#
# Вторую сломать легче всего: сигнал переименовали, обработчик отцепился, — и
# ключ становится просто красивой коробкой, которая ничего не делает.
func _test_pizza_key() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud   : Node = game.get_node_or_null("HUD")
	var party : Node = game.get_node_or_null("PizzaParty")
	var nrm   : Node = game.get_node_or_null("Normaldo")
	if party == null or nrm == null:
		_check(false, "сцена не собралась")
		return
	hud.call("_start_game")
	for _i in 10:
		await process_frame
	# ЖИВОЙ ЗАБЕГ. Пойманный ключ включает игру только пока забег идёт: заморожен
	# спавнер (босс, чужая мини-игра) — не включает, и это правильно. Здесь нужен
	# именно живой, иначе проверка меряет не то, что написано в её названии.
	if nrm.has_method("enable_input"):
		nrm.call("enable_input")
	await process_frame
	_check(bool(party.call("_run_active")), "забег живой — ключу есть куда звать")

	party.set("_arm_timer", 0.0)
	party.call("_send_box")
	await process_frame

	var box : Node = party.get("_box")
	_check(box != null and is_instance_valid(box), "ключ вылетел в поток")
	_check(box != null and box.is_in_group("pizza_box"),
		"и лежит в своей группе — иначе его не поймать")

	# ХИТБОКС ПОД РАЗМЕР КАРТИНКИ. Ключ вдвое крупнее супер-пиццы, и радиус,
	# скопированный у неё как есть, дал бы круг вдвое меньше нарисованной
	# коробки. Промах в таком месте читается не как «не попал», а как «предмет
	# сломан»: коробка вот она, голова по ней ведёт, а ничего не происходит.
	if box != null and is_instance_valid(box):
		var spr : Sprite2D = box.get_node_or_null("Sprite2D")
		var cs  : CollisionShape2D = box.get_node_or_null("CollisionShape2D")
		var art : Rect2i = ItemSizing.content_rect(spr.texture)
		# Меряем по РИСУНКУ, а не по рамке кадра: у коробки поля прозрачные, и
		# по рамке круг вышел бы «правильным», ловя воздух по краям.
		var drawn_h : float = float(art.size.y) * spr.scale.y
		var r : float = (cs.shape as CircleShape2D).radius
		_check(r * 2.0 > drawn_h * 0.75,
			"хитбокс под размер коробки: %.0f px при рисунке %.0f px"
				% [r * 2.0, drawn_h])
	# САМ ПО СЕБЕ ОН НИЧЕГО НЕ ВКЛЮЧАЕТ. Это половина правки: пока он летит,
	# забег идёт как шёл.
	for _i in 12:
		await process_frame
	_check(int(party.get("_state")) == 0,
		"пока он летит, мини-игра НЕ началась: состояние %d" % int(party.get("_state")))

	# А теперь ловим — как ловит игрок, через настоящую ветку подбора.
	if is_instance_valid(box):
		nrm.call("_on_area_entered", box)
	await process_frame
	await process_frame
	_check(int(party.get("_state")) != 0,
		"пойманный ключ включил мини-игру: состояние %d" % int(party.get("_state")))
	_check(party.get("_box") == null, "и ссылка на ключ отпущена")

	game.queue_free()
	await process_frame

# ── ДВА КЛЮЧА — ОДИН ЗНАК ───────────────────────────────────────────────────
# Светящийся предмет в потоке значит «сейчас будет мини-игра», и работает это,
# только пока знак ОДИН И ТОТ ЖЕ: зелёный зовёт в ЖИРОБОССА, оранжевый в
# ПИЦЦА-ПАТИ, а всё остальное совпадает.
#
# Проверяется по исходникам, что свечение у обоих берётся из общего кирпича.
# Скопированный блок расходится не от небрежности, а потому что правку вносят в
# тот файл, который открыли, — и однажды у одного ключа станет десять лучей
# вместо двенадцати. Глазами это не ловится: оба по отдельности красивые.
func _test_keys_look_alike() -> void:
	var mut : String = FileAccess.get_file_as_string("res://scripts/mutagen.gd")
	var box : String = FileAccess.get_file_as_string("res://scripts/pizza_box.gd")
	_check(mut.contains("minigame_glow.gd") and box.contains("minigame_glow.gd"),
		"свечение обоих ключей — из общего кирпича")
	# И СВОЕЙ КОПИИ НИ У КОГО НЕ ОСТАЛОСЬ. Кирпич можно подключить и продолжать
	# рисовать лучи руками рядом.
	var own : Array = []
	for pair in [["mutagen.gd", mut], ["pizza_box.gd", box]]:
		if String(pair[1]).contains("Polygon2D.new()") \
				or String(pair[1]).contains("CPUParticles2D.new()"):
			own.append(pair[0])
	_check(own.is_empty(), "и своей копии лучей ни у кого нет: %s" % [own])

	# Цвета РАЗНЫЕ, и это тоже часть знака.
	var mut_col : Color = load("res://scripts/mutagen.gd").COL_GLOW
	var box_col : Color = load("res://scripts/pizza_box.gd").COL_GLOW
	_check(mut_col.g > mut_col.r + 0.3, "мутаген зелёный: %s" % [mut_col])
	_check(box_col.r > box_col.g + 0.3, "коробка оранжевая: %s" % [box_col])

# Тот самый баг: пачка ещё доплёвывает, автоматы уже на весь экран, и предметы
# летят поверх них.
func _test_slots_over_party(game: Node, party: Node, slots: Node, sp: Node) -> void:
	party.call("dev_send_pizza_pack")
	# Ждём парковки пачки и тапаем — каждый тап выплёвывает предмет.
	for _i in 260:
		await process_frame
	for _i in 6:
		party.call("_spit_item")
		await process_frame
	var flying : int = (party.get("_proj") as Array).size()
	_check(flying > 0, "пачка наплевала предметов: %d" % flying)

	# Автоматы забирают забег себе.
	slots.call("dev_send_machine")
	for _i in 6:
		await process_frame
	slots.call("_on_caught")
	await process_frame

	_check((party.get("_proj") as Array).is_empty(),
		"спиты пачки убраны, а не летят поверх автоматов: осталось %d"
			% (party.get("_proj") as Array).size())

	game.queue_free()
	await process_frame
