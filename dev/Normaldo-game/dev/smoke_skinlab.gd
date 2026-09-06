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
const EXPECTED_CHECKS : int = 11

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
	_finish()

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
