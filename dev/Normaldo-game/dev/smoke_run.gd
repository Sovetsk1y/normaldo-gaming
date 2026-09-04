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
	# Прогон обязан быть независим от сейва: SaveData пишется на диск, и от
	# прошлого запуска мог остаться прокачанный скин с резистами. Тогда,
	# например, наручники честно разбились бы о резист Бэтмена, и тест упал бы
	# на исправном поведении. Классика резистов не имеет вовсе.
	var save0 : Node = get_root().get_node_or_null("SaveData")
	if save0:
		save0.active_skin = "classic"
		save0.skin_level  = 1
	normaldo.reload_skin()
	normaldo.call("_build_skin_runtime")
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
	print("── Итоговые барабаны ──")
	await _test_payout(game)

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
	# И она НАДЕТА. Иммунитет к замедлению — состояние, которое иначе видно
	# только в момент, когда тебя не замедлили, то есть никогда; надетая шляпа
	# отвечает «эффект ещё идёт» там, где игрок и смотрит, — на своей голове.
	# Проверяется, что вещь висит ребёнком СПРАЙТА ГОЛОВЫ: только так она едет с
	# ней и крутится на морфе жира.
	var hat : Sprite2D = normaldo.get("_hat_worn")
	_check(is_instance_valid(hat) and hat.get_parent() == normaldo.get_node("Sprite2D"),
		"шляпа мага: надета на голову")

	# Маска Кейси — неуязвимость.
	await _touch(normaldo, spawner, "casey_mask")
	_check(bool(normaldo.get("_scars_active")), "маска Кейси: неуязвимость включилась")
	var mask : Sprite2D = normaldo.get("_scars_mask")
	_check(is_instance_valid(mask) and mask.get_parent() == normaldo.get_node("Sprite2D"),
		"и тоже надета на голову")
	normaldo.call("_end_scars")

	# Оба эффекта — ДОЛГИЕ. Три секунды короче паузы между волнами: подобрал,
	# прочитал надпись — и всё кончилось, ни разу не пригодившись.
	_check(float(normaldo.CASEY_MASK_DURATION) >= 6.0
		and float(normaldo.MAGIC_HAT_DURATION) >= 6.0,
		"маска и шляпа держатся дольше волны: %.0f и %.0f с"
			% [normaldo.CASEY_MASK_DURATION, normaldo.MAGIC_HAT_DURATION])

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
	# Перед этим гасим поле и все временные щиты: мэджик бокс из прошлого шага
	# разбрасывает предметы, и подобранная маска Кейси честно съедала бы
	# наручники — тест падал на исправном поведении раз в несколько прогонов.
	await _wait(2.5)
	spawner.clear_items()
	normaldo.call("_end_scars")
	normaldo.set("_slow_immune_remaining", 0.0)
	await process_frame
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

# Окно итогов: барабаны ОБЯЗАНЫ встать тремя одинаковыми и ровно на брошенном
# множителе — иначе игрок видит одно, а на счёт приходит другое. Плашка к концу
# должна показывать умноженные числа, а сама сцена — закрыться и не остаться
# висеть поверх забега.
func _test_payout(game: Node) -> void:
	for mult in [1, 3, 5]:
		var w : Node = load("res://scripts/minigame_payout.gd").new()
		w.call("setup", 7, 4, mult, Vector2(120.0, 14.0), Vector2(180.0, 14.0))
		game.add_child(w)
		var got : Array = []
		w.connect("finished", func(m: int) -> void: got.append(m))
		# Ждём с запасом: вся сцена укладывается примерно в четыре секунды.
		var t := 0.0
		while t < 6.0 and is_instance_valid(w):
			await process_frame
			t += 1.0 / 60.0
		_check(not is_instance_valid(w), "×%d: окно итогов закрылось само" % mult)
		_check(got == [mult], "×%d: сигнал finished принёс тот же множитель: %s" % [mult, got])

	# Финальный такт — печать SLAKE BAKE: крупно и ПО ЦЕНТРУ. Раньше её ставили
	# сами мини-игры, мелко над головой и каждая на своём такте, — игрок читал её
	# как случайную наклейку. Проверяем именно размер и место: штамп, вылезающий
	# на пол-экрана сбоку, формально «есть», а работу не делает.
	var w3 : Node = load("res://scripts/minigame_payout.gd").new()
	w3.call("setup", 7, 4, 3, Vector2(120.0, 14.0), Vector2(180.0, 14.0))
	game.add_child(w3)
	var slake : Texture2D = load("res://assets/normaldo/slakebake.png")
	var stamp : Control = null
	var ts := 0.0
	while ts < 8.0 and is_instance_valid(w3):
		await process_frame
		ts += 1.0 / 60.0
		var f : Control = _find_texture_rect(w3, slake)
		if f != null and f.scale.x > 0.9:
			stamp = f
			break
	_check(stamp != null, "печать SLAKE BAKE появилась")
	if stamp != null:
		var vp : Vector2 = get_root().get_visible_rect().size
		var mid : Vector2 = stamp.position + stamp.size * 0.5
		# «Крупно» на широком низком экране меряется ПО ВЫСОТЕ: кадр почти
		# квадратный, и требовать половину ширины значило бы требовать штамп,
		# вылезающий за верх и низ.
		_check(stamp.size.y > vp.y * 0.85,
			"и она крупная: %.0f px в высоту при экране %.0f" % [stamp.size.y, vp.y])
		_check(mid.distance_to(vp * 0.5) < 12.0,
			"и стоит по центру: (%.0f, %.0f) против (%.0f, %.0f)"
				% [mid.x, mid.y, vp.x * 0.5, vp.y * 0.5])
	while is_instance_valid(w3):
		await process_frame

	# Отдельно — что именно встало на барабанах. Ждём остановки и читаем ленту.
	var w2 : Node = load("res://scripts/minigame_payout.gd").new()
	w2.call("setup", 7, 4, 4, Vector2(120.0, 14.0), Vector2(180.0, 14.0))
	game.add_child(w2)
	var t2 := 0.0
	while t2 < 2.6:
		await process_frame
		t2 += 1.0 / 60.0
	var faces : Array = []
	for i in 3:
		faces.append(String(w2.call("visible_face", i)))
	_check(faces == ["×4", "×4", "×4"],
		"в окошках стоит ровно выпавший множитель: %s" % [faces])
	# Числа прокручиваются позже барабанов, поэтому ждём событие, а не таймер:
	# фиксированная пауза развалилась бы от любой правки длительностей.
	var pl : Label = w2.get("_pizza_lbl")
	var dl : Label = w2.get("_dollar_lbl")
	var grown := false
	var t3 := 0.0
	while t3 < 6.0 and is_instance_valid(w2):
		if int(pl.text) == 28 and int(dl.text) == 16:
			grown = true
			break
		await process_frame
		t3 += 1.0 / 60.0
	_check(grown, "плашка досчитала до умноженного: %s пицц, %s $" % [pl.text, dl.text])
	if is_instance_valid(w2):
		w2.queue_free()
	await process_frame

func _find_texture_rect(root: Node, tex: Texture2D) -> Control:
	if root is TextureRect and (root as TextureRect).texture == tex:
		return root
	for c in root.get_children():
		var f := _find_texture_rect(c, tex)
		if f != null:
			return f
	return null
