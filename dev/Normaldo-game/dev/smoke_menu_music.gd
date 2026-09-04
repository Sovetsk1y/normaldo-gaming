extends SceneTree

# Headless-проверка музыки главного меню.
#   godot --headless --path . --script res://dev/smoke_menu_music.gd
#
# Меню молчало, и это никто не ловил: тишина — не ошибка, движок про неё не
# ругается. Теперь в меню крутится трек лудилки, и у этого есть три стыка, где
# всё ломается беззвучно:
#
#   • меню пересобирается на каждый возврат с экрана — трек не должен
#     перезапускаться с нуля;
#   • лудилка играет ТОТ ЖЕ трек — второй проигрыватель звучал бы как две копии
#     одной записи внахлёст;
#   • забег заводит свой трек, а из меню мы приходим с чужим в стволе.
#
# См. /Концепция/UI — паттерны интерфейса.md

const MENU_PATH := "res://assets/slots/slots_music.mp3"
const RUN_PATH  := "res://assets/audio/main_theme.mp3"

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var hud   : Node = game.get_node_or_null("HUD")
	var music : Node = game.get_node_or_null("Music")
	if hud == null or music == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Меню звучит ──")
	await _test_menu_plays(hud, music)
	print("── Пересборка меню ──")
	await _test_rebuild_keeps_playing(hud, music)
	print("── Лудилка не дублирует ──")
	await _test_slots_reuses(hud, music)
	print("── Затухание смерти не глушит новый трек ──")
	await _test_fade_out_then_menu(hud, music)
	print("── Старт забега ──")
	await _test_run_swaps(hud, music)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

func _path_of(music: Node) -> String:
	var st = music.get("stream")
	return "" if st == null else String(st.resource_path)

# ── Тесты ─────────────────────────────────────────────────────────────────────

func _test_menu_plays(hud: Node, music: Node) -> void:
	hud.call("_show_menu")
	await process_frame
	await process_frame
	_check(_path_of(music) == MENU_PATH, "в стволе трек лудилки: %s" % _path_of(music))
	_check(bool(music.get("playing")), "музыка играет")
	_check(String(music.get("bus")) == "Music",
		"на шине Music — значит слушается ползунка настроек")
	var st = music.get("stream")
	_check(st != null and bool(st.get("loop")), "трек зациклен")
	# Нарастание: заводится с -80 и поднимается. Проверяем, что тюн жив, иначе
	# музыка «играет» на неслышимой громкости.
	var db0 : float = float(music.get("volume_db"))
	await _wait(0.6)
	_check(float(music.get("volume_db")) > db0,
		"громкость нарастает (%.1f → %.1f dB)" % [db0, float(music.get("volume_db"))])

func _test_rebuild_keeps_playing(hud: Node, music: Node) -> void:
	await _wait(0.5)
	var pos0 : float = float(music.call("get_playback_position"))
	hud.call("_show_menu")          # возврат с любого экрана пересобирает меню
	await process_frame
	await process_frame
	var pos1 : float = float(music.call("get_playback_position"))
	_check(pos1 >= pos0,
		"трек не откатился на начало (%.2f → %.2f с)" % [pos0, pos1])
	_check(bool(music.get("playing")), "и не оборвался")

func _test_slots_reuses(hud: Node, music: Node) -> void:
	var scr : Node = load("res://scripts/slots_screen.gd").new()
	scr.call("setup", hud)
	hud.add_child(scr)
	for _i in 6:
		await process_frame
	_check(scr.get("_music") == null,
		"экран лудилки не завёл второй проигрыватель")
	_check(bool(music.get("playing")) and _path_of(music) == MENU_PATH,
		"трек меню продолжает идти")
	# Крутилка барабанов — своя, её лудилка обязана поднять в любом случае.
	_check(scr.get("_spin_audio") != null, "звук барабанов на месте")
	scr.free()
	await process_frame

func _test_fade_out_then_menu(hud: Node, music: Node) -> void:
	# Смерть гасит музыку полторы секунды и в конце жмёт stop(). Игрок успевает
	# вернуться в меню раньше — новый трек не должен попасть под чужой тюн.
	music.call("fade_out")
	await _wait(0.3)
	hud.call("_start_menu_music")
	await _wait(1.8)               # заведомо дольше, чем длится затухание
	_check(bool(music.get("playing")), "музыка меню жива после затухания смерти")
	_check(float(music.get("volume_db")) > -40.0,
		"и слышна: %.1f dB" % float(music.get("volume_db")))

func _test_run_swaps(hud: Node, music: Node) -> void:
	# Настоящий старт забега целиком: заставка с пультом, диван, слайд HUD.
	hud.call("_start_game")
	var ok := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		if _path_of(music) == RUN_PATH:
			ok = true
			break
	_check(ok, "забег перевёл музыку на свой трек")
	if not ok:
		return
	_check(bool(music.get("playing")), "трек забега играет")
	var db0 : float = float(music.get("volume_db"))
	await _wait(0.5)
	_check(float(music.get("volume_db")) >= db0,
		"перекрёстное затухание поднимает громкость, а не роняет")
