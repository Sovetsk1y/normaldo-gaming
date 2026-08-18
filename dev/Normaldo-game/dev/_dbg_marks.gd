extends SceneTree
func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var save : Node = get_root().get_node_or_null("SaveData")
	for sid in ["joker", "batman", "viking", "classic"]:
		save.active_skin = sid
		save.skin_level  = 10
		normaldo.call("reload_skin")
		normaldo.call("_build_skin_runtime")
		print(sid, " резисты: ", normaldo.get("_resist_cd_for").keys())
	save.active_skin = "joker"
	normaldo.call("_build_skin_runtime")
	spawner.campaign_mode = true
	spawner.set_process(true)
	for _i in 400:
		await process_frame
	var seen : Dictionary = {}
	for grp in ["obstacle", "slowing", "bomb", "compass", "molotov"]:
		for n in get_root().get_tree().get_nodes_in_group(grp):
			if n is Area2D:
				var tag = normaldo.call("_area_tag", n)
				seen[str(tag)] = int(seen.get(str(tag), 0)) + 1
	print("на экране опасных: ", seen)
	print("состояния: ")
	for grp in ["obstacle", "slowing"]:
		for n in get_root().get_tree().get_nodes_in_group(grp):
			if n is Area2D:
				print("  ", normaldo.call("_area_tag", n), " → ", normaldo.call("resist_state_for", n))
				break
	quit(0)
