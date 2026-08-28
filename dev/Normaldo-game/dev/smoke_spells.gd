extends SceneTree

# Headless-проверка спеллов, приехавших с обновлением ассетов.
#   godot --headless --path . --script res://dev/smoke_spells.gd
#
# Спелл — это лицо скина: он один отличает базовую голову от легендарной. Врущий
# спелл (не превратил, не выстрелил, не показал нарисованное) обесценивает
# покупку, за которую игрок отдал 9999 долларов.
#
# См. /Концепция/Скины.md

var _fails  : int = 0
var _checks : int = 0

# Нижняя граница числа проверок. Держать точной незачем — она ловит не «стало на
# одну меньше», а «не отработало вообще ничего».
const EXPECTED_CHECKS : int = 70

func _check(ok: bool, what: String) -> void:
	_checks += 1
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
	print("── Классика: доллары в глазах ──")
	await _test_cash_face()
	print("── Дракула: крылья ──")
	await _test_wings()
	print("── Кусс: летит лопатка ──")
	await _test_kuss_spatula()
	print("── Кулак с героя: Battletoads ──")
	await _test_big_fist()
	print("── Классика: рука с пальцем ──")
	await _test_pointing_hand()
	print("── Подмена кадра не двигает голову ──")
	await _test_head_anchor()
	print("── Тайсон: поворот ровно в точку тапа ──")
	await _test_tyson_aim()
	print("── Дракула: отжор ЛЮДЕЙ, не только бомжей ──")
	await _test_human_feast()
	print("── Спайдер: нить цвета паутины ──")
	await _test_web_color()

	print("")
	# Зелёный прогон, в котором НИЧЕГО не проверялось, — худший из возможных
	# отчётов. Ровно так и вышло: забытый импорт ассета уронил компиляцию
	# normaldo.gd целиком, каждый тест падал на первой же строке, ни один _check
	# не выполнился — и суита отрапортовала «ВСЁ ЗЕЛЁНОЕ».
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок выполнено %d из ожидаемых %d — тесты не отработали"
			% [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
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

	# «Поехало» ДЕРЖИТСЯ всё ускорение, а не мгновение: эффект длится две
	# секунды, и если лицо возвращается через треть, спелл читается как
	# мигание, а не как состояние.
	await _wait(0.8)
	_check(spr.texture == f2, "и держится, пока действует ускорение")
	_check(float(n.get("_speed_boost_remaining")) > 0.0, "ускорение и правда идёт")
	await _wait(1.6)
	_check(spr.texture == normal, "кончилось ускорение — вернулся к обычной голове")
	(e["game"] as Node).queue_free()
	await process_frame

# Кадр «доллары в глазах» — реакция на ПОПАДАНИЕ, а не на каст. Разница
# принципиальная: промахнулся мимо предмета — денег не появилось, и лицо
# меняться не должно.
func _test_cash_face() -> void:
	var e : Dictionary = await _boot("classic", 1)
	var n : Node = e["n"]
	var sp : Node = e["sp"]
	var spr : Sprite2D = (n as Node).get_node("Sprite2D")
	var normal : Texture2D = spr.texture

	# Промах: стреляем в пустоту.
	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.6)
	_check(spr.texture == normal, "промахнулся — лицо прежнее")

	# Попадание. Ждём откат: спелл с КД 2 с второй раз просто не выстрелит, и
	# тест мерил бы не лицо, а собственную нетерпеливость.
	await _wait(1.6)
	_rock(sp, (n as Node2D).position + Vector2(90.0, 0.0))
	await process_frame
	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.35)
	_check(spr.texture != normal, "попал — лицо сменилось")
	_check(spr.texture == load("res://assets/normaldo/normaldo2_cash.png"),
		"и это кадр с долларами в глазах")
	await _wait(0.7)
	_check(spr.texture == normal, "и вернулось обратно")
	(e["game"] as Node).queue_free()
	await process_frame

# «Парой за головой»: два крыла, зеркальных друг другу, ПОЗАДИ головы, и только
# на том жире, на котором они нарисованы.
func _test_wings() -> void:
	for fat in 4:
		var e : Dictionary = await _boot("dracula", fat)
		var n : Node = e["n"]
		var w : Array = n.get("_wings")
		if fat == 3:
			_check(w.size() == 2, "жир 4: крыльев ровно два (%d)" % w.size())
			if w.size() == 2:
				var l : Sprite2D = w[0]
				var r : Sprite2D = w[1]
				_check(l.scale.x < 0.0 and r.scale.x > 0.0,
					"правое — зеркало левого: %.2f и %.2f" % [l.scale.x, r.scale.x])
				_check(l.position.x < 0.0 and r.position.x > 0.0,
					"разведены по бокам головы: %.0f и %.0f" % [l.position.x, r.position.x])
				var head : Sprite2D = (n as Node).get_node("Sprite2D")
				_check(l.z_index < head.z_index and r.z_index < head.z_index,
					"лежат ЗА головой, а не поверх лица")
				# Крылья по просьбе сделаны КРУПНЕЕ головы, но потолок нужен:
				# хитбокс от них не растёт, и силуэт в полтора лейна обманывал
				# бы игрока насчёт его габаритов (то же правило, что MAX_BODY).
				var head_w : float = head.texture.get_size().x * head.scale.x
				var wing_w : float = absf(l.texture.get_size().x * l.scale.x)
				_check(wing_w < head_w * 1.5,
					"крыло не больше полутора голов: %.0f против %.0f" % [wing_w, head_w])
		else:
			_check(w.is_empty(), "жир %d: крыльев нет (%d)" % [fat + 1, w.size()])
		(e["game"] as Node).queue_free()
		await process_frame

	# Машет: угол обязан меняться сам, без каста.
	var e2 : Dictionary = await _boot("dracula", 3)
	var n2 : Node = e2["n"]
	var wing : Sprite2D = (n2.get("_wings") as Array)[0]
	var seen : Array = []
	for _i in 40:
		await process_frame
		seen.append(wing.rotation)
	var lo : float = seen.min()
	var hi : float = seen.max()
	_check(absf(hi - lo) > 0.2, "крылья машут сами: размах %.2f рад" % (hi - lo))

	# И сереют вместе с головой под невидимостью.
	n2.call("_try_fire_ability", (n2 as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.3)
	_check(wing.texture == load("res://assets/skills/dracula/wing_ghost.png"),
		"под невидимостью крылья тоже серые")
	await _wait(2.2)
	_check(wing.texture == load("res://assets/skills/dracula/wing_open.png"),
		"и вернулись в цвет")

	# Смена скина крылья убирает — иначе они останутся висеть на чужой голове.
	var save : Node = get_root().get_node_or_null("SaveData")
	save.active_skin = "classic"
	n2.call("reload_skin")
	await process_frame
	_check((n2.get("_wings") as Array).is_empty(), "сменили скин — крылья убраны")
	(e2["game"] as Node).queue_free()
	await process_frame

# Спелл называется «БРОСОК ЛОПАТКИ», и до приезда архива Кусса летел сюрикен
# ниндзя. Проверяем, что снаряд теперь — та самая лопатка.
func _test_kuss_spatula() -> void:
	var e : Dictionary = await _boot("kuss", 1)
	var n : Node = e["n"]
	var spatula : Texture2D = load("res://assets/skills/kuss/spatula.png")
	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.12)
	var found : int = _sprites_with((n as Node).get_parent(), spatula, []).size()
	_check(found >= 1, "летит лопатка, а не сюрикен (снарядов %d)" % found)

	# И поза каста у Кусса теперь есть на всех жирах.
	var missing : Array = []
	for fat in 4:
		var e2 : Dictionary = await _boot("kuss", fat)
		if (e2["n"] as Node).get("_skin_spell_tex")[fat] == null:
			missing.append(fat + 1)
		(e2["game"] as Node).queue_free()
		await process_frame
	_check(missing.is_empty(), "поза каста на всех жирах, нет на: %s" % [missing])
	(e["game"] as Node).queue_free()
	await process_frame

# Мили-спелл до сих пор бил НЕВИДИМОЙ зоной: кулак был нарисован только в позе
# каста. Проверяем, что теперь он есть на экране, что он крупнее головы — в этом
# вся отсылка к Battletoads, — и что «POWER!» печатается по попаданию, а не на
# каждый мах.
func _test_big_fist() -> void:
	for skin in ["viking", "tyson"]:
		var e : Dictionary = await _boot(skin, 1)
		var n : Node = e["n"]
		var head : Sprite2D = (n as Node).get_node("Sprite2D")
		var head_w : float = head.texture.get_size().x * head.scale.x
		n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
		await _wait(0.14)
		var fists : Array = []
		_all_sprites((n as Node).get_parent(), fists)
		var big : Sprite2D = null
		for f in fists:
			var w : float = absf((f as Sprite2D).texture.get_size().x * (f as Sprite2D).scale.x)
			if w > head_w and f != head:
				big = f
		_check(big != null, "«%s»: кулак на экране и крупнее головы (%.0f)" % [skin, head_w])
		(e["game"] as Node).queue_free()
		await process_frame

	# «POWER!» — только по попаданию.
	var power : Texture2D = load("res://assets/skills/power.png")
	var e2 : Dictionary = await _boot("viking", 1)
	var n2 : Node = e2["n"]
	n2.call("_try_fire_ability", (n2 as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.5)
	_check(_sprites_with((n2 as Node).get_parent(), power, []).is_empty(),
		"промах — «POWER!» не печатается")

	await _wait(5.0)                                   # откат мили-спелла
	for i in 3:                                        # три цели в один мах
		_rock(e2["sp"], (n2 as Node2D).position + Vector2(34.0 + i * 12.0, 0.0))
	await process_frame
	n2.call("_try_fire_ability", (n2 as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.3)
	var shown : int = _sprites_with((n2 as Node).get_parent(), power, []).size()
	_check(shown == 1, "попал — «POWER!» ровно одно, а не по слову на цель: %d" % shown)
	(e2["game"] as Node).queue_free()
	await process_frame

# У классики в кадре нет ни рук, ни оружия — «Размен» был выстрелом из ниоткуда.
func _test_pointing_hand() -> void:
	var hand : Texture2D = load("res://assets/skills/classic/hand.png")
	var e : Dictionary = await _boot("classic", 1)
	var n : Node = e["n"]
	n.call("_try_fire_ability", (n as Node2D).position + Vector2(300.0, 0.0))
	await _wait(0.12)
	var found : Array = _sprites_with((n as Node).get_parent(), hand, [])
	_check(found.size() == 1, "рука с пальцем появилась (%d)" % found.size())
	if found.size() == 1:
		var h : Sprite2D = found[0]
		_check(h.global_position.x > (n as Node2D).global_position.x,
			"и стоит со стороны выстрела: %.0f против %.0f"
				% [h.global_position.x, (n as Node2D).global_position.x])
	await _wait(0.8)
	_check(_sprites_with((n as Node).get_parent(), hand, []).is_empty(),
		"и убралась за собой")
	(e["game"] as Node).queue_free()
	await process_frame

# ── Посадка кадров-вариантов ─────────────────────────────────────────────────
# Кадр варианта нарисован в СВОЕЙ рамке. Размер мы уже приводим (POSE_K), но у
# классики «доллары в глазах» смещены ещё и на четверть ширины вбок: голова на
# подмене ПРЫГАЛА, и это читалось ровно как пролаг игры.
#
# Проверяется не картинка, а контракт: ЦЕНТР ГОЛОВЫ после подмены остаётся там
# же, где он был у обычного кадра. Меряется в тех же долях кадра, по которым
# посадка и считается, поэтому тест не зависит от конкретных цифр замера.
const ANCHOR_TOL_PX : float = 4.0

func _head_center(n: Node, variant: String) -> Vector2:
	var sm   : Node = get_root().get_node_or_null("SkinMetrics")
	var save : Node = get_root().get_node_or_null("SaveData")
	var spr  : Sprite2D = (n as Node).get_node("Sprite2D")
	var off  : Vector2 = sm.call("pose_off", save.active_skin, variant, n.get("fat_state"))
	var sz   : Vector2 = spr.texture.get_size()
	return spr.position + Vector2(off.x * sz.x * spr.scale.x, off.y * sz.y * spr.scale.y)

func _test_head_anchor() -> void:
	# Классика на всех четырёх жирах — именно на ней жалоба, и кадр «доллары в
	# глазах» у неё смещён сильнее всех.
	for fat in 4:
		var e : Dictionary = await _boot("classic", fat)
		var n : Node = e["n"]
		# Даём вертикали устояться: после смены скина спрайт ещё едет в свою
		# посадку, и мерить «где голова» на полпути значит мерить переезд.
		await _wait(0.40)
		var home : Vector2 = _head_center(n, "")
		var cash : Texture2D = load("res://assets/normaldo/normaldo%d_cash.png" % (fat + 1))
		n.call("_show_head", cash, "_cash")
		await _wait(0.40)          # покачивание успевает доехать до новой посадки
		var moved : float = _head_center(n, "_cash").distance_to(home)
		_check(moved < ANCHOR_TOL_PX,
			"жир %d: голова на подмене осталась на месте (сдвиг %.1f px)" % [fat + 1, moved])
		(e["game"] as Node).queue_free()
		await process_frame

	# И по одному самому кривому кадру у остальных: у Тайсона, Гарри и Викинга
	# поза каста смещена на четверть кадра в разные стороны.
	for skin in ["tyson", "harry_potter", "viking"]:
		var e2 : Dictionary = await _boot(skin, 1)
		var n2 : Node = e2["n"]
		var tex : Texture2D = (n2.get("_skin_spell_tex") as Array)[1]
		if tex != null:
			await _wait(0.40)
			var home2 : Vector2 = _head_center(n2, "")
			n2.call("_show_head", tex, "_spell")
			await _wait(0.40)
			var moved2 : float = _head_center(n2, "_spell").distance_to(home2)
			_check(moved2 < ANCHOR_TOL_PX,
				"%s: поза каста села на ту же голову (сдвиг %.1f px)" % [skin, moved2])
		(e2["game"] as Node).queue_free()
		await process_frame

# ── Тайсон: доворот ──────────────────────────────────────────────────────────
# Раньше угол зажимался сорока градусами, и на тап дальше — а это половина
# экрана — Тайсон бил «примерно вправо». Игрок целится в предмет, значит и
# смотреть надо в предмет.
func _test_tyson_aim() -> void:
	var e : Dictionary = await _boot("tyson", 1)
	var n : Node = e["n"]
	var spr : Sprite2D = (n as Node).get_node("Sprite2D")
	for dir in [Vector2(1.0, 0.0), Vector2(1.0, -1.0).normalized(),
			Vector2(-1.0, 0.0), Vector2(-1.0, -0.9).normalized(),
			Vector2(-1.0, 0.45).normalized()]:
		n.call("_snap_face_to", dir)
		# «Нос» спрайта: вправо по локальной оси, а при зеркале — влево.
		var nose : Vector2 = Vector2.RIGHT.rotated(spr.rotation)
		if spr.flip_h:
			nose = -nose
		_check(absf(nose.angle_to(dir)) < 0.02,
			"тап (%.2f, %.2f): смотрит ровно туда (расхождение %.1f°)"
				% [dir.x, dir.y, rad_to_deg(absf(nose.angle_to(dir)))])
		_check(absf(wrapf(spr.rotation, -PI, PI)) <= PI * 0.5 + 0.01,
			"и голова не вверх ногами (наклон %.0f°)" % rad_to_deg(spr.rotation))
	await _wait(0.5)
	_check(absf(spr.rotation) < 0.02 and not spr.flip_h,
		"после удара вернулся в обычную посадку")
	(e["game"] as Node).queue_free()
	await process_frame

# ── Дракула: «сбил ЧЕЛОВЕКА» ─────────────────────────────────────────────────
# На карточке написано «человека», а работало только на бомже. Бандит, коп и
# шаман нарисованы людьми ровно так же.
func _test_human_feast() -> void:
	var e : Dictionary = await _boot("dracula", 1)
	var n : Node = e["n"]
	var sp : Node = e["sp"]

	var thief := Area2D.new()
	thief.set_script(load("res://scripts/thief.gd"))
	sp.add_child(thief)
	await process_frame
	_check(str(n.call("_area_tag", thief)) == "thief",
		"бандита вообще опознали: тег «%s»" % str(n.call("_area_tag", thief)))

	var before : int = int(n.get("_pizza_count"))
	var fat_before : int = int(n.get("fat_state"))
	n.call("_handle_obstacle", thief)
	await process_frame
	_check(int(n.get("_pizza_count")) - before == 3,
		"и отожрал его на три пиццы (+%d)" % (int(n.get("_pizza_count")) - before))
	_check(int(n.get("fat_state")) >= fat_before, "а не похудел от удара")

	for tag in ["bum", "cop", "shaman"]:
		_check(bool(n.call("_bum_feast", tag)), "%s — тоже человек" % tag)
	_check(not bool(n.call("_bum_feast", "safe")), "а сейф — не человек")
	(e["game"] as Node).queue_free()
	await process_frame

# ── Спайдер: нить ────────────────────────────────────────────────────────────
# Белёсая нить читалась как луч: снаряд серый, а тянется от него светящаяся
# леска. Проверяем контракт «серая», а не конкретные три числа.
func _test_web_color() -> void:
	var c : Color = load("res://scripts/normaldo.gd").get("WEB_COLOR")
	var mx : float = maxf(c.r, maxf(c.g, c.b))
	var mn : float = minf(c.r, minf(c.g, c.b))
	_check(mx - mn < 0.10, "нить обесцвечена (разброс каналов %.3f)" % (mx - mn))
	_check(mx < 0.60, "и не белая (ярчайший канал %.2f)" % mx)
	_check(mx > 0.30, "но и не чёрная (ярчайший канал %.2f)" % mx)

func _all_sprites(root: Node, out: Array) -> Array:
	if root is Sprite2D and (root as Sprite2D).texture != null:
		out.append(root)
	for c in root.get_children():
		_all_sprites(c, out)
	return out
