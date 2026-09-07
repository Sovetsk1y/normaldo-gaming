extends SceneTree

# Headless-проверка ручного слоя размеров и хитбоксов предметов.
#   godot --headless --path . --script res://dev/smoke_item_lab.gd
#
# Слой накладывается на ГОТОВЫЙ УЗЕЛ — умножает то, что предмет уже себе
# поставил. У такого подхода ровно три способа сломаться, и все тихие:
#
#   1. НАЛОЖИЛОСЬ ДВАЖДЫ. Предмет входит в дерево повторно (мэджик бокс, спелл
#      Спайди перевешивают его на другой узел), и он растёт с каждым переносом.
#   2. ФОРМА ПРАВИТСЯ НА МЕСТЕ. Одна CircleShape2D нередко висит на всех
#      экземплярах сцены сразу, и правка без дубликата раздувает каждый предмет
#      этого вида, включая уже летящие.
#   3. СЛОЙ НЕ ДОХОДИТ. Спавнер зовёт наложение один раз, на входе в дерево;
#      отвяжется сигнал — и правки перестанут работать, ничего не сломав.
#
# См. scripts/item_tweaks.gd, scripts/skin_lab.gd

const TWEAKS := preload("res://scripts/item_tweaks.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 21

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
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	var snap : Dictionary = TWEAKS.snapshot()
	const PIZZA : String = "res://assets/items/pizza.png"

	# ── Слой ────────────────────────────────────────────────────────────────
	print("── Слой ──")
	TWEAKS.reset(PIZZA)
	var d : Dictionary = TWEAKS.mult_for(PIZZA)
	_check(is_equal_approx(float(d["size"]), 1.0) and is_equal_approx(float(d["hit"]), 1.0),
		"без правки множители единичные: %s" % [d])

	TWEAKS.set_mult(PIZZA, 1.5, 0.6)
	d = TWEAKS.mult_for(PIZZA)
	_check(is_equal_approx(float(d["size"]), 1.5) and is_equal_approx(float(d["hit"]), 0.6),
		"правка записалась: %s" % [d])

	# ВОЗВРАТ К ЕДИНИЦЕ — ЭТО УДАЛЕНИЕ. Записанная единица копит в файле строки
	# «ничего не менял», среди которых настоящих правок не найти.
	TWEAKS.set_mult(PIZZA, 1.0, 1.0)
	_check(not TWEAKS.has_tweak(PIZZA), "возврат к единице стирает запись, а не пишет её")

	# Пределы: множитель вне границ — это уже не «подправил», а «поменял предмет».
	TWEAKS.set_mult(PIZZA, 99.0, 0.001)
	d = TWEAKS.mult_for(PIZZA)
	_check(float(d["size"]) <= float(TWEAKS.MULT_MAX) + 0.001
			and float(d["hit"]) >= float(TWEAKS.MULT_MIN) - 0.001,
		"множители зажаты в границы: %s" % [d])

	# ── Наложение ───────────────────────────────────────────────────────────
	print("── Наложение на узел ──")
	TWEAKS.set_mult(PIZZA, 2.0, 0.5)
	var item : Node2D = _make_pizza()
	var spr  : Sprite2D = item.get_node("Sprite2D")
	var cs   : CollisionShape2D = item.get_node("CollisionShape2D")
	var s0   : float = spr.scale.x
	var r0   : float = (cs.shape as CircleShape2D).radius

	sp.add_child(item)
	await process_frame
	_check(is_equal_approx(spr.scale.x, s0 * 2.0),
		"рисунок умножился: %.3f → %.3f" % [s0, spr.scale.x])
	_check(is_equal_approx((cs.shape as CircleShape2D).radius, r0 * 0.5),
		"и хитбокс тоже: %.1f → %.1f" % [r0, (cs.shape as CircleShape2D).radius])

	# ── Дважды не накладывается ─────────────────────────────────────────────
	print("── Повторный вход в дерево ──")
	var s1 : float = spr.scale.x
	var r1 : float = (cs.shape as CircleShape2D).radius
	sp.remove_child(item)
	sp.add_child(item)
	await process_frame
	_check(is_equal_approx(spr.scale.x, s1),
		"перевешенный предмет не растёт: %.3f" % spr.scale.x)
	_check(is_equal_approx((cs.shape as CircleShape2D).radius, r1),
		"и хитбокс не растёт: %.1f" % (cs.shape as CircleShape2D).radius)

	# ── Форма ДУБЛИРУЕТСЯ ───────────────────────────────────────────────────
	# Второй предмет того же вида обязан получить СВОЙ радиус, а не унаследовать
	# уже умноженный от первого.
	print("── Общая форма ──")
	var it2 : Node2D = _make_pizza()
	var cs2 : CollisionShape2D = it2.get_node("CollisionShape2D")
	var raw2 : float = (cs2.shape as CircleShape2D).radius
	_check(is_equal_approx(raw2, r0),
		"свежий предмет приходит с исходным радиусом: %.1f против %.1f" % [raw2, r0])
	sp.add_child(it2)
	await process_frame
	_check(is_equal_approx((cs2.shape as CircleShape2D).radius, r0 * 0.5),
		"и правится ровно один раз: %.1f" % (cs2.shape as CircleShape2D).radius)
	_check((cs2.shape as CircleShape2D) != (cs.shape as CircleShape2D),
		"формы у них РАЗНЫЕ объекты, а не одна на всех")

	# ── Без правки — ничего не трогаем ──────────────────────────────────────
	print("── Нетронутый предмет ──")
	TWEAKS.reset(PIZZA)
	var it3 : Node2D = _make_pizza()
	var spr3 : Sprite2D = it3.get_node("Sprite2D")
	var cs3 : CollisionShape2D = it3.get_node("CollisionShape2D")
	var s3 : float = spr3.scale.x
	sp.add_child(it3)
	await process_frame
	_check(is_equal_approx(spr3.scale.x, s3),
		"предмет без правки остаётся как был: %.3f" % spr3.scale.x)
	_check(is_equal_approx((cs3.shape as CircleShape2D).radius, r0),
		"и хитбокс у него исходный: %.1f" % (cs3.shape as CircleShape2D).radius)

	# ── Спавнер подключён ───────────────────────────────────────────────────
	# Отвяжется сигнал — правки перестанут работать, ничего при этом не сломав.
	print("── Спавнер ──")
	_check(sp.is_connected("child_entered_tree", Callable(sp, "_on_item_entered")),
		"спавнер накладывает слой на каждый вошедший предмет")

	# ── Раздел в лаборатории ────────────────────────────────────────────────
	print("── Раздел ПРЕДМЕТЫ ──")
	var lab : Node = load("res://scripts/skin_lab.gd").new()
	lab.call("setup", game.get_node_or_null("HUD"))
	get_root().add_child(lab)
	await process_frame

	_check(String(lab.get("_mode")) == "skins", "лаборатория открывается на скинах")
	lab.call("_cycle_mode")
	await process_frame
	_check(String(lab.get("_mode")) == "items", "чип переключает на предметы")

	# ПОКАЗЫВАЕТСЯ РОВНО ОДНО. Скин и предмет разом читались бы как «предмет
	# надет на героя», чего в игре не бывает.
	var skin_spr : Sprite2D = lab.get("_sprite")
	var item_spr : Sprite2D = lab.get("_item_spr")
	_check(is_instance_valid(item_spr) and item_spr.visible and not skin_spr.visible,
		"на экране предмет, а не скин")

	# Правка из лаборатории обязана дойти ДО ТОГО ЖЕ слоя, что читает забег.
	var first : String = String((lab.LAB_ITEMS[0] as Array)[1])
	TWEAKS.reset(first)
	lab.set("_item", 0)
	lab.call("_bump_item", 0.25, -0.10)
	var lm : Dictionary = TWEAKS.mult_for(first)
	_check(is_equal_approx(float(lm["size"]), 1.25)
			and is_equal_approx(float(lm["hit"]), 0.90),
		"кнопки правят тот же слой, что читает забег: %s" % [lm])

	# СБРОС в режиме предметов сбрасывает предмет, а не скин.
	lab.call("_reset_current")
	_check(not TWEAKS.has_tweak(first), "СБРОС в этом режиме сбрасывает предмет")

	# ОТМЕНА возвращает ОБА слоя, а не только видимый: правки другого режима
	# иначе тихо теряются, и замечаешь это через полчаса.
	lab.call("_bump_item", 0.25, 0.0)
	lab.call("_revert_all")
	_check(not TWEAKS.has_tweak(first), "ОТМЕНА откатывает и правки предметов")

	# Каждый предмет каталога обязан существовать: путь с опечаткой даёт пустую
	# карточку, и заметить это можно только пролистав весь список глазами.
	var missing : Array = []
	for row in lab.LAB_ITEMS:
		var path : String = String((row as Array)[1])
		if load(path) == null:
			missing.append(path)
	_check(missing.is_empty(), "все картинки каталога на месте: %s" % [missing])

	lab.queue_free()
	TWEAKS.restore(snap)
	_finish()

# Пицца — обычный предмет потока: `item.tscn` со спрайтом и круглым хитбоксом.
func _make_pizza() -> Node2D:
	var it : Node2D = load("res://scenes/item.tscn").instantiate()
	it.set("speed", 0.0)
	it.set("is_eatable", true)
	var spr := it.get_node("Sprite2D") as Sprite2D
	spr.texture = load("res://assets/items/pizza.png")
	spr.scale   = Vector2.ONE * 0.09
	var cs := it.get_node("CollisionShape2D") as CollisionShape2D
	var c := CircleShape2D.new()
	c.radius = 28.0
	cs.shape = c
	return it

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
