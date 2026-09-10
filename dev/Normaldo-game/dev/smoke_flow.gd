extends SceneTree

# Headless-проверка ДВУХ ПОРЧ ПОТОКА: зеркала (компас) и гриба.
#   godot --headless --path . --script res://dev/smoke_flow.gd
#
# Проверяется то, что ломается тихо:
#
#   1. Направление потока живёт В ОДНОМ МЕСТЕ. Было двадцать три копии
#      `position.x -= speed * delta` по скриптам предметов; копия, забытая при
#      переезде на общий знак, летела бы влево посреди зеркала — и заметить это
#      можно только глазами и только если повезёт увидеть тот самый предмет.
#   2. Зеркало разворачивает УЖЕ ЛЕТЯЩИХ, а не только новых. Ровно этого просили,
#      и ровно это не проверить на глаз: зеркало держится пять секунд.
#   3. Отсечка за краем меняет СТОРОНУ. Иначе предметы копятся за правым краем до
#      конца забега — счётчик растёт, кадр проседает, а на экране ничего.
#   4. Гриб превращает в пиццу и то, что на экране, и то, что вылетит ПОТОМ.
#   5. Всё это СБРАСЫВАЕТСЯ на старте уровня. Компас перед боссом не имеет права
#      встретить игрока на следующем уровне.
#
# См. /Концепция/Предметы.md, scripts/item_flow.gd

const FLOW    := preload("res://scripts/item_flow.gd")
const SPAWNER := preload("res://scripts/spawner.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 34

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	await process_frame
	print("── Общий знак ──")
	_test_flow()
	print("── Один источник в скриптах ──")
	_test_sources()
	print("── Зеркало ──")
	await _test_mirror()
	print("── Компас ──")
	await _test_compass()
	print("── Гриб ──")
	await _test_shroom()
	_finish()

# ── Общий знак ───────────────────────────────────────────────────────────────

func _test_flow() -> void:
	FLOW.reset()
	_check(FLOW.dir == FLOW.LEFT and not FLOW.mirrored(), "по умолчанию поток идёт влево")

	var n := Node2D.new()
	get_root().add_child(n)
	n.position = Vector2(500.0, 100.0)
	FLOW.advance(n, 100.0, 1.0)
	_check(is_equal_approx(n.position.x, 400.0), "влево: 500 → %.0f" % n.position.x)

	FLOW.dir = FLOW.RIGHT
	_check(FLOW.mirrored(), "знак переключился")
	FLOW.advance(n, 100.0, 1.0)
	_check(is_equal_approx(n.position.x, 500.0), "вправо: 400 → %.0f" % n.position.x)

	# Отсечка обязана сменить сторону. С левой отсечкой при зеркале предмет не
	# улетит НИКОГДА: он уезжает вправо, а проверяют «левее −200».
	var w : float = n.get_viewport_rect().size.x
	n.position.x = w + 400.0
	_check(FLOW.gone(n, 200.0), "за правым краем — улетел")
	n.position.x = -400.0
	_check(not FLOW.gone(n, 200.0), "за левым краем при зеркале — ещё нет")
	FLOW.reset()
	_check(FLOW.gone(n, 200.0), "а без зеркала — улетел")

	# Точка вылета — с той стороны, откуда идёт поток.
	_check(is_equal_approx(FLOW.spawn_x(960.0, 80.0), 1040.0), "вылет справа: 1040")
	FLOW.dir = FLOW.RIGHT
	_check(is_equal_approx(FLOW.spawn_x(960.0, 80.0), -80.0), "вылет слева: −80")
	FLOW.reset()
	n.queue_free()

# ── Один источник ────────────────────────────────────────────────────────────
# Скрипт предмета, оставивший себе свою копию движения, зеркала не заметит.
# Проверяется по исходникам: на глаз двадцать три файла не пересмотришь.
#
# Ищем ЛЮБОЙ сдвиг позиции на `speed * delta` мимо общего знака, а не одну
# знакомую строчку. Первая версия проверки искала ровно
# `position.x -= speed * delta` — и пропустила девочку-зазывалу, которая пишет
# `position.x += _dir.x * speed * delta`. В зеркале она вылетала бы слева и
# тут же уходила за левый край, то есть пропадала бы из игры на пять секунд, а
# тест бы молчал.

# Сет-писы считают ход сами и в зеркале не запускаются вовсе (см. `_run_set_piece`):
# у них хореография с парковкой в заданной точке, отражать её — отдельная работа.
const SETPIECE_OK : Array = ["ninja_item", "bum_barrel",
	# Сватовец: идёт своим шагом и держит щит спереди по ходу. В зеркале не
	# запускается — стоит в `spawner.NO_MIRROR`, и это проверяется ниже, чтобы
	# послабление здесь не пережило причину, по которой дано.
	"police_swat"]
# Не поток: фон, декор и боссы едут своей жизнью.
#
# `club_boss_minion` — оба разом: девочка из потока слушается общего знака,
# миньоны боя приходят с обеих сторон по воле сцены. Обе ветки в одном файле,
# поэтому файл в списке, а верную ветку проверяет отдельная проверка ниже.
const NOT_FLOW : Array = ["background", "bg_rat_run", "couch", "leatherhead",
	"leatherhead_bullet", "club_boss_minion",
	# Автомат в мини-игре: он не летит в потоке, он подъезжает в своей сцене.
	"slots_game",
	# Сам источник: строку он держит в комментарии — тем самым, что объясняет,
	# от чего ушли.
	"item_flow"]

func _test_sources() -> void:
	var d := DirAccess.open("res://scripts")
	_check(d != null, "исходники открылись")
	if d == null:
		return
	var stray : Array = []
	var users : int = 0
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var name := f.get_basename()
		var fa := FileAccess.open("res://scripts/" + f, FileAccess.READ)
		if fa == null:
			continue
		var text := fa.get_as_text()
		if text.contains("ItemFlow.advance"):
			users += 1
		if name in SETPIECE_OK or name in NOT_FLOW:
			continue
		for line in text.split("\n"):
			var t : String = line.strip_edges()
			if t.begins_with("#") or not t.contains("position"):
				continue
			if t.contains("speed * delta") and not t.contains("ItemFlow"):
				stray.append("%s: %s" % [name, t])
	_check(stray.is_empty(), "своей копии движения ни у кого не осталось: %s" % [stray])

	# ПОСЛАБЛЕНИЕ НЕ ДОЛЖНО ПЕРЕЖИТЬ СВОЮ ПРИЧИНУ. Тому, кто считает ход сам,
	# оно дано ровно потому, что в зеркале он не появляется вовсе. Уберут его из
	# `NO_MIRROR` — и он поедет не в ту сторону, а список здесь промолчит.
	var spawner_src := FileAccess.get_file_as_string("res://scripts/spawner.gd")
	var no_mirror : Array = []
	for line in spawner_src.split("\n"):
		if String(line).strip_edges().begins_with("const NO_MIRROR"):
			no_mirror = String(line).split("[")[1].split("]")[0].split(",")
			break
	var listed := ""
	for k in no_mirror:
		listed += String(k)
	_check(listed.contains("swat"),
		"а сватовец за это исключён из зеркала: %s" % [listed.strip_edges()])
	_check(users >= 20, "общий знак читают %d скриптов" % users)

	# Девочка-зазывала: в потоке — по общему знаку, в бою — по воле босса.
	var mf := FileAccess.open("res://scripts/club_boss_minion.gd", FileAccess.READ)
	if mf != null:
		var mt := mf.get_as_text()
		_check(mt.contains("ItemFlow.advance") and mt.contains("_dir.x * speed * delta"),
			"у зазывалы обе ветки: поток по знаку, бой по своей")

# ── Зеркало ──────────────────────────────────────────────────────────────────

func _test_mirror() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var nrm : Node = game.get_node_or_null("Normaldo")
	var bg  : Node = game.get_node_or_null("Background")
	var sp  : Node = game.get_node_or_null("Spawner")
	_check(nrm != null and bg != null and sp != null, "сцена забега собралась")
	if nrm == null or bg == null:
		game.queue_free()
		return

	# Предмет, УЖЕ ЛЕТЯЩИЙ, обязан развернуться вместе с новыми — это и просили.
	var flying := Node2D.new()
	sp.add_child(flying)
	flying.position = Vector2(600.0, 100.0)
	FLOW.advance(flying, 100.0, 1.0)
	var before : float = flying.position.x

	nrm.call("apply_mirror", 5.0)
	_check(FLOW.mirrored(), "зеркало развернуло поток")
	_check(bg.call("trip_on", "mirror"), "и отразил фон")
	_check(not bg.call("trip_on", "invert"), "цвет при этом не тронут")
	FLOW.advance(flying, 100.0, 1.0)
	_check(flying.position.x > before, "летящий развернулся: %.0f → %.0f"
		% [before, flying.position.x])

	# ЗЕРКАЛО НЕ ТРОГАЕТ НИ РУКУ, НИ ЗВУК — этим занимается компас, и путать их
	# нельзя: у них разные предметы и разные обещания.
	_check(float(nrm.get("_invert_remaining")) <= 0.0, "управление не перевёрнуто")
	_check(not bool(nrm.get("_music_reversed")), "музыка не развёрнута")

	# Привязанные к стороне экрана в зеркале не запускаются — вместо них обычная
	# угроза. Проверяем по составу детей: перчатка паркуется у правого края,
	# тачка копов разбивается, пройдя долю экрана слева направо, — из зеркала
	# она разбилась бы в первом же кадре на точке вылета.
	var before_kids : int = sp.get_child_count()
	for _i in 12:
		sp.call("_spawn_level_hazard", "police_car", 100.0, 960.0, 250.0)
	var cops := 0
	for n in sp.get_children():
		if is_instance_valid(n) and String(n.name).to_lower().contains("police"):
			cops += 1
	_check(cops == 0, "тачка копов в зеркале не выезжает: %d" % cops)
	_check(sp.get_child_count() > before_kids, "но что-то вместо неё вылетело")

	# Старт уровня обязан всё вернуть: иначе зеркало перед боссом достаётся
	# следующему уровню.
	sp.call("_start_level")
	_check(not FLOW.mirrored(), "старт уровня вернул поток влево")

	game.queue_free()
	await process_frame
	FLOW.reset()

# ── Компас ───────────────────────────────────────────────────────────────────
# Компас ВЕРНУЛСЯ К СТАРОМУ ПОВЕДЕНИЮ: он ломает РУКУ — пальцы делают не то, что
# просят, — и разворачивает музыку. Мир при этом стоит как стоял.
#
# Отражает мир ЗЕРКАЛО, отдельный предмет. Пока эти двое жили в одном, правка
# одного молча меняла другого; здесь проверяется именно граница между ними.
func _test_compass() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var nrm : Node = game.get_node_or_null("Normaldo")
	var bg  : Node = game.get_node_or_null("Background")
	if nrm == null or bg == null:
		_check(false, "сцена забега не собралась")
		game.queue_free()
		return

	var mus : Node = game.get_node_or_null("Music")
	if mus != null:
		mus.set("stream", load("res://assets/audio/main_theme.mp3"))
		mus.call("play")
		await process_frame

	nrm.call("apply_invert", 5.0)
	_check(float(nrm.get("_invert_remaining")) > 0.0, "компас перевернул управление")
	_check(mus == null or bool(nrm.get("_music_reversed")), "и развернул музыку")
	# А МИР НЕ ТРОГАЕТ. Это и есть граница с зеркалом.
	_check(not FLOW.mirrored(), "но поток идёт как шёл")
	_check(not bg.call("trip_on", "mirror"), "и фон не отражён")

	game.queue_free()
	await process_frame
	FLOW.reset()

# ── Гриб ─────────────────────────────────────────────────────────────────────

func _test_shroom() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var nrm : Node = game.get_node_or_null("Normaldo")
	var bg  : Node = game.get_node_or_null("Background")
	var sp  : Node = game.get_node_or_null("Spawner")
	if nrm == null or bg == null or sp == null:
		game.queue_free()
		return

	# Что-то не-пицца на экране до подбора.
	var junk := Area2D.new()
	junk.set_script(load("res://scripts/compass_item.gd"))
	junk.set("speed", 200.0)
	sp.add_child(junk)
	junk.position = Vector2(400.0, 120.0)
	await process_frame

	# Тему заводим сами: проверка «музыка НЕ развернулась» на тишине прошла бы
	# и с поломанным грибом — реверсить нечего.
	var mus : Node = game.get_node_or_null("Music")
	if mus != null:
		mus.set("stream", load("res://assets/audio/main_theme.mp3"))
		mus.call("play")
		await process_frame

	nrm.call("apply_shroom", 8.0)
	_check(bg.call("trip_on", "invert"), "гриб вывернул цвет фона")
	_check(sp.call("pizza_storm"), "и включил пицца-шторм")
	_check(float(nrm.get("_slow_remaining")) > 0.0, "шаг замедлен")
	# РЕВЕРСА У ГРИБА БОЛЬШЕ НЕТ — ни руки, ни звука. Гриб и так делает три вещи
	# разом: цвета наизнанку, шаг медленнее, всё вокруг пицца. Четвёртая, ломающая
	# руку, превращала его из «накрыло» в «игра сломалась». Реверс уехал туда,
	# где читается как своё, — на компас.
	_check(float(nrm.get("_invert_remaining")) <= 0.0, "а управление НЕ перевёрнуто")
	_check(not bool(nrm.get("_music_reversed")), "и музыка не развёрнута")

	# ВСЁ НА ЭКРАНЕ — пицца. Считаем после кадра: подмена идёт освобождением
	# старого узла, а оно откладывается до конца кадра.
	await process_frame
	await process_frame
	var not_pizza : Array = []
	for n in sp.get_children():
		if n is Node2D and n.get("speed") != null and not n.is_in_group("pizza"):
			not_pizza.append(n.name)
	_check(not_pizza.is_empty(), "на экране одна пицца: лишние %s" % [not_pizza])

	# И ТО, ЧТО ВЫЛЕТИТ ПОТОМ, — тоже. Это вторая половина обещания, и флагом на
	# спавне её не закрыть: проверяем предметом, добавленным ПОСЛЕ гриба.
	var late := Area2D.new()
	late.set_script(load("res://scripts/compass_item.gd"))
	late.set("speed", 200.0)
	sp.add_child(late)
	late.position = Vector2(500.0, 120.0)
	await process_frame
	await process_frame
	var late_left := false
	for n in sp.get_children():
		if is_instance_valid(n) and n.get("speed") != null and n.is_in_group("compass"):
			late_left = true
	_check(not late_left, "вылетевший после гриба тоже стал пиццей")

	game.queue_free()
	await process_frame
	FLOW.reset()

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
