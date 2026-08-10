extends SceneTree

# Headless прогон настоящего забега.
#   godot --headless --path . --script res://dev/smoke_run.gd
#
# smoke_items.gd проверяет предметы поштучно, этот — что они живут внутри
# реальной сцены: спавнер крутит все шесть фаз кампании, каждый новый эффект
# применяется к настоящей голове, а множитель мини-игр реально доначисляет
# добычу. Ошибки движка ловятся грепом по stderr прогона.

const EFFECT_ITEM := preload("res://scripts/effect_item.gd")
const MAGIC_BOX   := preload("res://scripts/magic_box.gd")

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

	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var bg       : Node = game.get_node_or_null("Background")
	if normaldo == null or spawner == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Старт забега ──")
	normaldo.enable_input()
	normaldo.set_dev_immortal(true)     # смерть проверяем отдельно, в самом конце
	spawner.campaign_mode = true
	spawner.set_process(true)
	if bg:
		bg.start_scrolling()
	_check(true, "кампания запущена")

	# Фазы кампании: живём в каждой по 6 c и перескакиваем дальше. Дольше не
	# нужно — нас интересуют спавн и переходы, а не полная длительность.
	print("── Фазы кампании ──")
	for phase in 5:
		await _wait(6.0)
		var alive := _count_items(spawner)
		_check(alive > 0, "фаза %d: на экране %d предметов" % [phase, alive])
		if spawner.has_method("dev_skip_to_next_phase"):
			spawner.dev_skip_to_next_phase()
		await process_frame

	print("── Эффекты предметов ──")
	# Гасим живой поток: иначе случайная бочка попадает по голове ровно в тот
	# кадр, когда мы проверяем маску Кейси, маска честно поглощает удар и
	# слетает — тест падал бы на исправном поведении.
	spawner.clear_items()
	await process_frame
	await _test_effects(normaldo, spawner)

	print("── Множитель мини-игр ──")
	await _test_multiplier(normaldo)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0

func _count_items(spawner: Node) -> int:
	var n := 0
	for c in spawner.get_children():
		if c is Node2D:
			n += 1
	return n

# Каждый эффект применяем через настоящий диспетчер столкновений, а не вызовом
# метода напрямую — иначе тест разошёлся бы с игрой при первой же правке
# порядка веток в _on_area_entered.
func _touch(normaldo: Node, spawner: Node, kind: String) -> void:
	var node := Area2D.new()
	node.set_script(EFFECT_ITEM)
	node.set("kind", kind)
	node.position = normaldo.position
	spawner.add_child(node)
	await process_frame
	normaldo.call("_on_area_entered", node)
	await process_frame

func _test_effects(normaldo: Node, spawner: Node) -> void:
	# Банка колы — ускорение.
	await _touch(normaldo, spawner, "cola")
	_check(float(normaldo.get("_speed_boost_remaining")) > 0.0, "банка колы: ускорение включилось")

	# Шляпа мага — иммунитет к замедлению: банан после неё не тормозит.
	await _touch(normaldo, spawner, "magic_hat")
	normaldo.call("apply_slow", 4.0)
	_check(float(normaldo.get("_slow_remaining")) <= 0.0, "шляпа мага: замедление погашено")

	# Маска Кейси — неуязвимость.
	await _touch(normaldo, spawner, "casey_mask")
	_check(bool(normaldo.get("_scars_active")), "маска Кейси: неуязвимость включилась")
	normaldo.call("_end_scars")

	# Песочные часы — замедление мира. Сбрасываем множитель явно: за 30 c
	# прогона фаз голова могла подобрать часы сама, и тогда «стало меньше, чем
	# было» ничего не проверяет.
	spawner.set("world_speed_mult", 1.0)
	var factor : float = float(spawner.get("SLOW_MO_FACTOR"))
	await _touch(normaldo, spawner, "hourglass")
	await process_frame
	_check(is_equal_approx(float(spawner.get("world_speed_mult")), factor),
		"песочные часы: мир замедлился до ×%.2f" % factor)

	# Жетон автомата — начисляется сразу в сейв. Автолоады при запуске через
	# --script в глобальной области ещё не зарегистрированы, поэтому берём узел.
	var save : Node = get_root().get_node_or_null("SaveData")
	var tokens_before : int = int(save.get("tokens")) if save else -1
	await _touch(normaldo, spawner, "casino_chip")
	_check(save != null and int(save.get("tokens")) == tokens_before + 1, "жетон: +1 в сейве")

	# Чек лузера — обнуляет доллары забега.
	normaldo.set("_dollars", 25)
	await _touch(normaldo, spawner, "loser_ticket")
	_check(int(normaldo.get("_dollars")) == 0, "чек лузера: доллары обнулены")

	# Чёрный туз — сжигает жир до минимума.
	normaldo.set("fat_state", 2)
	normaldo.set("_pizza_count", 70)
	await _touch(normaldo, spawner, "black_ace")
	await _wait(0.2)
	_check(int(normaldo.get("fat_state")) == 0, "чёрный туз: жир сгорел до минимума")

	# Мэджик бокс — раздаёт предметы.
	var box := Area2D.new()
	box.set_script(MAGIC_BOX)
	box.position = normaldo.position
	spawner.add_child(box)
	await process_frame
	var before_count := _count_items(spawner)
	normaldo.call("_on_area_entered", box)
	await _wait(1.2)
	_check(_count_items(spawner) > before_count, "мэджик бокс: выплюнул предметы")

	# Наручники — энд гейм. Снимаем dev-бессмертие, иначе предмет их уважает.
	await _wait(2.5)
	normaldo.set_dev_immortal(false)
	await _touch(normaldo, spawner, "handcuffs")
	_check(bool(normaldo.get("_dead")), "наручники: энд гейм")

func _test_multiplier(normaldo: Node) -> void:
	# Учёт добычи: набрали N, бросок ×M — на счету должно стать N × M.
	normaldo.set("_dead", false)
	normaldo.call("begin_loot_tally")
	var pizzas_before : int = int(normaldo.get("_total_pizza_count"))
	for i in 10:
		normaldo.call("_eat_pizza")
	var tally : Vector2i = normaldo.call("loot_tally")
	_check(tally.x == 10, "учтено 10 пицц за мини-игру")

	var extra : Vector2i = normaldo.call("award_loot_tally", 3)
	_check(extra.x == 20, "множитель ×3 доначислил 20 пицц")
	_check(int(normaldo.get("_total_pizza_count")) == pizzas_before + 30,
		"итого за мини-игру ×3: 10 → 30")

	# Повторный вызов не должен начислять ничего.
	var again : Vector2i = normaldo.call("award_loot_tally", 5)
	_check(again == Vector2i.ZERO, "повторное начисление не срабатывает")
