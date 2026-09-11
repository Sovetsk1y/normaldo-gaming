extends SceneTree

# Снимки меню и настроек на двух языках.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_i18n.gd -- <папка>
#
# Проверяется глазами ровно одно: переводится ли интерфейс, который НИКТО НЕ
# ТРОГАЛ. Ни одно место сборки меню под перевод не правилось — если надписи
# сменились, значит Godot переводит текст у Label и Button сам, и полторы тысячи
# мест вызова переписывать не придётся.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", true)
	save.set("dollars", 12400)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	await _tick(0.8)

	for lang in ["ru", "en"]:
		var loc := get_root().get_node("Loc")
		loc.call("set_language", lang)
		# СЦЕНУ НЕ ПЕРЕСОБИРАЕМ НАРОЧНО. Если надписи сменятся сами, значит смена
		# языка доходит до уже стоящих на экране узлов, и перезапуск игре не нужен.
		await _tick(0.6)
		_save(out, "menu_" + lang)

	# И настройки — там же и переключатель.
	hud.call("_show_settings_modal", "lang")
	await _tick(1.2)
	_save(out, "settings_en")
	quit()

func _save(out: String, name: String) -> void:
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("XX ", name)

func _tick(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
