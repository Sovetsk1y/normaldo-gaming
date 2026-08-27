extends SceneTree

# Headless-проверка спеллов, приехавших с обновлением ассетов.
#   godot --headless --path . --script res://dev/smoke_spells.gd
#
# Спелл — это лицо скина: он один отличает базовую голову от легендарной. Врущий
# спелл (не превратил, не выстрелил, не показал нарисованное) обесценивает
# покупку, за которую игрок отдал 9999 долларов.
#
# См. /Концепция/Скины.md

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Классика: «Размен» ──")
	await _test_dollar_shot()
	print("── Пират: ГААР и флаг по жиру ──")
	await _test_pirate_flair()
	print("── Дракула: серый призрак ──")
	await _test_dracula_ghost()
	print("── Очки: поза каста в два кадра ──")
	await _test_glasses_pose()

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _boot(skin: String, fat: int = 0) -> Dictionary:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var save     : Node = get_root().get_node_or_null("SaveData")
	spawner.clear_items()
	save.active_skin = skin
	save.skin_level  = 10
	normaldo.reload_skin()
	await process_frame
	normaldo.call("_build_skin_runtime")
	normaldo.set("fat_state", fat)
	normaldo.call("_apply_skin_to_sprite")
	await process_frame
	return { "game": game, "n": normaldo, "sp": spawner }

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0

# Предмет-препятствие рядом с головой, чтобы снаряд гарантированно в него попал.
func _rock(spawner: Node, pos: Vector2) -> Area2D:
	var rock := Area2D.new()
	rock.set_script(preload("res://scripts/hazard_item.gd"))
	rock.set("kind", "safe")
	rock.set("speed", 0.0)
	rock.position = pos
	spawner.add_child(rock)
	return rock

func _count_group(node: Node, group: String) -> int:
	return get_root().get_tree().get_nodes_in_group(group).size()

# Спрайты, которые скин кладёт НЕ в себя, а рядом — надпись пирата летит в
# родителе, чтобы не наследовать масштаб головы.
func _sprites_with(root: Node, tex: Texture2D, out: Array) -> Array:
	if root is Sprite2D and (root as Sprite2D).texture == tex:
		out.append(root)
	for c in root.get_children():
		_sprites_with(c, tex, out)
	return out

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Главное обещание спелла: во что попал — то стало ДОЛЛАРОМ. Не пиццей: у
# «Трансформуса» мага монетка бросается, и если тем же обработчиком обслужить
# классику, половина выстрелов будет читаться как осечка.
func _test_dollar_shot() -> void:
	var e : Dictionary = await _boot("classic")
	var n : Node = e["n"]
	var sp : Node = e["sp"]

	# Автолоад по имени тут не виден: godot --script компилирует этот файл
	# РАНЬШЕ, чем поднимаются автолоады.
	var skills : Node = get_root().get_node_or_null("SkinSkills")
	var ab : Dictionary = skills.call("get_ability", "classic")
	_check(String(ab.get("id", "")) == "dollar_shot",
		"у классики спелл «%s»" % ab.get("label", ""))
	_check(is_equal_approx(float(ab.get("cd", 0.0)), 2.0),
		"откат 2 секунды: %.1f" % ab.get("cd", 0.0))

	var dollars_before : int = _count_group(e["game"], "dollar")
	var rock := _rock(sp, (n as Node2D).position + Vector2(90.0, 0.0))
	await process_frame
	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.6)

	_check(not is_instance_valid(rock), "препятствие разменяно")
	var got : int = _count_group(e["game"], "dollar") - dollars_before
	_check(got == 1, "на его месте ровно один доллар: %d" % got)

	# И это именно доллар, а не пицца с другим ярлыком.
	var pizzas := 0
	for d in get_root().get_tree().get_nodes_in_group("dollar"):
		if bool(d.get("is_eatable")):
			pizzas += 1
	_check(pizzas == 0, "и он не съедобный: пицц среди долларов %d" % pizzas)

	(e["game"] as Node).queue_free()
	await process_frame

# «На 3 жире птица орёт ГААР, на 4 — флаг.» Значит на 1 и 2 не должно быть
# ничего: иначе жир перестаёт что-либо значить.
func _test_pirate_flair() -> void:
	var gaar : Texture2D = load("res://assets/skills/pirate/gaar.png")
	var flag : Texture2D = load("res://assets/skills/pirate/flag.png")
	for fat in 4:
		var e : Dictionary = await _boot("pirate", fat)
		var n : Node = e["n"]
		n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
		await _wait(0.25)
		var host : Node = (n as Node).get_parent()
		var g : int = _sprites_with(host, gaar, []).size()
		var f : int = _sprites_with(host, flag, []).size()
		match fat:
			2: _check(g == 1 and f == 0, "жир 3: вылетела надпись ГААР (надписей %d, флагов %d)" % [g, f])
			3: _check(f == 1 and g == 0, "жир 4: развернулся флаг (надписей %d, флагов %d)" % [g, f])
			_: _check(g == 0 and f == 0, "жир %d: молчит (надписей %d, флагов %d)" % [fat + 1, g, f])
		(e["game"] as Node).queue_free()
		await process_frame

	# Надпись обязана исчезнуть сама: она вылетает каждые 3 секунды отката, и
	# оставшись на экране, за забег накопится в стопку.
	var e2 : Dictionary = await _boot("pirate", 2)
	var n2 : Node = e2["n"]
	n2.call("_try_fire_ability", (n2 as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.2)
	_check(_sprites_with((n2 as Node).get_parent(), gaar, []).size() == 1, "надпись на экране")
	await _wait(1.2)
	_check(_sprites_with((n2 as Node).get_parent(), gaar, []).size() == 0,
		"и убралась за собой")
	(e2["game"] as Node).queue_free()
	await process_frame

# Невидимость Дракулы теперь НАРИСОВАНА. Проверяем, что голова действительно
# меняет кадр, а не просто бледнеет, и что она возвращается обратно.
func _test_dracula_ghost() -> void:
	var e : Dictionary = await _boot("dracula", 1)
	var n : Node = e["n"]
	var spr : Sprite2D = (n as Node).get_node("Sprite2D")
	var normal : Texture2D = spr.texture

	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.3)
	_check(spr.texture != normal, "под невидимостью кадр другой")
	_check(spr.texture == n.get("_skin_ghost_tex")[1], "и это призрачный кадр")
	_check(spr.modulate.a > 0.5,
		"рисунок при этом видно: альфа %.2f" % spr.modulate.a)

	# Жевать под невидимостью можно — для этого нарисован отдельный серый кадр.
	n.set("_nearby_pizzas", 1)
	n.call("_update_mouth")
	await process_frame
	_check(spr.texture == n.get("_skin_ghost_eat_tex")[1],
		"жуёт тоже призрачным кадром")
	n.set("_nearby_pizzas", 0)

	await _wait(2.2)
	_check(spr.texture == normal, "после невидимости голова вернулась")
	_check(not bool(n.get("_ghost_active")), "признак призрака снят")
	(e["game"] as Node).queue_free()
	await process_frame

	# Серый кадр нарисован на КАЖДОЕ состояние жира: спелл не должен пропадать
	# на толстом Дракуле, где его как раз и кастуют чаще всего.
	var missing : Array = []
	for fat in 4:
		var e2 : Dictionary = await _boot("dracula", fat)
		var n2 : Node = e2["n"]
		if n2.get("_skin_ghost_tex")[fat] == null or n2.get("_skin_ghost_eat_tex")[fat] == null:
			missing.append(fat + 1)
		(e2["game"] as Node).queue_free()
		await process_frame
	_check(missing.is_empty(), "призрачные кадры есть на всех жирах, нет на: %s" % [missing])

# У Очков каст нарисован двумя кадрами: «пьёт банку» → «поехало». Одним кадром
# спелл не читается, поэтому проверяем, что играются оба и голова возвращается.
func _test_glasses_pose() -> void:
	var e : Dictionary = await _boot("glasses", 1)
	var n : Node = e["n"]
	var spr : Sprite2D = (n as Node).get_node("Sprite2D")
	var normal : Texture2D = spr.texture
	var f1 : Texture2D = n.get("_skin_spell_tex")[1]
	var f2 : Texture2D = n.get("_skin_spell2_tex")[1]
	_check(f1 != null and f2 != null, "оба кадра позы подгрузились")

	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.12)
	_check(spr.texture == f1, "первый кадр: пьёт банку")
	await _wait(0.34)
	_check(spr.texture == f2, "второй кадр: поехало")
	await _wait(0.5)
	_check(spr.texture == normal, "и вернулся к обычной голове")
	(e["game"] as Node).queue_free()
	await process_frame
