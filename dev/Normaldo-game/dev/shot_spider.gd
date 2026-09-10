extends SceneTree

# Снимки превращения Спайдера в руку.
#   xvfb-run -a godot --path . --script res://dev/shot_spider.gd -- <папка>

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "/tmp/claude-0/shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", true)
	save.set("owned_skins", ["classic", "spider_man"])
	save.set("active_skin", "spider_man")
	save.set("skin_level", 10)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	var nd  : Node2D = game.get_node_or_null("Normaldo")
	var sp  : Node = game.get_node_or_null("Spawner")
	nd.call("reload_skin")
	nd.call("_build_skin_runtime")
	hud.call("_start_game")
	await _wait(2.0)
	sp.call("clear_items")
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size
	nd.position = Vector2(200.0, vp.y * 0.5)
	await _wait(0.4)

	# Добыча на пути паутины — её и утащит.
	sp.call("tutorial_send", "pizza", 2, 120.0)
	await _wait(0.2)
	nd.call("_try_fire_ability", nd.position + Vector2(400.0, 0.0))
	await _wait(0.22)
	get_root().get_texture().get_image().save_png(out + "/spider_hand.png")
	print("XX рука снята, рука=", nd.get("_spider_hand") != null)
	await _wait(1.4)
	get_root().get_texture().get_image().save_png(out + "/spider_back.png")
	print("XX возврат снят, рука=", nd.get("_spider_hand") != null, " поймал=", nd.get("_spider_caught"))
	quit()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
