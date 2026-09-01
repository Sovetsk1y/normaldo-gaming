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

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

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
