extends SceneTree

# Кадры боя с КАПИТАНОМ ПОЛИЦИИ — по одному на каждый акт.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_police.gd -- <папка>
#
# ── КАДРЫ СНИМАЮТСЯ ПО СОБЫТИЮ, А НЕ ПО СЕКУНДОМЕРУ ────────────────────────
# Первым заходом здесь стоял список «на 7-й секунде собака, на 24-й штурмовка», и
# это враньё по устройству: акты кончаются НЕ ПО ТАЙМЕРУ. Первый ждёт сигнала от
# собаки, и сколько она пробегает, зависит от того, где стоит Нормальдо и куда
# она отскочит. Секундомер попадал то в акт, то между актами — и кадр «штурмовка»
# приходил пустым, показывая ровно ничего.
#
# Теперь каждый кадр ЖДЁТ СВОЁГО СОСТОЯНИЯ: собаку — когда собака на арене, огонь
# — когда полоса разгорелась целиком. Пустых кадров при таком порядке не бывает:
# либо снято то, что названо, либо истекло ожидание и об этом напечатано.
const POLICE := preload("res://scripts/police_boss.gd")

# Сколько ждём каждое состояние, прежде чем признать, что акт не отработал.
const WAIT_MAX : float = 45.0

var _out : String = "user://shots"

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node   = game.get_node_or_null("HUD")
	var nrm : Node2D = game.get_node_or_null("Normaldo")

	# ── МЕНЮ РАЗБИРАЕМ ДО КОНЦА ──────────────────────────────────────────────
	# Оно живёт CanvasLayer'ом ПОВЕРХ мира, и снятый через него кадр показывает
	# логотип и кнопки, а не арену. Раньше здесь просто ждали пять секунд и
	# снимали — логотип «НОРМАЛЬДО» закрывал полкадра, и по таким снимкам я
	# уверенно рассказывал, что бой читается.
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	boot = 0
	while boot < 2400 and hud.get("_menu_overlay") != null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame

	nrm.call("enable_input")
	nrm.call("set_dev_immortal", true)
	# Голову ставим В СЕРЕДИНУ ЛЕВОЙ ПОЛОВИНЫ: туда идут сватовцы и туда летит
	# собака, и с края кадр читался бы как «никого нет».
	var vp : Vector2 = get_root().get_visible_rect().size
	nrm.position = Vector2(vp.x * 0.26, vp.y * 0.5)
	hud.call("summon_police", true)
	await process_frame

	var boss : Node = null
	for c in game.get_children():
		if c.get_script() == POLICE:
			boss = c

	await _shot(game, "dog", "собака",
		func() -> bool: return _count(game, "police_dog") > 0)
	await _shot(game, "squad", "отряд",
		func() -> bool: return _count(game, "swat") > 0)
	# Полосу ждём РАЗГОРЕВШУЮСЯ, а не первый язык: кадр с тремя огнями из
	# девятнадцати сказал бы про плотность ровно обратное правде.
	await _shot(game, "strafe", "штурмовка",
		func() -> bool: return _count(game, "fire") >= 15)
	await _shot(game, "rope", "трос",
		func() -> bool: return _rope(game) != null)
	await _shot(game, "finale", "пицца на лицо",
		func() -> bool: return _pizza_landed(boss))
	print("saved")
	quit(0)

# ── Ждём состояние и снимаем ───────────────────────────────────────────────
func _shot(game: Node, name: String, what: String, cond: Callable) -> void:
	var t := 0.0
	while t < WAIT_MAX and not bool(cond.call()):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	if t >= WAIT_MAX:
		print("НЕ ДОЖДАЛСЯ: %s" % what)
		return
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/police_%s.png" % [_out, name])
	# И КРУПНО правый край: капитан там ростом с ладонь, а проверять надо
	# фуражку, рацию и пиццу на лице — несколько десятков пикселей.
	var vpz : Vector2i = img.get_size()
	var rect := Rect2i(vpz.x - 320, 0, 320, mini(vpz.y, 320))
	var crop := img.get_region(rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/police_%s_zoom.png" % [_out, name])
	print("снят %s" % what)

func _count(game: Node, group: String) -> int:
	var n := 0
	for c in game.get_children():
		if is_instance_valid(c) and c.is_in_group(group):
			n += 1
	return n

func _rope(game: Node) -> Node:
	for c in game.get_children():
		if is_instance_valid(c) and c is Line2D:
			return c
	return null

# ── ПИЦЦА СЕЛА, А НЕ ЕЩЁ ЛЕТИТ ─────────────────────────────────────────────
# Здесь сначала стояло «ниже −120», и это ловило пиццу НА ПОЛПУТИ: она падает с
# −430, и порог срабатывал задолго до посадки. Хуже того, порог был один и тот же
# независимо от того, куда пицца целится, — два прогона с РАЗНОЙ посадкой дали
# два одинаковых кадра, и по ним я решал, куда её двигать.
#
# Теперь высота берётся из констант самого босса: сравнивать надо с ТОЙ ТОЧКОЙ,
# в которую он её сажает, а не с числом, выдуманным здесь.
func _pizza_landed(boss: Node) -> bool:
	if not is_instance_valid(boss):
		return false
	var land : float = POLICE.COP_PX * POLICE.PIZZA_FACE_Y
	for c in boss.get_children():
		if not (c is Sprite2D):
			continue
		var s := c as Sprite2D
		if s.texture == null:
			continue
		if String(s.texture.resource_path).ends_with("pizza_face.png") \
				and s.position.y >= land - 1.0:
			return true
	return false
