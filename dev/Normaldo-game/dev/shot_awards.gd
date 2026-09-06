extends SceneTree

# Кадры экрана достижений — настоящий рендер.
#   xvfb-run -a godot --path . --script res://dev/shot_awards.gd -- <папка> [категория]
#
# Категория — номер вкладки в корешке, 0…11 (см. Achievements.CATEGORIES).
# Без номера снимается «menu» — главный экран с кнопкой достижений: проверять
# надо и то, куда игрок нажимает, а не только то, куда он попадает.
#
# Прогресс НАСТОЯЩИЙ — из achievement_manager.gd. Чтобы кадры были
# воспроизводимы, а не зависели от того, кто сколько наиграл на своей машине,
# счётчики перед съёмкой выставляются здесь же (см. `_pose`): экран для показа
# должен показывать и взятое, и недобранное, и полоски посередине.

func _initialize() -> void:
	await _bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "menu"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud  : Node = game.get_node_or_null("HUD")
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400
	save.tokens  = 37
	_pose(get_root().get_node_or_null("AchievementManager"))

	if mode != "menu":
		hud.call("_show_awards", int(mode))
		# Заезд экрана — 0.45 с; снимать раньше значит поймать его на полпути.
		await _wait(0.9)
	else:
		await _wait(0.6)

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/awards_%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

# Показательная раскладка счётчиков: что-то взято целиком, что-то на полпути,
# что-то не начато. Ставится ЧЕРЕЗ `set_max`, то есть через ту же дверь, что и
# настоящая игра, — иначе кадр показывал бы состояние, в которое игра прийти не
# может.
const POSE : Dictionary = {
	"runs_total": 214, "pizzas_total": 38400, "pizzas_run_best": 412,
	"money_total": 61200, "money_run_best": 240, "fat_max": 3, "uber_runs": 7,
	"episodes_done": 2, "nodmg_episodes": 1, "boss_reached": 1,
	"bosses_beaten": 9, "endless_best": 415, "endless_runs": 22,
	"skins_owned": 6, "skins_bought": 5, "skin_lvl_max": 10, "skins_at_10": 1,
	"spell_casts": 340, "resists": 41, "clean_best": 96, "codex_seen": 31,
	"slot_spins": 63, "slot_best_match": 3, "best_rank_inv": 12,
	"item:money_bag": 34, "item:magic_box": 18, "minigame:fat_boss": 4,
}

func _pose(am: Node) -> void:
	if am == null:
		return
	for k in POSE:
		am.call("set_max", String(k), int(POSE[k]))

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
