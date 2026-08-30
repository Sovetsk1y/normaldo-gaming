extends SceneTree

# Headless-проверка босса-крокодила.
#   godot --headless --path . --script res://dev/smoke_croc.gd
#
# Битва держится на одном правиле: СНАЧАЛА ТЕЛЕГРАФ, ПОТОМ УДАР. Его и надо
# проверять — не «пуля появилась», а «пуля появилась ПОСЛЕ того, как показали
# куда». Босс, который бьёт без предупреждения, формально работает и при этом
# нечестен; именно этим болел крокодил в старом проекте.
#
# Второе, что проверяется, — что битва ДОХОДИТ ДО КОНЦА. Битва из трёх актов,
# сшитых await'ами, ломается тихо: одна корутина не дождалась — и босс навсегда
# завис в акте, а забег не продолжится никогда.
#
# См. /Концепция/Босс — Крокодил.md

const CROC := preload("res://scripts/leatherhead.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 16

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Кадры и замеры ──")
	_test_assets()
	print("── Акт 1: охота ──")
	await _test_hunt()
	print("── Акт 2: хвост ──")
	await _test_tail()
	print("── Акт 3: картечь и пасть ──")
	await _test_shotgun()
	print("── Битва доходит до конца ──")
	await _test_full()
	_finish()

# ── Хелперы ──────────────────────────────────────────────────────────────────

func _boot() -> Dictionary:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var n  : Node = game.get_node_or_null("Normaldo")
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(200.0, vp.y * 0.5)
	# Нормальдо бессмертен НАМЕРЕННО: тест меряет хореографию битвы, а не
	# выживание. Смертный Нормальдо на первом же взмахе хвоста умирает, экран
	# смерти ставит дерево на паузу — и битва замирает на середине, а тест
	# показывает «босс завис», хотя завис он не сам.
	n.set("_dev_immortal", true)
	await process_frame
	return { "game": game, "n": n, "sp": sp, "vp": vp }

# Босс поднимается БЕЗ интро: интро — это пять секунд титров и реплики, и
# гонять их в каждом тесте значит мерить титры, а не битву.
func _croc(e: Dictionary) -> Node2D:
	var c := Node2D.new()
	c.set_script(CROC)
	c.call("setup", e["n"], e["sp"], e["game"], true)
	c.set("autostart", false)
	e["game"].add_child(c)
	return c

func _tick(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _count(group: String) -> int:
	return get_root().get_tree().get_nodes_in_group(group).size()

# Именно НИТЬ ПРИЦЕЛА, а не любой Line2D: в сцене есть и другие — паутина
# Спайдера, следы снарядов, — и по типу узла их не различить.
func _lines(root: Node, out: Array) -> Array:
	if root is Line2D and String(root.name).begins_with("AimLaser"):
		out.append(root)
	for c in root.get_children():
		_lines(c, out)
	return out

# ── Кадры ────────────────────────────────────────────────────────────────────
# Позы нарезаны из одной рамки, чтобы голова не прыгала при смене. Если кто-то
# перережет листы иначе, крокодил начнёт дёргаться — а заметить это на глаз в
# бою, где кадры меняются каждые 0.07 с, почти невозможно.
func _test_assets() -> void:
	var same := true
	var sz : Vector2 = CROC.F_GUN.get_size()
	for arr in [CROC.F_RELOAD_UP, CROC.F_SNIPE, CROC.F_RELOAD_DOWN,
			CROC.F_SHOT_DOWN, CROC.F_RAGE]:
		for t in arr:
			if t.get_size() != sz:
				same = false
	_check(same, "все боевые позы в одной рамке %dx%d" % [sz.x, sz.y])
	_check(CROC.F_RAGE.size() == 7 and CROC.F_SHOT_DOWN.size() == 5,
		"злая картечь на 7 кадров, обычная на 5")

	# Дуло замерено по вспышке и у трёх поз стоит В РАЗНЫХ местах. Общей точкой
	# обойтись нельзя: пуля вылетала бы из шеи.
	var m : Array = [CROC.MUZZLE_AIM, CROC.MUZZLE_DOWN, CROC.MUZZLE_RAGE]
	var distinct : bool = m[0] != m[1] and m[1] != m[2] and m[0] != m[2]
	_check(distinct, "у трёх поз своё положение дула: %s" % str(m))

func _test_hunt() -> void:
	var e : Dictionary = await _boot()
	var c : Node2D = _croc(e)
	await process_frame
	c.call("_act_hunt")

	# Ключевая проверка всей битвы: НИТЬ РАНЬШЕ ПУЛИ. Ждём появления нити и
	# смотрим, что пули в этот момент ещё нет.
	var laser_at := -1.0
	var bullet_at := -1.0
	var t := 0.0
	while t < 6.0 and (laser_at < 0.0 or bullet_at < 0.0):
		await process_frame
		t += 1.0 / 60.0
		if laser_at < 0.0 and not _lines(e["game"], []).is_empty():
			laser_at = t
		if bullet_at < 0.0 and _count("bullet") > 0:
			bullet_at = t
	_check(laser_at > 0.0, "нить прицела загорелась (%.2f с)" % laser_at)
	_check(bullet_at > 0.0, "и выстрел состоялся (%.2f с)" % bullet_at)
	_check(laser_at > 0.0 and bullet_at > laser_at,
		"нить РАНЬШЕ пули: %.2f против %.2f" % [laser_at, bullet_at])
	_check(bullet_at - laser_at > 0.25,
		"и у игрока есть время уйти: %.2f с" % (bullet_at - laser_at))

	# Пуля летит ПО ПРЯМОЙ и никуда не доводится: иначе нить бессмысленна.
	var b : Node2D = get_root().get_tree().get_nodes_in_group("bullet")[0]
	var p0 : Vector2 = b.global_position
	await _tick(0.08)
	var p1 : Vector2 = b.global_position if is_instance_valid(b) else p0
	(e["n"] as Node2D).position += Vector2(0.0, 140.0)   # игрок ушёл
	await _tick(0.08)
	if is_instance_valid(b):
		var d1 := (p1 - p0).normalized()
		var d2 := (b.global_position - p1).normalized()
		_check(d1.dot(d2) > 0.99, "пуля летит по прямой, за игроком не идёт")
	else:
		_check(true, "пуля уже улетела за край")
	e["game"].queue_free()
	await process_frame

func _test_tail() -> void:
	var e : Dictionary = await _boot()
	var c : Node2D = _croc(e)
	await process_frame
	c.call("_act_tail")

	# Свечение края раньше хвоста — та же проверка, что и с нитью.
	var glow_at := -1.0
	var tail_at := -1.0
	var t := 0.0
	while t < 4.0 and (glow_at < 0.0 or tail_at < 0.0):
		await process_frame
		t += 1.0 / 60.0
		if glow_at < 0.0:
			for ch in e["game"].get_children():
				if ch is ColorRect and (ch as ColorRect).size.y < 20.0:
					glow_at = t
					break
		if tail_at < 0.0 and _count("croc_tail") > 0:
			tail_at = t
	_check(glow_at > 0.0, "край загорелся (%.2f с)" % glow_at)
	_check(tail_at > 0.0 and tail_at > glow_at,
		"хвост пошёл ПОСЛЕ свечения: %.2f против %.2f" % [tail_at, glow_at])

	# Щель. Хвост перекрывает не весь экран — иначе от него нельзя уйти в
	# принципе, и акт превращается в отнятую жизнь.
	var tails : Array = get_root().get_tree().get_nodes_in_group("croc_tail")
	if not tails.is_empty():
		var tl : Node2D = tails[0]
		var cs : CollisionShape2D = null
		for ch in tl.get_children():
			if ch is CollisionShape2D:
				cs = ch
		var h : float = (cs.shape as RectangleShape2D).size.y if cs != null else 0.0
		var vp : Vector2 = e["vp"]
		_check(h < vp.y * 0.85, "и оставляет щель: стена %.0f при экране %.0f" % [h, vp.y])
	e["game"].queue_free()
	await process_frame

func _test_shotgun() -> void:
	var e : Dictionary = await _boot()
	var c : Node2D = _croc(e)
	await process_frame

	# Веер: три дробины за раз, и они РАЗЪЕЗЖАЮТСЯ. Три пули в одну точку — это
	# одна пуля, только громче.
	c.call("_buckshot", 3, CROC.BUCK_SPREAD)
	await _tick(0.45)
	var bs : Array = get_root().get_tree().get_nodes_in_group("bullet")
	_check(bs.size() == 3, "картечь: ровно три дробины (%d)" % bs.size())
	if bs.size() == 3:
		var ys : Array = []
		for b in bs:
			ys.append((b as Node2D).global_position.y)
		await _tick(0.25)
		var spread := 0.0
		for b in bs:
			if is_instance_valid(b):
				spread = maxf(spread, absf((b as Node2D).global_position.y - ys[0]))
		_check(spread > 20.0, "и они разъезжаются: %.0f px" % spread)

	# Пасть: тап отталкивает крокодила и выбивает добычу. Удар по боссу обязан
	# что-то давать, иначе тапают из вежливости.
	for b in get_root().get_tree().get_nodes_in_group("bullet"):
		b.queue_free()
	await process_frame
	c.call("_jaw_lunge")
	await _tick(0.4)
	_check(bool(c.get("_lunging")), "пасть пошла на игрока")
	var x0 : float = (c as Node2D).position.x
	var hp0 : int  = int(c.get("_lunge_hp"))
	var loot0 : int = _count("pizza") + _count("dollar")
	c.call("_on_lunge_tap")
	await process_frame
	_check((c as Node2D).position.x > x0, "тап отталкивает: %.0f → %.0f"
		% [x0, (c as Node2D).position.x])
	_check(int(c.get("_lunge_hp")) == hp0 - 1, "и снимает одно нажатие из счёта")
	_check(_count("pizza") + _count("dollar") > loot0, "и выбивает добычу")
	e["game"].queue_free()
	await process_frame

# Битва из трёх актов, сшитых await'ами, ломается ТИХО: одна корутина не
# дождалась — и босс навсегда завис, а забег не продолжится никогда. Поэтому
# отдельная проверка: доходит ли всё до конца и убирает ли за собой.
func _test_full() -> void:
	var e : Dictionary = await _boot()
	var c := Node2D.new()
	c.set_script(CROC)
	c.call("setup", e["n"], e["sp"], e["game"], true)
	e["game"].add_child(c)
	await process_frame
	var t := 0.0
	var seen : Array = []
	while t < 200.0 and is_instance_valid(c):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		var a : String = String(c.get("current_act"))
		if not seen.has(a):
			seen.append(a)
			print("    [%.0f с] такт: %s" % [t, a])
	_check(not is_instance_valid(c), "битва дошла до конца и босс убрался (%.0f с)" % t)
	_check(t > 30.0, "и заняла не пару секунд: %.0f с" % t)
	_check(_count("croc_tail") == 0 and _count("bullet") == 0,
		"после боя на экране не осталось ни хвостов, ни пуль")
	e["game"].queue_free()
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
