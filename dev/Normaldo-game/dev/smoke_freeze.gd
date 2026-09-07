extends SceneTree

# ЗАМОРОЗКА ПОТОКА ПРИ НАЛОЖИВШИХСЯ СОБЫТИЯХ.
#   godot --headless --path . --script res://dev/smoke_freeze.gd
#
# Поток предметов останавливают несколько разных вещей: мини-игры, итоговые
# барабаны, замедление времени. Накладываются они запросто — мэджик бокс
# выплёвывает замедляющие пачкой, — и пока заморозка была простым флагом,
# накладка ломала забег насмерть: поток вставал НАВСЕГДА.
#
# Как это выглядело в игре: играешь за мага, часто кастуешь спелл (он превращает
# угрозы в мэджик боксы), ловишь их, из них сыплются замедляющие — и после
# очередного из них предметы перестают появляться вовсе. Экран доигрывает то,
# что уже летело, и пустеет.
#
# Проверяется не «работает ли одно замедление», а именно НАКЛАДКА: одно поверх
# другого, и вложенная пауза поверх обоих.

var _fails  : int = 0
var _checks : int = 0

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
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	if sp == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return
	sp.set("campaign_mode", true)
	sp.set_process(true)

	print("── Наложенные заморозки ──")
	_check(not bool(sp.get("_frozen")), "поток идёт")

	# ДВА ЗАМЕДЛЕНИЯ ВНАХЛЁСТ — ровно тот случай, что ломал забег.
	sp.call("apply_slow_mo", 0.4, 0.5)
	await process_frame
	_check(bool(sp.get("_frozen")), "первое замедление остановило поток")
	sp.call("apply_slow_mo", 0.4, 0.5)
	await process_frame
	_check(bool(sp.get("_frozen")), "второе тоже держит его стоящим")
	# Ждём дольше обоих.
	var t := 0.0
	while t < 3.0 and bool(sp.get("_frozen")):
		await process_frame
		t += 1.0 / 60.0
	_check(not bool(sp.get("_frozen")),
		"и после обоих поток ПОШЁЛ (ждали %.1f с)" % t)
	_check(int(sp.get("_event_pause_depth")) == 0,
		"счётчик пауз вернулся в ноль: %d" % int(sp.get("_event_pause_depth")))

	# ВЛОЖЕННАЯ ПАУЗА. Мини-игра держит поток, замедление берёт и отпускает свою
	# паузу внутри — поток обязан остаться стоять, пока мини-игра не отпустит.
	sp.call("pause_for_event")
	sp.call("apply_slow_mo", 0.4, 0.3)
	var t2 := 0.0
	while t2 < 1.2:
		await process_frame
		t2 += 1.0 / 60.0
	_check(bool(sp.get("_frozen")),
		"пока внешнее событие держит паузу, поток стоит")
	sp.call("resume_after_event")
	await process_frame
	_check(not bool(sp.get("_frozen")), "отпустило — пошёл")

	# ЛИШНИЙ resume ничего не ломает: пары «pause/resume» приходят из разных
	# мест, и один непарный не должен разрешать поток посреди мини-игры.
	sp.call("resume_after_event")
	sp.call("pause_for_event")
	await process_frame
	_check(bool(sp.get("_frozen")), "лишний resume не сбил счётчик")
	sp.call("force_resume")
	await process_frame
	_check(not bool(sp.get("_frozen")) and int(sp.get("_event_pause_depth")) == 0,
		"force_resume снимает заморозку целиком")

	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: %d" % _fails)
	quit(0)
