extends SceneTree

# Headless-проверка: ВТОРОГО БОССА НА АРЕНЕ НЕ БЫВАЕТ.
#   godot --headless --path . --script res://dev/smoke_boss_twice.gd
#
# Дев-кнопка зовётся сколько угодно раз, и второе нажатие поднимало второго
# босса поверх первого. Дальше один из них добегал до конца, звал `queue_free`,
# и его корутина просыпалась уже вне дерева: `get_tree()` возвращал null, и
# `await get_tree().process_frame` падал с
#   Invalid get index 'process_frame' (on base: 'null instance').
#
# Игра при этом падала целиком, а поймать это можно было только нажав кнопку
# дважды — то есть глазами и случайно.
#
# См. hud.gd (_boss_on_screen), scripts/bum_king.gd (_alive / _step)

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 6

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
	var hud : Node   = game.get_node_or_null("HUD")
	var n   : Node2D = game.get_node_or_null("Normaldo")
	var sp  : Node   = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	n.set("_dev_immortal", true)
	await process_frame

	print("── Второй вызов ──")
	hud.call("summon_bum_king", true)
	await _wait(0.4)
	_check(_bosses(game) == 1, "первый вызов поднял босса: %d" % _bosses(game))

	# ВТОРОЕ НАЖАТИЕ НИЧЕГО НЕ ДЕЛАЕТ. Не «поднимает второго тихо» и не падает —
	# именно ничего: два боя на одной арене дерутся с одним Нормальдо и оба
	# правят заморозку потока.
	hud.call("summon_bum_king", true)
	hud.call("summon_bum_king", true)
	await _wait(0.5)
	_check(_bosses(game) == 1, "повторные — не поднимают второго: %d" % _bosses(game))

	# И чужих боссов тоже: арена одна на всех.
	hud.call("summon_club_boss", true)
	hud.call("summon_leatherhead", true)
	await _wait(0.5)
	_check(_bosses(game) == 1, "и другого босса поверх не пускает: %d" % _bosses(game))

	# ── Босс, вынутый из дерева, не роняет игру ─────────────────────────────
	# Это вторая половина той же поломки: даже если босса уберут со стороны
	# (перезагрузка сцены, «ЕЩЁ РАЗ» на экране смерти), его циклы обязаны выйти
	# сами, а не проснуться с `get_tree() == null`.
	print("── Босс вынут из дерева ──")
	var boss : Node = _first_boss(game)
	_check(boss != null, "босс на месте")
	if boss == null:
		_finish()
		return
	_check(not bool(boss.call("_alive")) or boss.is_inside_tree(),
		"пока в дереве — жив")
	game.remove_child(boss)
	await _wait(0.6)
	_check(not bool(boss.call("_alive")),
		"вынутый из дерева перестаёт считаться живым — и циклы выходят сами")
	boss.free()

	_finish()

func _bosses(game: Node) -> int:
	var n := 0
	for c in game.get_children():
		if c.get_script() == null:
			continue
		var path : String = String(c.get_script().resource_path)
		if path.ends_with("bum_king.gd") or path.ends_with("club_boss.gd") \
				or path.ends_with("leatherhead.gd") or path.ends_with("ninja_foot.gd"):
			n += 1
	return n

func _first_boss(game: Node) -> Node:
	for c in game.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("bum_king.gd"):
			return c
	return null

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

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
