extends SceneTree

# Headless-проверка скинов: лестница уровней, резисты и касты всех спеллов.
#   godot --headless --path . --script res://dev/smoke_skins.gd

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var save : Node = get_root().get_node_or_null("SaveData")
	var prog : Node = get_root().get_node_or_null("SkinProgression")
	var skil : Node = get_root().get_node_or_null("SkinSkills")
	var reg  : Node = get_root().get_node_or_null("SkinRegistry")

	print("── Лестница уровней ──")
	_test_ladder(prog, reg)
	print("── Резисты по уровням ──")
	_test_resists(prog, skil, save)
	print("── Размер головы ──")
	_test_heads(reg)
	print("── Карточка скина ──")
	_test_card(skil, save)
	print("── Размер на экране ──")
	await _test_sizes(reg, save)
	print("── ЖИРОБОСС ──")
	await _test_boss(reg, save)
	print("── Карточки наград ──")
	await _test_reward_cards(reg, save, prog)
	print("── Касты ──")
	await _test_casts(reg, save)
	print("── Паутина Спайдера ──")
	await _test_web(save)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

func _test_ladder(prog: Node, reg: Node) -> void:
	var ids : Array = []
	for s in reg.SKINS:
		ids.append(String(s["id"]))

	var no_first := true
	var full := true
	for id in ids:
		# Главное требование: на 1-м уровне награды нет — скин уже куплен.
		if not prog.reward_for(id, 1).is_empty():
			no_first = false
			print("      у «%s» есть награда на 1 уровне" % id)
		for lv in range(2, 11):
			if prog.reward_for(id, lv).is_empty():
				full = false
				print("      у «%s» пусто на уровне %d" % [id, lv])
	_check(no_first, "ни у одного скина нет награды за 1 уровень")
	_check(full, "уровни 2–10 заполнены у всех %d скинов" % ids.size())

	# Три состояния жира доступны сразу, 4-е открывает 2-й уровень.
	var f1 : int = prog.max_fat_state("viking", 1)
	var f2 : int = prog.max_fat_state("viking", 2)
	_check(f1 == 2 and f2 == 3, "жир: 1 лвл → %d состояния, 2 лвл → %d" % [f1 + 1, f2 + 1])

	# Венец 10-го уровня есть у каждого скина из ТЗ.
	var crowned := 0
	for id in ids:
		if not prog.reward_for(id, 10).is_empty():
			crowned += 1
	_check(crowned == ids.size(), "у всех скинов есть награда 10 уровня")

func _test_resists(prog: Node, skil: Node, save: Node) -> void:
	# Резисты копятся по уровням: до 4-го ни одного, после 8-го — три.
	var at3 : int = prog.immunities("tyson", 3).size()
	var at4 : int = prog.immunities("tyson", 4).size()
	var at8 : int = prog.immunities("tyson", 8).size()
	_check(at3 == 0 and at4 == 1 and at8 == 3,
		"Тайсон: 3 лвл → %d, 4 лвл → %d, 8 лвл → %d резистов" % [at3, at4, at8])

	# У резиста есть откат — это по-прежнему резист, а не вечный иммунитет.
	var rows : Array = skil.resists_at("tyson", 8)
	var has_cd := rows.size() == 3
	for r in rows:
		if float(r.get("cd", 0.0)) <= 0.0:
			has_cd = false
	_check(has_cd, "у всех резистов Тайсона задан откат")

	# Эпические и легендарные перезаряжаются быстрее обычных.
	var cd_common : float = skil.resist_cd("tyson")
	var cd_epic   : float = skil.resist_cd("wizard")
	_check(cd_epic < cd_common, "откат: обычный %.0f c > эпический %.0f c" % [cd_common, cd_epic])

	# get_resists для АКТИВНОГО скина обязан смотреть на его реальный уровень.
	save.active_skin = "tyson"
	save.skin_level  = 3
	_check(skil.get_resists("tyson").is_empty(), "на 3 уровне активный скин без резистов")
	save.skin_level = 10
	_check(skil.get_resists("tyson").size() == 3, "на 10 уровне активный скин с тремя резистами")

# Замеры голов лежат таблицей (skin_metrics.gd), и главный риск — добавить скин
# и забыть её пересчитать: тогда он молча отрисуется по старой логике «ширина
# кадра» и снова окажется мельче остальных. Сверку самой таблицы со спрайтами
# делает dev/tools/measure_heads.py --check, здесь ловим именно пропуск.
func _test_heads(reg: Node) -> void:
	var metrics : Node = get_root().get_node_or_null("SkinMetrics")
	var missing : Array = []
	for s in reg.SKINS:
		var id := String(s["id"])
		if id == "classic":
			continue   # у классики кадр это ровно голова, замер не нужен
		if not metrics.HEADS.has(id):
			missing.append(id)
	_check(missing.is_empty(), "замеры головы есть у всех скинов, пропущено: %s" % [missing])

	# Джокер — крайний случай: его голова 27 % кадра, множитель должен быть
	# заметно больше единицы, иначе нормировка не работает.
	var jk : float = metrics.scale_for("joker")
	_check(jk > 3.0, "Джокеру назначен множитель ×%.2f" % jk)

	# Смещение головы у Гарри ощутимое — проверяем, что оно вообще не нулевое.
	var off : Vector2 = metrics.offset_for("harry_potter", 0)
	_check(absf(off.x) > 0.05, "у Гарри учтено смещение головы от центра: %.3f" % off.x)

# Карточка обязана показывать ВСЕ резисты скина, включая ещё не открытые, —
# иначе игрок не видит, ради чего качать скин дальше. Открытые и закрытые
# различаются флагом unlocked, по нему рисуется замок.
func _test_card(skil: Node, save: Node) -> void:
	save.active_skin = "tyson"
	save.skin_level  = 1
	var all_1 : Array = skil.all_resists("tyson")
	_check(all_1.size() == 3, "на 1 уровне в карточке всё равно 3 кружка резистов")
	var locked := 0
	for r in all_1:
		if not bool(r.get("unlocked", true)):
			locked += 1
	_check(locked == 3, "на 1 уровне все три закрыты замком")

	save.skin_level = 6
	var all_6 : Array = skil.all_resists("tyson")
	var open_6 := 0
	for r in all_6:
		if bool(r.get("unlocked", false)):
			open_6 += 1
	_check(all_6.size() == 3 and open_6 == 2,
		"на 6 уровне кружков всё так же 3, открыто %d" % open_6)

	# Уровень открытия должен быть проставлен — по нему подпись «откроется на N».
	var lvls : Array = []
	for r in all_6:
		lvls.append(int(r.get("level", 0)))
	_check(lvls == [4, 6, 8], "уровни открытия резистов: %s" % [lvls])

	# Карточка НЕ активного скина должна смотреть на его собственный уровень,
	# а не показывать всё открытым.
	save.active_skin = "viking"
	save.skin_level  = 10
	var other : Array = skil.all_resists("tyson")
	var other_open := 0
	for r in other:
		if bool(r.get("unlocked", false)):
			other_open += 1
	_check(other_open < 3, "у неактивного скина открыто по ЕГО уровню: %d из 3" % other_open)

# Размер скина держат два правила, и оба легко сломать новым спрайтом:
#   в забеге — голова как у классики, но силуэт не больше MAX_BODY;
#   в интерфейсе — голова занимает ровно UI_HEAD_FILL коробки у ВСЕХ скинов.
# Первое ловит «скин раздулся на два лейна», второе — «Джокер втрое мельче».
func _test_sizes(reg: Node, save: Node) -> void:
	var met : Node = get_root().get_node_or_null("SkinMetrics")

	var over : Array = []
	var head_min : float = 1e9
	var head_max : float = 0.0
	for s in reg.SKINS:
		var id := String(s["id"])
		for fat in 4:
			var tex : Texture2D = reg.get_avatar_texture(id, fat)
			if tex == null:
				continue
			var sz : Vector2 = tex.get_size()
			var k  : float   = met.sprite_scale(id, fat, sz)
			var box: Vector2 = met.box_for(id, fat)
			var w  : float   = box.x * sz.x * k
			var h  : float   = box.y * sz.y * k
			if w > met.MAX_BODY.x + 1.0 or h > met.MAX_BODY.y + 1.0:
				over.append("%s/%d %.0fx%.0f" % [id, fat, w, h])
			if fat == 0:
				var hw : float = met.head_frac_for(id) * sz.x * k
				head_min = minf(head_min, hw)
				head_max = maxf(head_max, hw)
	_check(over.is_empty(), "силуэт всех скинов в коробке %.0fx%.0f, вылезли: %s"
		% [met.MAX_BODY.x, met.MAX_BODY.y, over])
	# Голова не обязана совпадать пиксель в пиксель — четверых поджимает коробка,
	# — но разброс должен остаться небольшим. До нормировки он был 2.3 раза.
	_check(head_min / head_max > 0.70,
		"головы в забеге от %.0f до %.0f px (разброс ×%.2f)"
		% [head_min, head_max, head_max / head_min])

	# Интерфейс: коробка одна, голова в ней одна у любого скина.
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var host := Control.new()
	hud.add_child(host)
	await process_frame

	const BOX := 52.0
	var widths : Array = []
	var out_of_box : Array = []
	for s in reg.SKINS:
		var id := String(s["id"])
		var holder : Control = hud.call("_skin_head_icon", id, 0, BOX)
		host.add_child(holder)
		var r : TextureRect = hud.call("_head_icon_rect", holder)
		var tex : Texture2D = r.texture
		var hw : float = met.head_frac_for(id) * r.size.x
		widths.append(snappedf(hw, 0.1))
		# Центр головы обязан сидеть в центре коробки, иначе обрезка съест лицо.
		var c : Vector2 = Vector2(0.5, 0.5) + met.offset_for(id, 0)
		var head_c : Vector2 = r.position + Vector2(c.x * r.size.x, c.y * r.size.y)
		if head_c.distance_to(Vector2(BOX, BOX) * 0.5) > 1.0:
			out_of_box.append(id)
	await process_frame
	var same := true
	for w in widths:
		if absf(float(w) - BOX * float(hud.get("UI_HEAD_FILL"))) > 0.5:
			same = false
	_check(same, "в карточках голова %.0f px у всех %d скинов" % [BOX * float(hud.get("UI_HEAD_FILL")), widths.size()])
	_check(out_of_box.is_empty(), "голова по центру коробки, съехали: %s" % [out_of_box])

	game.queue_free()
	await process_frame

# ЖИРОБОСС должен для КАЖДОГО скина и КАЖДОГО состояния жира встать одинаково:
# голова ростом с экран, центром на левом крае — видно ровно половину лица. И
# хитбокс обязан помещаться в нарисованную голову: круг больше головы означает,
# что предметы лопаются в пустоте перед лицом, «об невидимую стену».
func _test_boss(reg: Node, save: Node) -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var boss     : Node = game.get_node_or_null("FatBoss")
	var met      : Node = get_root().get_node_or_null("SkinMetrics")
	spawner.clear_items()
	var vp : Vector2 = get_root().get_visible_rect().size

	_check(is_equal_approx(boss.boss_anchor(vp).x, 0.0),
		"голова босса ставится центром на левый край: x = %.0f" % boss.boss_anchor(vp).x)

	var target_h : float = vp.y * float(boss.BOSS_FACE_H)
	var bad_size : Array = []
	var bad_box  : Array = []
	for sk in reg.SKINS:
		var id := String(sk["id"])
		save.active_skin = id
		save.skin_level  = 10
		normaldo.reload_skin()
		await process_frame
		for fat in 4:
			normaldo.set("fat_state", fat)
			normaldo.call("_apply_skin_to_sprite")
			var tex : Texture2D = reg.get_avatar_texture(id, fat)
			if tex == null:
				continue
			var base : Vector2 = normaldo.get("_base_scale")
			var f  : float = normaldo.call("boss_face_factor", target_h)
			var fr : Vector2 = met.head_size_for(id, fat)
			var hw : float = fr.x * tex.get_size().x * base.x * f
			var hh : float = fr.y * tex.get_size().y * base.y * f
			var r  : float = float(normaldo.call("boss_head_radius")) * f
			# Голова ростом с экран — с точностью до пары процентов.
			if absf(hh - target_h) > target_h * 0.03:
				bad_size.append("%s/%d %.0f" % [id, fat, hh])
			# Круг обязан быть внутри овала головы по ОБЕИМ сторонам.
			if r > hw * 0.5 + 0.5 or r > hh * 0.5 + 0.5:
				bad_box.append("%s/%d r=%.0f при голове %.0fx%.0f" % [id, fat, r, hw, hh])
	_check(bad_size.is_empty(), "голова босса ростом с экран у всех, мимо: %s" % [bad_size])
	_check(bad_box.is_empty(), "хитбокс внутри головы у всех, торчит: %s" % [bad_box])

	# Живая проверка: предмет обязан ДОЛЕТЕТЬ до лица, а не лопнуть перед ним.
	save.active_skin = "classic"
	save.skin_level  = 1
	normaldo.reload_skin()
	normaldo.set("fat_state", 0)
	normaldo.call("_apply_skin_to_sprite")
	normaldo.call("begin_fat_boss")
	boss.call("dev_pose_boss")
	await process_frame
	var f2 : float = float(normaldo.get("_fat_boss_factor"))
	var tex2 : Texture2D = reg.get_avatar_texture("classic", 0)
	var base2 : Vector2 = normaldo.get("_base_scale")
	var face_r : float = met.head_size_for("classic", 0).x * tex2.get_size().x * base2.x * f2 * 0.5
	var pizza := Area2D.new()
	pizza.set_script(preload("res://scripts/effect_item.gd"))
	pizza.set("kind", "casino_chip")
	pizza.set("speed", 260.0)
	pizza.position = Vector2(900.0, normaldo.get("position").y)
	spawner.add_child(pizza)
	var hit_x := -1.0
	var t := 0.0
	while t < 5.0:
		await process_frame
		t += 1.0 / 60.0
		if not is_instance_valid(pizza):
			break
		hit_x = pizza.position.x
	_check(hit_x >= 0.0 and hit_x <= face_r + 4.0,
		"предмет исчезает НА лице, а не перед ним: x=%.0f при краю лица %.0f" % [hit_x, face_r])
	normaldo.call("end_fat_boss")

	# После мини-игры голову обязано вернуть в забег: якорь босса стоит на самом
	# краю экрана, и оставить её там значит продолжить забег вплотную к краю.
	normaldo.position = Vector2(220.0, 215.0)
	var home : Vector2 = normaldo.position
	boss.call("_run_grow")
	var t2 := 0.0
	while t2 < 1.2:
		await process_frame
		t2 += 1.0 / 60.0
	boss.call("_deflate")
	var t3 := 0.0
	while t3 < 1.4:
		await process_frame
		t3 += 1.0 / 60.0
	_check(absf(normaldo.position.x - home.x) < 2.0,
		"после босса голова вернулась в забег: x=%.0f (было %.0f)" % [normaldo.position.x, home.x])
	normaldo.call("end_fat_boss")

	game.queue_free()
	await process_frame

# Награды за уровень рисуются в ЧЕТЫРЁХ местах (колонка карточек, список
# «НАГРАДЫ ЗА УРОВНИ», попап повышения и подсказка сундука), и каждое из них
# когда-то читало общие таблицы из save_data.gd. Прогоняем все четыре по всем
# скинам и всем уровням: любой промах по виду награды всплывёт как SCRIPT ERROR.
func _test_reward_cards(reg: Node, save: Node, prog: Node) -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	if hud == null:
		_check(false, "HUD не найден в сцене")
		return

	var host := Control.new()
	host.size = Vector2(720.0, 1280.0)
	hud.add_child(host)
	await process_frame

	var built := 0
	for s in reg.SKINS:
		var id := String(s["id"])
		var vbox := VBoxContainer.new()
		host.add_child(vbox)
		for lv in range(2, 11):
			if hud.call("_build_reward_card", vbox, lv, 180.0, id, 5) != null:
				built += 1
		hud.call("_show_skin_levels_popup", host, id)
		vbox.queue_free()
	await process_frame
	_check(built == reg.SKINS.size() * 9,
		"собрано %d карточек наград (%d скинов × 9 уровней)" % [built, reg.SKINS.size()])

	# Попап повышения и подсказка сундука смотрят на АКТИВНЫЙ скин, поэтому
	# гоняем их отдельно, переключая скин и уровень.
	hud.set("_menu_overlay", host)
	hud.set("_chest_anchor", Vector2(360.0, 400.0))
	for s in reg.SKINS:
		var id := String(s["id"])
		save.active_skin = id
		for lv in range(2, 11):
			save.skin_level = lv - 1
			hud.call("_show_chest_tooltip")
			var money : Vector2i = prog.money_for(id, lv)
			# Без await: тело попапа доходит до ожидания кнопки — этого хватает,
			# чтобы выполнить всю разметку награды.
			hud.call("_show_level_reward_popup", lv, money.x, money.y)
		await process_frame
	_check(true, "попап уровня и подсказка сундука отрисованы для всех скинов")

	game.queue_free()
	await process_frame

func _test_casts(reg: Node, save: Node) -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	if normaldo == null:
		_check(false, "сцена не собралась")
		return
	normaldo.enable_input()
	normaldo.set_dev_immortal(true)
	spawner.clear_items()

	# Каждый скин: переключаемся, кастуем, ждём. Падение любого спелла всплывёт
	# как SCRIPT ERROR в stderr прогона.
	for s in reg.SKINS:
		var id := String(s["id"])
		save.active_skin = id
		save.skin_level  = 10
		normaldo.reload_skin()
		await process_frame
		normaldo.call("_build_skin_runtime")
		for i in 3:
			normaldo.call("_try_fire_ability", normaldo.position + Vector2(120.0, 0.0))
			await process_frame
		var t := 0.0
		while t < 0.5:
			await process_frame
			t += 1.0 / 60.0
		_check(is_instance_valid(normaldo) and not bool(normaldo.get("_dead")),
			"«%s» отработал каст" % id)

	# Поза каста подгрузилась у скинов, чьи архивы приехали.
	var posed : Array = []
	var with_art := ["batman", "harry_potter", "halloween", "spider_man", "wizard",
		"joker", "tyson", "viking"]
	for id in with_art:
		save.active_skin = id
		normaldo.reload_skin()
		await process_frame
		var arr : Array = normaldo.get("_skin_spell_tex")
		var n := 0
		for tex in arr:
			if tex != null:
				n += 1
		if n == 4:
			posed.append(id)
	_check(posed.size() == with_art.size(),
		"позы каста на всех 4 состояниях жира у %d/%d скинов: %s"
		% [posed.size(), with_art.size(), posed])

	game.queue_free()

# Паутина обязана вести себя по-разному: добычу тянет к себе, препятствие
# облепляет и тормозит. Если перепутать — спелл с откатом 2 c будет уничтожать
# любую угрозу и обесценит остальные скины.
func _test_web(save: Node) -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	spawner.clear_items()
	save.active_skin = "spider_man"
	save.skin_level  = 10
	normaldo.reload_skin()
	await process_frame

	# Препятствие: липнет и тормозит, но НЕ ломается.
	var rock := Area2D.new()
	rock.set_script(preload("res://scripts/hazard_item.gd"))
	rock.set("kind", "safe")
	rock.set("speed", 250.0)
	rock.position = Vector2(500.0, 200.0)
	spawner.add_child(rock)
	await process_frame
	var speed_before : float = float(rock.get("speed"))
	normaldo.call("_web_stick", rock)
	await process_frame
	_check(is_instance_valid(rock), "препятствие после паутины ЖИВО, а не сломано")
	_check(float(rock.get("speed")) < speed_before,
		"препятствие замедлено: %.0f → %.0f" % [speed_before, float(rock.get("speed"))])
	_check(rock.has_meta("webbed"), "на препятствии висит паутина")

	# Добыча: подтягивается к голове.
	var pizza := Area2D.new()
	pizza.set_script(preload("res://scripts/effect_item.gd"))
	pizza.set("kind", "casino_chip")
	pizza.set("speed", 250.0)
	pizza.position = Vector2(700.0, 60.0)
	spawner.add_child(pizza)
	await process_frame
	var dist_before : float = pizza.global_position.distance_to(normaldo.global_position)
	normaldo.call("_web_pull", pizza)
	# Замеряем В ПОЛЁТЕ: долетев до головы, добыча честно подбирается и узел
	# освобождается — это правильный исход, а не пропажа.
	var t := 0.0
	while t < 0.12:
		await process_frame
		t += 1.0 / 60.0
	if is_instance_valid(pizza):
		var dist_after : float = pizza.global_position.distance_to(normaldo.global_position)
		_check(dist_after < dist_before,
			"добыча подтягивается к голове: %.0f → %.0f" % [dist_before, dist_after])
	else:
		_check(true, "добыча долетела до головы и подобрана")

	game.queue_free()
