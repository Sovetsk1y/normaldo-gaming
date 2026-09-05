extends SceneTree

# Headless-проверка СТАТУС-ЭФФЕКТОВ.
#   godot --headless --path . --script res://dev/smoke_status.gd
#
# Проверяется не «красиво ли», а два контракта, которые ломаются молча:
#   1. У каждого состояния есть свой значок, и он ВКЛЮЧАЕТСЯ вместе с
#      состоянием и ГАСНЕТ вместе с ним. Не погасший значок — это уже не
#      украшение, а вранье: игрок читает «я замедлен», когда он уже нет.
#   2. Кадры всех эффектов на месте. Папку легко потерять при переносе
#      ассетов, а `attach` в этом случае молча вернёт null — на экране просто
#      ничего не появится, и заметить это можно только глазами и случайно.

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 23

# Все эффекты, которые обязаны лежать на диске. Список ЗДЕСЬ, а не читается из
# папки: тест, спрашивающий у папки, что в ней лежит, согласен с любой папкой.
# Имена СОСТОЯНИЙ, а не папок: папку под состоянием можно поменять (часы и
# шары уже менялись местами), а состояние остаётся тем же.
const WANT : Array = ["slow", "invert", "hourglass", "armor", "heal",
	"stun", "shock", "rage", "blessed", "charm"]

# Состояние без записи в ART грузилось бы по своему имени, а папки с таким
# именем нет — эффект молча не появился бы.
var _art_bad : Array = []

func _check_art(name: String) -> void:
	if not StatusFx.ART.has(name):
		_art_bad.append(name)

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

var _n : Node2D = null

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	_n = game.get_node_or_null("Normaldo")
	if _n == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Кадры на диске ──")
	_test_assets()
	print("── Состояние включает и гасит значок ──")
	await _test_slow()
	await _test_confusion()
	print("── Мгновенные значки ──")
	await _test_burst()
	print("── Вспышка едет за головой ──")
	await _test_flash_follows()
	print("── Сфера резиста ──")
	await _test_sphere()
	print("── Смена режима снимает всё ──")
	await _test_clear()
	_finish()

func _test_assets() -> void:
	var missing : Array = []
	for name in WANT:
		# Путь строим ЧЕРЕЗ ту же таблицу, что и игра: собери его тест сам из
		# имени состояния — и он проверял бы папки, которых нет, а те, что игра
		# правда грузит, остались бы непроверенными.
		_check_art(name)
		var art : String = String(StatusFx.ART.get(name, name))
		for i in StatusFx.FRAMES:
			var p : String = (StatusFx.DIR % art) + "%02d.png" % i
			if not ResourceLoader.exists(p):
				missing.append("%s/%02d" % [name, i])
	_check(missing.is_empty(), "все %d кадров у %d состояний на месте: %s"
		% [StatusFx.FRAMES, WANT.size(), "нет " + str(missing) if missing else "да"])
	_check(_art_bad.is_empty(),
		"у каждого состояния прописана картинка: %s" % ["да" if _art_bad.is_empty() else _art_bad])
	var sf := StatusFx._sprite_frames("slow")
	_check(sf != null and sf.get_frame_count("default") == StatusFx.FRAMES,
		"кадры собираются в анимацию: %d" % (sf.get_frame_count("default") if sf else -1))
	_check(sf != null and sf.get_animation_loop("default"),
		"и она зациклена — статус висит, пока висит состояние")

# Замедление: банан кладёт значок, время его снимает.
func _test_slow() -> void:
	_check(not _has("slow"), "на старте значка замедления нет")
	_n.call("apply_slow", 0.5)
	await _wait_frames(3)
	_check(_has("slow"), "замедлили — значок появился")
	_check(_fx("slow").get_parent() == _n.get_parent(),
		"он у РОДИТЕЛЯ, а не ребёнок головы: голову красят в фиолетовый и качают")
	# Значок обязан ехать за головой, иначе он читается как предмет рядом.
	var was : Vector2 = _fx("slow").global_position
	_n.position += Vector2(60.0, 0.0)
	await _wait_frames(2)
	_check(_fx("slow").global_position != was
			and _fx("slow").global_position.distance_to(_n.global_position) < 1.0,
		"и едет ровно за головой")
	await _wait_real(1.0)
	_check(not _has("slow"), "замедление кончилось — значок погас")

# Проклятие шамана: то же самое, но состояние живёт своим таймером.
func _test_confusion() -> void:
	_n.call("apply_invert", 0.4)
	await _wait_frames(3)
	_check(_has("invert"), "перевёрнутое управление — свой значок")
	await _wait_real(1.0)
	_check(not _has("invert"), "и он гаснет вместе с реверсом")

# Мгновенные значки: появляются и убирают себя сами.
func _test_burst() -> void:
	var host : Node = _n.get_parent()
	var before : int = _count_fx(host)
	StatusFx.burst(host, _n.global_position, "stun", 90.0)
	await _wait_frames(2)
	_check(_count_fx(host) == before + 1, "значок появился одним узлом")
	# Круг анимации — FRAMES/FPS секунд РЕАЛЬНОГО времени.
	await _wait_real(float(StatusFx.FRAMES) / StatusFx.FPS + 0.5)
	_check(_count_fx(host) == before, "и убрал себя сам, без чужой помощи")

# Нимб мешка, плюс жира и звёзды удара — знаки ГОЛОВЫ, и держатся они на ней
# весь круг анимации. Раньше они вешались в точке события и оставались висеть в пустоте:
# за полсекунды голова уезжает через пол-экрана, и знак читался как чужой
# предмет позади.
func _test_flash_follows() -> void:
	_n.call("_status_flash", "heal", 2.0, 0.0)
	await _wait_frames(2)
	_check(_has("heal"), "значок появился")
	_n.position += Vector2(120.0, -40.0)
	await _wait_frames(2)
	_check(_fx("heal").global_position.distance_to(_n.global_position) < 1.0,
		"и поехал вместе с головой, а не остался на месте удара")
	await _wait_real(float(StatusFx.FRAMES) / StatusFx.FPS + 0.5)
	_check(not _has("heal"), "и снял себя сам, доиграв круг")

# Щит резиста — не значок из набора, а СФЕРА, считаемая шейдером. Проверяется
# то, что у значка проверить было нечем: она и правда появляется отдельным
# узлом с материалом, надувается через `open_amount` и уходит сама.
func _test_sphere() -> void:
	_n.call("_sphere_flash", 2.3)
	await _wait_frames(2)
	var s = _fx("sphere")
	_check(s != null, "сфера появилась")
	if s == null:
		return
	_check(s.material is ShaderMaterial,
		"и она считается шейдером, а не проигрывается кадрами")
	# Надувается: сразу после запуска она ещё не раскрыта полностью.
	var open0 : float = float((s.material as ShaderMaterial).get_shader_parameter("open_amount"))
	await _wait_real(0.25)
	var open1 : float = float((s.material as ShaderMaterial).get_shader_parameter("open_amount"))
	_check(open1 > open0, "надувается: %.2f → %.2f" % [open0, open1])
	# Едет за головой, как и все знаки головы.
	_n.position += Vector2(70.0, 0.0)
	await _wait_frames(2)
	_check(is_instance_valid(s)
			and (s as Node2D).global_position.distance_to(_n.global_position) < 1.0,
		"и держится на голове")
	await _wait_real(EnergySphere.life() + 0.4)
	_check(not _has("sphere") and not is_instance_valid(s),
		"а досчитав своё — убралась сама")

func _test_clear() -> void:
	_n.call("apply_slow", 5.0)
	_n.call("apply_invert", 5.0)
	# Замедление включает значок не в момент вызова, а на ближайшем такте: оно
	# ловится по ПЕРЕХОДУ состояния в `_physics_process`, а не событием. Один
	# такт тут и ждём — иначе тест проверяет момент до включения.
	await _wait_frames(3)
	_check(_has("slow") and _has("invert"), "два состояния — два значка")
	_n.call("begin_slots_mode")
	_check(not _has("slow") and not _has("invert"),
		"уход в мини-игру снял оба: там этих состояний нет")

# ── Мелочи ───────────────────────────────────────────────────────────────────

func _fx(name: String) -> Node2D:
	var d : Dictionary = _n.get("_status_fx")
	var n = d.get(name)
	return n if (n != null and is_instance_valid(n)) else null

func _has(name: String) -> bool:
	return _fx(name) != null

func _count_fx(host: Node) -> int:
	var n := 0
	for c in host.get_children():
		if c is AnimatedSprite2D:
			n += 1
	return n

func _wait_frames(k: int) -> void:
	for _i in k:
		get_root().get_tree().paused = false
		await process_frame

# Ждём РЕАЛЬНОЕ время: и таймеры состояний, и таймер самоуничтожения значка
# живут в секундах, а не в кадрах.
func _wait_real(sec: float) -> void:
	var t0 : int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
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
