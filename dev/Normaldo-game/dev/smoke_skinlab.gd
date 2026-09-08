extends SceneTree

# Headless-проверка лаборатории скинов.
#   godot --headless --path . --script res://dev/smoke_skinlab.gd
#
# Смысл лаборатории в том, что она показывает НАСТОЯЩУЮ игру: те же лейны, тот
# же хитбокс, тот же масштаб. Соврать она может ровно двумя способами, и оба
# тихие — экран при этом собирается и выглядит рабочим:
#
#   1. Геометрия разошлась с игрой. Хитбокс, позиция героя и число лейнов
#      прописаны в лаборатории константами (иначе пришлось бы поднимать полсцены
#      забега ради трёх чисел). Поменяли их в game.tscn или в spawner — и
#      лаборатория молча меряет по старому.
#   2. Посадка спрайта разошлась с `normaldo._apply_skin_to_sprite`. Тогда
#      сводить размеры будут по картинке, которой в забеге нет.
#
# Обе проверяются сверкой с первоисточником, а не «примерно так и должно быть».
#
# См. scripts/skin_lab.gd

const SP := preload("res://scripts/spawner.gd")

# ── Почему всё берётся из ДЕРЕВА, а не предзагрузкой ─────────────────────────
# SceneTree-скрипт компилируется РАНЬШЕ, чем автозагрузки попадают в область
# видимости. Поэтому в нём не резолвится ни `SkinRegistry.SKINS` напрямую, ни
# `preload("normaldo.gd")` — последний тянет за собой `SaveData` и роняет
# компиляцию уже чужого скрипта. Ошибка при этом не мешает тесту пройти
# (константы всё равно читаются), и именно поэтому её легко проглядеть —
# а опираться на полусобранный скрипт нельзя.
#
# Спавнер предзагружается: у него автозагрузок в области видимости нет.
var _reg : Node = null
var _met : Node = null
var _hero_nudge = null

# Константа скрипта живого узла. Через карту констант, а не свойством: у
# Object.get() констант нет вовсе.
func _const(node: Node, name: String):
	if node == null or node.get_script() == null:
		return null
	return (node.get_script() as Script).get_script_constant_map().get(name)

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 50

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_reg = get_root().get_node_or_null("SkinRegistry")
	_met = get_root().get_node_or_null("SkinMetrics")
	print("── Геометрия сходится с игрой ──")
	await _test_geometry()
	print("── Посадка спрайта ──")
	await _test_placement()
	print("── Правка и запись ──")
	await _test_editing()
	print("── Шляпа и маска ──")
	_test_worn()
	print("── Ширина вещи ──")
	await _test_worn_width()
	print("── Кадр поедания ──")
	await _test_pose()
	print("── Классика: правка доходит ──")
	await _test_classic_moves()
	print("── Чип лаборатории под флагом ──")
	await _test_lab_chip_gated()
	_finish()

# ── Кадр поедания ────────────────────────────────────────────────────────────
# У каждого жира ДВА кадра, покой и «ест», а правился только покой: поедание
# держалось на одном автозамере, который на нём и промахивается чаще всего —
# рот открыт, голова наклонена, силуэт другой.
#
# Проверяется здесь не «кнопка есть», а три вещи, каждая из которых ломается
# молча:
#   1. Правка кадра идёт В СВОЙ слой и не трогает покой.
#   2. Игра берёт ту же поправку — иначе лаборатория показывает не то, что
#      увидит игрок, и подгонять по ней бессмысленно.
#   3. Правка размера скина НЕ ЗАТИРАЕТ её: обе живут в одной строке жира.
func _test_pose() -> void:
	var lab : Node = await _open_lab()
	if lab == null:
		_check(false, "лаборатория открылась")
		return
	var snap : Dictionary = _met.call("layout_snapshot")
	var id : String = "viking"
	lab.set("_skin", _reg.call("get_skin_index", id))
	lab.call("_set_fat", 1)

	var idle_tex : Texture2D = lab.call("_tex")
	lab.call("_cycle_pose")
	_check(String(lab.get("_pose")) == "_eat", "переключились на кадр поедания")
	var eat_tex : Texture2D = lab.call("_tex")
	_check(eat_tex != null and eat_tex != idle_tex,
		"и картинка сменилась на кадр «ест»")

	# Правка идёт В СВОЙ СЛОЙ. Общий на два кадра означал бы, что подгонка
	# поедания уводит покой — а его к этому моменту уже выставили.
	var idle_before : float = float(_met.call("tweak_for", id, 1))
	lab.call("_bump_tweak", 0.05)
	_check(absf(float(_met.call("pose_tweak_for", id, 1, "_eat")) - 1.05) < 0.001,
		"правка ушла в слой кадра: ×%.3f"
			% float(_met.call("pose_tweak_for", id, 1, "_eat")))
	_check(is_equal_approx(float(_met.call("tweak_for", id, 1)), idle_before),
		"а покой не тронут: ×%.3f" % float(_met.call("tweak_for", id, 1)))

	# ИГРА БЕРЁТ ЭТУ ЖЕ ПОПРАВКУ. `pose_k` — то, чем `normaldo._show_head`
	# масштабирует кадр; если бы ручной слой жил мимо неё, лаборатория
	# показывала бы не то, что увидит игрок.
	var k_raw : float = float(_met.POSE_K.get(id, {}).get("_eat", [1.0, 1.0, 1.0, 1.0])[1])
	_check(absf(float(_met.call("pose_k", id, "_eat", 1)) - k_raw * 1.05) < 0.001,
		"и игра масштабирует кадр с её учётом: ×%.3f против замеренных ×%.3f"
			% [float(_met.call("pose_k", id, "_eat", 1)), k_raw])

	# Сдвиг — так же: поверх замеренного, а не вместо.
	var off_raw : Vector2 = _met.POSE_OFF.get(id, {}).get("_eat",
		[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])[1]
	_met.call("pose_set", id, 1, "_eat", 1.05, Vector2(0.01, -0.02))
	var got : Vector2 = _met.call("pose_off", id, "_eat", 1)
	_check(got.distance_to(off_raw + Vector2(0.01, -0.02)) < 0.0005,
		"и сдвиг кадра ложится поверх замеренного: %s" % [got])

	# РАЗМЕР СКИНА НЕ ЗАТИРАЕТ ПРАВКУ КАДРА. Обе лежат в одной строке жира, и
	# первая версия записи сносила соседей целиком.
	_met.call("layout_set", id, 1, 1.3, Vector2(0.02, 0.02))
	_check(absf(float(_met.call("pose_tweak_for", id, 1, "_eat")) - 1.05) < 0.001,
		"правка размера скина её не сносит: ×%.3f"
			% float(_met.call("pose_tweak_for", id, 1, "_eat")))

	# СБРОС снимает строку кадра, а не пишет в неё единицы: единицы пережили бы
	# следующий пересчёт замера и остались бы в файле навсегда.
	lab.call("_reset_current")
	_check(is_equal_approx(float(_met.call("pose_tweak_for", id, 1, "_eat")), 1.0)
			and _met.call("pose_nudge_for", id, 1, "_eat") == Vector2.ZERO,
		"сброс снимает правку кадра начисто")

	# ── ПОСАДКА ВЕЩИ У КАЖДОГО КАДРА СВОЯ ───────────────────────────────────
	# Шляпа садится по МАКУШКЕ РИСУНКА, а у кадра «ест» рисунок другой: рот
	# открыт, голова наклонена, макушка в другом месте. Пока посадка была одна на
	# оба кадра, выходил тупик: выставил шляпу на покое — на поедании съехала;
	# поправил на поедании — уехала на покое. Верного значения у одного числа не
	# было вовсе.
	_met.call("worn_set", id, 1, "hat", { "k": 0.74, "x": 0.05, "sink": 0.40 })
	_met.call("worn_set", id, 1, "hat", { "k": 0.74, "x": -0.03, "sink": 0.60 }, "_eat")
	var w_idle : Dictionary = _met.call("worn_for", id, 1, "hat")
	var w_eat  : Dictionary = _met.call("worn_for", id, 1, "hat", "_eat")
	_check(absf(float(w_idle["sink"]) - 0.40) < 0.001,
		"посадка на покое своя: sink %.2f" % float(w_idle["sink"]))
	_check(absf(float(w_eat["sink"]) - 0.60) < 0.001,
		"а на поедании своя: sink %.2f" % float(w_eat["sink"]))
	# И ПОПРАВКА КЛАДЁТСЯ ПОВЕРХ, а не вместо: чего в кадре не правили, то
	# берётся с покоя. Иначе на каждый кадр пришлось бы выставлять всё заново.
	_met.call("worn_set", id, 1, "hat", { "sink": 0.55 }, "_eat")
	var w_eat2 : Dictionary = _met.call("worn_for", id, 1, "hat", "_eat")
	_check(absf(float(w_eat2["x"]) - 0.05) < 0.001,
		"а не тронутое в кадре берётся с покоя: x %.2f" % float(w_eat2["x"]))

	# Игра берёт ту же посадку: `normaldo._refit_worn` пересаживает вещь на
	# каждой смене кадра, иначе правка в лаборатории осталась бы в лаборатории.
	var n : Node = _live_normaldo()
	_check(n != null and n.has_method("_refit_worn"),
		"и игра умеет пересаживать вещь под кадр")

	lab.call("_cycle_pose")
	_check(String(lab.get("_pose")).is_empty(), "и переключатель возвращается к покою")
	_met.call("layout_restore", snap)

func _live_normaldo() -> Node:
	for w in get_root().get_children():
		var n := w.get_node_or_null("Normaldo")
		if n != null:
			return n
	return null

# ── Геометрия ────────────────────────────────────────────────────────────────

func _test_geometry() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	# У героя обязан быть КРУГЛЫЙ хитбокс: лаборатория снимает с него радиус и
	# рисует круг. Стала фигура другой — рисовать будет нечего.
	var hero : Node2D = game.get_node_or_null("Normaldo")
	var cs : CollisionShape2D = hero.get_node_or_null("CollisionShape2D") if hero != null else null
	var r : float = -1.0
	if cs != null and cs.shape is CircleShape2D:
		r = (cs.shape as CircleShape2D).radius
	_check(r > 0.0, "у героя круглый хитбокс: %.1f" % r)

	_hero_nudge = _const(hero, "CLASSIC_HEAD_NUDGE_PX")
	_check(_hero_nudge != null, "поправка классики объявлена константой: %s" % str(_hero_nudge))

	game.queue_free()
	await process_frame

# ── Посадка ──────────────────────────────────────────────────────────────────
# Лаборатория обязана ставить спрайт ровно туда же, куда его ставит забег.
# Сверяется не «похоже», а ЧИСЛО В ЧИСЛО: расхождение в пару пикселей — это
# ровно та ошибка, которую инструмент и должен ловить, а не вносить.

func _test_placement() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	_check(hud != null and hud.has_method("_show_skin_lab"), "меню умеет открыть лабораторию")
	if hud == null:
		game.queue_free()
		return

	hud.call("_show_skin_lab")
	await process_frame
	var lab : Node = null
	for c in hud.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("skin_lab.gd"):
			lab = c
	_check(lab != null, "лаборатория открылась")
	if lab == null:
		game.queue_free()
		return

	# Слой поверх меню: без него разметку накрывает логотип и кнопки, и мерить
	# по такому кадру нельзя. Проверено кадром, а не догадкой.
	_check(lab is CanvasLayer and int(lab.get("layer")) > 1,
		"лаборатория лежит своим слоем поверх меню: %d" % int(lab.get("layer")))

	# Поправка классики и число лейнов не переписаны, а ВЗЯТЫ из первоисточника.
	# Проверяется именно это — не «числа совпали», а что копии нет вовсе:
	# совпавшая копия ведёт себя так же ровно до первой правки. Здесь на этом уже
	# обожглись: первая версия лаборатории переписала три числа из `game.tscn`, и
	# два из них разошлись с живой игрой на первом же прогоне.
	var lab_nudge = _const(lab, "CLASSIC_NUDGE_PX")
	_check(lab_nudge != null and _hero_nudge != null \
			and (lab_nudge as Vector2).is_equal_approx(_hero_nudge),
		"поправка классики взята у normaldo: %s и %s" % [str(lab_nudge), str(_hero_nudge)])
	_check(int(_const(lab, "LANE_COUNT")) == SP.LANE_COUNT,
		"лейнов столько же, сколько в спавнере: %s и %d"
			% [str(_const(lab, "LANE_COUNT")), SP.LANE_COUNT])

	# Радиус лаборатория СНЯЛА с живого героя — сверяем со сценой.
	var hero2 : Node2D = game.get_node_or_null("Normaldo")
	var cs2 : CollisionShape2D = hero2.get_node_or_null("CollisionShape2D") if hero2 != null else null
	var live_r : float = (cs2.shape as CircleShape2D).radius \
		if cs2 != null and cs2.shape is CircleShape2D else -1.0
	_check(is_equal_approx(float(lab.get("_hitbox_r")), live_r),
		"хитбокс снят с живого героя: %.1f и %.1f" % [float(lab.get("_hitbox_r")), live_r])

	# Герой в лаборатории стоит по СЕРЕДИНЕ среднего лейна: по ней и судят,
	# влезает ли скин в дорожку. В сцене записана стартовая точка забега, а в
	# меню он и вовсе сидит на диване — ни то, ни другое для замера не годится.
	var vp : Vector2 = get_root().get_visible_rect().size
	var mid : float = vp.y / float(SP.LANE_COUNT) * (float(SP.LANE_COUNT / 2) + 0.5)
	_check(is_equal_approx((lab.get("_hero_pos") as Vector2).y, mid),
		"герой по центру среднего лейна: %.1f и %.1f"
			% [(lab.get("_hero_pos") as Vector2).y, mid])

	var spr : Sprite2D = lab.get("_sprite")
	_check(spr != null, "спрайт скина на месте")
	if spr == null:
		game.queue_free()
		return

	# Проходим все скины и все жиры: расходится посадка обычно на одном-двух —
	# у тех, где голова далеко от центра кадра.
	var bad : Array = []
	var skins : Array = _reg.get("SKINS")
	for i in skins.size():
		var id : String = String(skins[i]["id"])
		for fat in 4:
			lab.set("_skin", i)
			lab.call("_set_fat", fat)
			var tex : Texture2D = _reg.call("get_avatar_texture", id, fat)
			if tex == null:
				continue
			var k : float = float(_met.call("sprite_scale", id, fat, tex.get_size()))
			if not is_equal_approx(spr.scale.x, k):
				bad.append("%s/%d масштаб %.4f против %.4f" % [id, fat + 1, spr.scale.x, k])
			# Та же формула, что в `normaldo._apply_head_offset`.
			var want : Vector2 = lab_nudge
			if id != "classic":
				var sz : Vector2 = tex.get_size()
				var off : Vector2 = _met.call("offset_for", id, fat)
				want = Vector2(-off.x * sz.x * k, -off.y * sz.y * k)
			want += lab.get("_hero_pos")
			if not spr.position.is_equal_approx(want):
				bad.append("%s/%d место %s против %s"
					% [id, fat + 1, str(spr.position), str(want)])
	_check(bad.is_empty(), "посадка совпадает с забегом на всех скинах и жирах: %s" % [bad])

	game.queue_free()
	await process_frame

# ── Правка ───────────────────────────────────────────────────────────────────
# Круг, ради которого лаборатория и существует: подвинул → игра увидела →
# записалось в файл → прочиталось обратно. Рвётся он тихо в каждом из четырёх
# мест, и снаружи все четыре выглядят одинаково — «я подвинул, а ничего не
# изменилось».

func _test_editing() -> void:
	var snap : Dictionary = _met.call("layout_snapshot")

	# 1. Правка доходит до ИГРЫ, а не только до экрана. Меряется `sprite_scale`
	#    — та самая функция, по которой игра ставит скин в забеге.
	var id : String = "viking"
	var before : float = float(_met.call("sprite_scale", id, 0, Vector2(500, 500)))
	_met.call("layout_set", id, 0, 1.25, Vector2(0.01, -0.02))
	var after : float = float(_met.call("sprite_scale", id, 0, Vector2(500, 500)))
	_check(is_equal_approx(after, before * 1.25),
		"правка размера доходит до забега: %.4f → %.4f" % [before, after])

	var nudge : Vector2 = _met.call("nudge_for", id, 0)
	_check(nudge.is_equal_approx(Vector2(0.01, -0.02)),
		"правка сдвига доходит до забега: %s" % str(nudge))

	# 2. Правка НЕ ЗАДЕВАЕТ соседние жиры. Ошибка тут особенно противная: правишь
	#    один жир, а разъезжаются все четыре, и заметно это не сразу.
	_check(is_equal_approx(float(_met.call("tweak_for", id, 1)), 1.0),
		"соседний жир не тронут: %.3f" % float(_met.call("tweak_for", id, 1)))

	# 3. Отмена возвращает СНИМОК, а не «примерно как было».
	_met.call("layout_restore", snap)
	_check(is_equal_approx(float(_met.call("sprite_scale", id, 0, Vector2(500, 500))), before),
		"отмена возвращает исходное: %.4f" % float(_met.call("sprite_scale", id, 0, Vector2(500, 500))))

	# 4. Запись и чтение обратно. Пишем во временный файл рядом, а не в
	#    настоящий: тест не имеет права переписать рабочую раскладку.
	var path : String = String(_met.get("LAYOUT_PATH"))
	var f := FileAccess.open(path, FileAccess.READ)
	_check(f != null, "раскладка лежит на месте: %s" % path)
	if f == null:
		return
	var raw : String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	_check(typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("skins"),
		"раскладка разбирается как JSON со списком скинов")
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	# Числа в файле обязаны совпасть с тем, что отдаёт игра. Расхождение значит,
	# что читатель и писатель понимают файл по-разному, — а это ровно тот случай,
	# когда «сохранил, перезапустил, и всё стало другим».
	var skins : Dictionary = (parsed as Dictionary)["skins"]
	var bad : Array = []
	for sid in skins:
		var fats : Array = (skins[sid] as Dictionary).get("fat", [])
		for i in fats.size():
			var row : Dictionary = fats[i]
			var want_t : float = float(row.get("tweak", 1.0))
			var got_t : float = float(_met.call("tweak_for", String(sid), i))
			if not is_equal_approx(want_t, got_t):
				bad.append("%s/%d размер %.3f против %.3f" % [sid, i + 1, got_t, want_t])
			var n : Array = row.get("nudge", [0.0, 0.0])
			var want_n := Vector2(float(n[0]), float(n[1]))
			var got_n : Vector2 = _met.call("nudge_for", String(sid), i)
			if not got_n.is_equal_approx(want_n):
				bad.append("%s/%d сдвиг %s против %s" % [sid, i + 1, str(got_n), str(want_n)])
	_check(bad.is_empty(), "игра читает из файла ровно то, что в нём написано: %s" % [bad])

	# Пояснение вверху файла — часть данных: без него следующий читатель не
	# узнает ни откуда числа, ни почему их нельзя править в коде. Запись обязана
	# его сохранять, а не затирать.
	_check((parsed as Dictionary).has("_comment"),
		"в файле осталось пояснение, зачем он")

# ── Шляпа и маска ────────────────────────────────────────────────────────────
# Посадка вещей до этого была ОДНА на все четырнадцать скинов, и работать не
# могла: у классика в кадре голова, у викинга рога, у пирата своя шляпа. Теперь
# она по скину и по жиру, и ломается это тремя способами, все тихие.

func _test_worn() -> void:
	var snap : Dictionary = _met.call("layout_snapshot")

	# 1. Скин, которого нет в файле, ведёт себя РОВНО КАК РАНЬШЕ. Иначе переезд
	#    в файл молча сдвинул бы шляпу у десяти скинов из четырнадцати.
	var defaults : Dictionary = _met.get("WORN_DEFAULTS")
	var hat : Dictionary = _met.call("worn_for", "viking", 0, "hat")
	var same := true
	for key in (defaults["hat"] as Dictionary):
		if not is_equal_approx(float(hat[key]), float((defaults["hat"] as Dictionary)[key])):
			same = false
	_check(same, "без записи в файле посадка та же, что была константой: %s" % [hat])

	# 2. Правка ложится ТОЧЕЧНО: на свой скин, свой жир и свою вещь. Ошибка тут
	#    особенно противная — поправил шляпу на одном скине, разъехалась у всех.
	_met.call("worn_set", "viking", 1, "hat", { "k": 0.5, "x": 0.1, "sink": 0.2 })
	_check(is_equal_approx(float(_met.call("worn_for", "viking", 1, "hat")["k"]), 0.5),
		"правка вещи применилась")
	_check(is_equal_approx(float(_met.call("worn_for", "viking", 0, "hat")["k"]),
			float((defaults["hat"] as Dictionary)["k"])),
		"соседний жир не тронут")
	_check(is_equal_approx(float(_met.call("worn_for", "tyson", 1, "hat")["k"]),
			float((defaults["hat"] as Dictionary)["k"])),
		"соседний скин не тронут")
	_check(is_equal_approx(float(_met.call("worn_for", "viking", 1, "mask")["k"]),
			float((defaults["mask"] as Dictionary)["k"])),
		"маска не тронута правкой шляпы")

	# 3. Правка вещи и правка САМОГО СКИНА не затирают друг друга. Они лежат в
	#    одной строке жира и правятся разными кнопками — при неаккуратной записи
	#    движение скина сбрасывало бы шляпу, и заметно это только через раз.
	_met.call("layout_set", "viking", 1, 1.4, Vector2(0.05, 0.05))
	_check(is_equal_approx(float(_met.call("worn_for", "viking", 1, "hat")["k"]), 0.5),
		"движение скина не сбросило посадку вещи")
	_check(is_equal_approx(float(_met.call("tweak_for", "viking", 1)), 1.4),
		"и правка скина на месте")

	_met.call("layout_restore", snap)

# ── Ширина вещи ──────────────────────────────────────────────────────────────
# `k` — доля ШИРИНЫ КАДРА хозяина, а кадры у жиров РАЗНЫЕ. Отсюда то, на что и
# наткнулись глазами: одинаковый коэффициент на всех жирах даёт РАЗНУЮ шляпу, и
# по панели этого было не видно — она показывала только коэффициент.
#
# Проверяется поэтому не «панель что-то пишет», а само свойство: одинаковый `k`
# даёт разные пиксели, а «Ш = ВСЕМ ЖИРАМ» — одинаковые.

func _test_worn_width() -> void:
	var snap : Dictionary = _met.call("layout_snapshot")
	var id := "viking"
	var hat : Texture2D = load("res://assets/items/magic_hat.png")

	# Ширина считается по РИСУНКУ, а не по кадру: у шляпы кадр 536×615, и
	# рисунок занимает в нём меньше половины. Число «по кадру» показывало бы поля.
	var frame : float = hat.get_size().x
	var art : float = float(WornItem.used_rect(hat).size.x)
	_check(art > 0.0 and art < frame,
		"ширина меряется по рисунку, а не по кадру: %d из %d" % [int(art), int(frame)])

	# 1. ОДИН И ТОТ ЖЕ `k` даёт разный размер — то, из-за чего всё и затевалось.
	var px : Array = []
	for f in 4:
		var host : Texture2D = _reg.call("get_avatar_texture", id, f)
		px.append(WornItem.art_px(host, hat, 0.74,
			float(_met.call("sprite_scale", id, f, host.get_size()))))
	var spread : float = (px as Array).max() - (px as Array).min()
	_check(spread > 1.0,
		"одинаковый k даёт разную ширину: %.0f / %.0f / %.0f / %.0f" % px)

	# 2. «Ш = ВСЕМ ЖИРАМ» выравнивает в пикселях. Допуск в один пиксель: `k`
	#    зажат в 0.05…3.0, и на краю диапазона точное совпадение невозможно.
	var lab : Node = await _open_lab()
	if lab == null:
		_met.call("layout_restore", snap)
		return
	# Лабораторию надо ПЕРЕВЕСТИ на тот же скин, что мерим. Первый вариант этой
	# проверки забыл про это: лаборатория стояла на классике, уравнивала его, а
	# сверялись мы с викингом — и провал выглядел как поломка уравнивания.
	var idx := -1
	for i in (_reg.get("SKINS") as Array).size():
		if String((_reg.get("SKINS") as Array)[i]["id"]) == id:
			idx = i
	_check(idx >= 0, "скин %s нашёлся в реестре: №%d" % [id, idx])
	lab.set("_skin", idx)
	lab.set("_worn", "hat")
	lab.set("_fat", 2)
	lab.call("_worn_same_width")
	var want : float = float(lab.call("_worn_px_at", id, 2))
	var off : Array = []
	for f in 4:
		var got : float = float(lab.call("_worn_px_at", id, f))
		if absf(got - want) > 1.0:
			off.append("жир %d: %.0f вместо %.0f" % [f + 1, got, want])
	_check(off.is_empty(), "после «Ш = ВСЕМ ЖИРАМ» ширина одна: %s" % [off])

	# 3. Трогает ТОЛЬКО ширину. Посадку у каждого жира подбирают руками —
	#    макушка у худого и у убера в разных местах, — и утащить её заодно
	#    значило бы сбить сделанную работу.
	var sink_before : float = float(_met.call("worn_for", id, 0, "hat")["sink"])
	lab.call("_worn_same_width")
	_check(is_equal_approx(float(_met.call("worn_for", id, 0, "hat")["sink"]), sink_before),
		"глубина посадки не тронута")

	lab.queue_free()
	await process_frame
	_met.call("layout_restore", snap)

# ── КЛАССИКА ДВИГАЕТСЯ, И КАДР «ЕСТ» НЕ УЛЕТАЕТ ──────────────────────────────
# Тихая пара ошибок, найденная по жалобе «первый скин в лабе не двигается
# никак»: у классики посадка бралась ЖЁСТКОЙ пиксельной константой, и ручная
# правка на неё не влияла вовсе. Сдвиг при этом честно копился в файле — а тот
# же накопленный сдвиг применялся к кадру «ест» (его-то сажают по доле кадра) и
# уносил кадр на пол-экрана в сторону.
#
# Проверяется поэтому и то, и другое: что правка ДОХОДИТ и что кадр варианта
# остаётся рядом со своим кадром покоя.
func _test_classic_moves() -> void:
	var snap = _met.call("layout_snapshot")
	var lab : Node = await _open_lab()
	if lab == null:
		_check(false, "лаборатория открылась")
		return
	lab.set("_skin", 0)
	lab.set("_fat", 3)
	lab.set("_pose", "")
	lab.call("_refresh")
	await process_frame
	var spr : Sprite2D = lab.get("_sprite")
	var was : Vector2 = spr.position
	# Двигаем ровно тем же путём, что и палец в лаборатории.
	lab.call("_apply", "classic", float(lab.call("_cur_tweak", "classic")),
		Vector2(0.02, 0.0))
	await process_frame
	_check(spr.position.distance_to(was) > 1.0,
		"классика ДВИГАЕТСЯ ручной правкой: %s → %s" % [was.round(), spr.position.round()])

	# А кадр «ест» садится рядом с кадром покоя, а не улетает.
	lab.call("_apply", "classic", float(lab.call("_cur_tweak", "classic")), Vector2.ZERO)
	await process_frame
	var idle_pos : Vector2 = spr.position
	var idle_scale : float = spr.scale.x
	lab.set("_pose", "_eat")
	lab.call("_refresh")
	await process_frame
	_check(spr.position.distance_to(idle_pos) < 40.0,
		"кадр «ест» садится рядом с покоем: %s против %s"
			% [spr.position.round(), idle_pos.round()])

	# И МАСШТАБ У НЕГО ТОТ ЖЕ, ЧТО В ИГРЕ: база по кадру ПОКОЯ, помноженная на
	# поправку кадра (`normaldo._show_head`). Считая базу по кадру варианта,
	# лаборатория показывала голову в полтора раза крупнее, чем видит игрок, —
	# и по ней подбирали числа.
	var pk : float = float(_met.call("pose_k", "classic", "_eat", 3))
	_check(absf(spr.scale.x - idle_scale * pk) < 0.01,
		"и масштаб как в игре: %.3f против %.3f" % [spr.scale.x, idle_scale * pk])

	lab.queue_free()
	await process_frame
	_met.call("layout_restore", snap)

# ── ЧИП ЛАБОРАТОРИИ ЖИВЁТ ПОД ФЛАГОМ, И ОТДЕЛЬНО ОТ ЧИПА «ОПЫТ» ──────────────
# Они строились в одной функции: флаг на них один, а смысл разный. Опыт задуман
# оставаться и в сборке без инструментария — лестницу скинов иначе не проверить,
# — и, вынеся его из-под рубильника, вынесли бы заодно и лабораторию, не заметив.
func _test_lab_chip_gated() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	_check(hud != null and hud.has_method("_build_menu_dev_lab_btn"),
		"чип лаборатории собирается своей функцией")
	# И функция чипа «ОПЫТ» его больше не создаёт.
	var src := FileAccess.get_file_as_string("res://scripts/hud.gd")
	var xp_i : int = src.find("func _build_menu_dev_xp_btn")
	var lab_i : int = src.find("func _build_menu_dev_lab_btn")
	var xp_body : String = src.substr(xp_i, maxi(0, lab_i - xp_i)) if xp_i >= 0 and lab_i > xp_i else ""
	_check(not xp_body.contains("_show_skin_lab"),
		"и чип «ОПЫТ» её не тащит за собой")
	# А вызывается он под флагом ИНСТРУМЕНТАРИЯ: лаборатория — инструмент, и
	# место ей в одном ряду со сбросами и долларами, а не рядом с опытом (тот
	# исключение — им проверяют лестницу скинов забегами).
	var call_i : int = src.find("_build_menu_dev_lab_btn(vp)")
	var gate_i : int = src.rfind("if DevFlags.ENABLED and DevFlags.TOOLBOX", call_i)
	_check(gate_i > 0 and call_i - gate_i < 600,
		"и стоит он под DevFlags.ENABLED and DevFlags.TOOLBOX")
	game.queue_free()
	await process_frame

# Лаборатория поверх живой игры — тем же путём, каким её открывает игрок.
func _open_lab() -> Node:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	if hud == null or not hud.has_method("_show_skin_lab"):
		return null
	hud.call("_show_skin_lab")
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame
	for c in hud.get_children():
		if c is SkinLab:
			return c
	return null

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
