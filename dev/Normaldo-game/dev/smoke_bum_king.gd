extends SceneTree

# Headless-проверка босса «Старый пират» (король бомжей).
#   godot --headless --path . --script res://dev/smoke_bum_king.gd
#
# Этот бой не про уворот, а про то, чтобы НЕ УДАРИТЬ, и вся его начинка —
# правила размена. Ломаются они тихо:
#
#   1. БЛОК ПЕРЕСТАЁТ БЫТЬ БЛОКОМ. Кулаки встретились в один кадр, а разбор
#      выдал попадание — потому что проверка попаданий стоит выше ничьей.
#      На экране это выглядит как «иногда блокирует, иногда нет».
#   2. ВОЛНЫ УЧАТ НЕ ТОМУ. Серый ударил на обучении, рыжий начал первым, порядок
#      «сначала блок, потом попадание» перевернулся — и каждое из этих трёх
#      учит игрока обратному тому, ради чего волна и заведена.
#   3. АРЕНА ОТПУСКАЕТ. Нормальдо снова ходит или кастует спелл, и бой
#      превращается в обычный уворот.
#
# См. scripts/bum_king.gd, /Концепция/Босс — Старый пират.md

const BUM_KING := preload("res://scripts/bum_king.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 40

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
	var sp : Node   = game.get_node_or_null("Spawner")
	var n  : Node2D = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	# ── Раскладка эпизодов ──────────────────────────────────────────────────
	# Третий эпизод держал крокодила ВТОРЫМ ЗАХОДОМ — тот же бой два эпизода
	# подряд, помеченный `boss_tmp`. Проверяется и то, что босс встал на место,
	# и то, что метка «взаймы» с него снята: забыть её — значит оставить эпизод
	# в списке недоделанных навсегда.
	print("── Место в кампании ──")
	var lv : Array = sp.CAMPAIGN_LEVELS
	_check(String((lv[2] as Dictionary)["boss"]) == "bum_king",
		"третий эпизод зовёт своего босса: %s" % [(lv[2] as Dictionary)["boss"]])
	_check(not sp.call("boss_is_temp", 2), "и он больше не «взаймы»")
	_check(String((lv[1] as Dictionary)["boss"]) == "croc",
		"крокодил остался на втором")

	# ── Бой ─────────────────────────────────────────────────────────────────
	print("── Арена ──")
	var boss : Node2D = Node2D.new()
	boss.set_script(BUM_KING)
	boss.call("setup", n, sp, game, true)
	game.add_child(boss)
	await _wait(0.2)

	var vp : Vector2 = get_root().get_visible_rect().size
	var crowd : Array = boss.get("_crowd")
	# ТОЛПА ПЛОТНАЯ. Одно кольцо из двадцати шести читалось как хоровод с
	# просветами: сквозь него было видно стену, и «уходить некуда» держалось
	# только на словах.
	_check(crowd.size() >= 70, "толпа плотная: %d бомжей" % crowd.size())
	# И РАЗНОШЁРСТНАЯ: серые с рыжими вперемешку и примерно поровну. Толпа из
	# одного цвета читается как копии одного человека.
	var grey := 0
	var ging := 0
	for c in crowd:
		if (c as Sprite2D).texture == boss.CROWD_TEX[1]: grey += 1
		else: ging += 1
	_check(mini(grey, ging) * 2 >= maxi(grey, ging),
		"серых и рыжих поровну: %d / %d" % [grey, ging])
	# ОВАЛОМ, а не дугой: арена обязана закрывать все стороны, иначе «уходить
	# некуда» перестаёт быть правдой — и игрок первым делом пойдёт в дырку.
	var left := false; var right := false; var up := false; var down := false
	for c in crowd:
		var p : Vector2 = (c as Node2D).position
		if p.x < vp.x * 0.25: left  = true
		if p.x > vp.x * 0.75: right = true
		if p.y < vp.y * 0.25: up    = true
		if p.y > vp.y * 0.75: down  = true
	_check(left and right and up and down,
		"и закрывает арену со всех сторон: л%s п%s в%s н%s"
			% [left, right, up, down])

	# А ВНУТРЬ НЕ ЛЕЗЕТ. Плотная толпа первым делом встала поверх Нормальдо и его
	# противника — кольца считаются от центра экрана, а бой идёт ровно там же, — и
	# кадр читался не как «толпа вокруг», а как каша.
	var inside : Array = []
	var arena : Rect2 = boss.call("_arena_rect")
	for c in crowd:
		if arena.has_point((c as Node2D).position):
			inside.append((c as Node2D).position)
	_check(inside.is_empty(),
		"и не лезет в сцену боя: внутри %d" % inside.size())

	_check(bool(n.get("spells_blocked")),
		"спелл заперт: единственный жест боя занят ударом")

	# АРЕНА ВЫТАЛКИВАЕТ, а не отключает управление. Свайп обязан что-то сделать:
	# молча проглоченный он читается как «игра не поняла». И обязан ВЕРНУТЬ на
	# место — уехавший и оставшийся там Нормальдо это уже движение, то есть тот
	# самый уворот, которого в этом бою нет.
	var home : Vector2 = n.position
	boss.call("_nudge_hero", Vector2(0.0, -1.0))
	await _wait(0.05)
	_check(n.position.distance_to(home) > 1.0,
		"свайп сдвигает: на %.0f px" % n.position.distance_to(home))
	await _wait(0.6)
	_check(n.position.distance_to(home) < 2.0,
		"и пружина возвращает обратно: %.1f px" % n.position.distance_to(home))

	# ── ИНТЕРФЕЙС ЗАБЕГА СПРЯТАН ────────────────────────────────────────────
	# Жира в этом бою нет — у игрока свои три рейки, — а счётчики над ареной с
	# отключённым потоком показывают неподвижные числа. Кнопка паузы остаётся:
	# выйти из боя игрок обязан уметь в любую секунду.
	print("── Чистый экран ──")
	var hud : Node = game.get_node_or_null("HUD")
	var hidden : Array = hud.get("_boss_hidden")
	_check(not hidden.is_empty(), "интерфейс забега спрятан: узлов %d" % hidden.size())
	var pause_btn : Button = hud.get("_pause_btn_hit")
	_check(is_instance_valid(pause_btn) and pause_btn.visible,
		"а кнопка паузы осталась")

	# ── Волна 1: серый не бьёт ВООБЩЕ ───────────────────────────────────────
	print("── Волна 1: серый ──")
	# Ждём выхода волны: до неё идёт реплика босса.
	var waited := await _await_wave(boss, "grey", 12.0)
	_check(String(boss.get("current_wave")) == "grey",
		"волна серого пошла через %.1f c" % waited)
	# ПЕРВЫМ ВЫХОДИТ СЕРЫЙ. homeless2 — серый, homeless1 — рыжий; поменяй их
	# местами, и обучение пойдёт задом наперёд, не сломав ничего видимого.
	var foe : Sprite2D = boss.get("_foe_sprite")
	_check(is_instance_valid(foe) and foe.texture == boss.CROWD_TEX[1],
		"и это СЕРЫЙ бомж, а не рыжий")

	# ОН ПОДХОДИТ, а не появляется на месте. Проверяется движение: выйдя из-за
	# края и встав, он читался бы как «его поставили».
	var fx0 : float = float(boss.get("_foe_x"))
	await _wait(0.35)
	_check(float(boss.get("_foe_x")) < fx0 - 20.0,
		"и идёт на тебя: %.0f → %.0f" % [fx0, float(boss.get("_foe_x"))])
	# Но НЕ ВПЛОТНУЮ: встаёт на дистанции удара. Подошедший вплотную закрыл бы
	# собой и Нормальдо, и оба кулака.
	await _wait(2.0)
	_check(float(boss.get("_foe_x")) > float(boss.get("_hero_x")) + 120.0,
		"и тормозит на дистанции удара: %.0f при герое %.0f"
			% [float(boss.get("_foe_x")), float(boss.get("_hero_x"))])

	# Серый — ЕДИНСТВЕННЫЙ, кто ничего не делает сам, и потому на нём и меряется
	# разбор размена: любой другой противник в этот момент лупил бы по своему
	# расписанию, и «только твой кулак» превращалось бы то в блок, то в размен.
	# ХП ему поднято, чтобы он дожил до конца замеров: это тот же учебный
	# манекен, только не разваливающийся с первого удара.
	boss.set("foe_hp", 9)
	n.set("_dev_immortal", true)   # меряем разбор, а не выживание

	var took0 : int = int(boss.get("hits_taken"))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(0.8)
	_check(int(boss.get("hits_dealt")) >= 1,
		"тап = удар, и он доходит: попаданий %d" % int(boss.get("hits_dealt")))
	_check(int(boss.get("hits_taken")) == took0,
		"а серый не ответил ни разу: %d" % (int(boss.get("hits_taken")) - took0))
	_check(int(boss.get("blocks")) == 0, "и блока на обучении не было")

	# ── Перезарядка ─────────────────────────────────────────────────────────
	# Без неё бой — мэшинг, а весь его смысл в паузе ПЕРЕД ударом. Меряется
	# результат, а не флаг: три тапа подряд обязаны дать РОВНО ОДИН удар, а не
	# «не больше одного» — второе прошло бы и на кулаке, который не летает вовсе.
	print("── Перезарядка ──")
	# И её ВИДНО. Перезарядка без индикатора — правило, которое игрок может
	# только угадать: тапнул, ничего не вылетело, и непонятно, промахнулся ты по
	# кнопке или кулак ещё не вернулся.
	var fill : ColorRect = boss.get("_cd_fill")
	_check(fill != null, "полоска перезарядки есть")
	var before : int = int(boss.get("hits_dealt"))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	boss.call("punch")
	boss.call("punch")
	await _wait(0.8)
	_check(int(boss.get("hits_dealt")) - before == 1,
		"три тапа подряд дают ровно один удар: %d"
			% (int(boss.get("hits_dealt")) - before))
	if fill != null:
		# Полоска показывает СОСТОЯНИЕ, а не украшение: сразу после удара она
		# пустая, через кулдаун — полная.
		boss.set("_p_cd", float(boss.PUNCH_CD))
		await _wait(0.05)
		var short_w : float = fill.size.x
		boss.set("_p_cd", 0.0)
		await _wait(0.05)
		_check(fill.size.x > short_w + 10.0,
			"и она наполняется по мере перезарядки: %.0f → %.0f"
				% [short_w, fill.size.x])

	# ── Три исхода размена ──────────────────────────────────────────────────
	print("── Три исхода размена ──")
	boss.set("blocks", 0)
	boss.set("hits_dealt", 0)
	boss.set("hits_taken", 0)

	# 1. Кулак в кулак — БЛОК, и никто не попал. Оба вылетают в один кадр.
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	boss.call("foe_punch")
	await _wait(0.8)
	_check(int(boss.get("blocks")) == 1,
		"кулак в кулак — блок: %d" % int(boss.get("blocks")))
	_check(int(boss.get("hits_dealt")) == 0 and int(boss.get("hits_taken")) == 0,
		"и НИКТО не попал: %d / %d"
			% [int(boss.get("hits_dealt")), int(boss.get("hits_taken"))])

	# 2. Только твой кулак — попал ты.
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(0.8)
	_check(int(boss.get("hits_dealt")) == 1 and int(boss.get("hits_taken")) == 0,
		"один твой кулак — попал ты: %d / %d"
			% [int(boss.get("hits_dealt")), int(boss.get("hits_taken"))])

	# 3. Только его — получил ты.
	boss.call("foe_punch")
	await _wait(0.8)
	_check(int(boss.get("hits_taken")) == 1,
		"один его кулак — получил ты: %d" % int(boss.get("hits_taken")))

	# ── Волна 2: рыжий отвечает, но не начинает ─────────────────────────────
	print("── Волна 2: рыжий ──")
	boss.set("foe_hp", 0)          # отпускаем манекен — идёт следующая волна
	await _await_wave(boss, "ginger", 8.0)
	_check(String(boss.get("current_wave")) == "ginger", "волна рыжего пошла")
	boss.set("foe_hp", 9)
	# Сам он не начинает НИКОГДА. Ждём заведомо дольше любой его паузы, ничего
	# не делая: ответ — это реакция на удар, а удара нет.
	var quiet : int = int(boss.get("hits_taken"))
	await _wait(2.2)
	_check(int(boss.get("hits_taken")) == quiet,
		"первым не бьёт: получили %d за 2.2 c простоя"
			% (int(boss.get("hits_taken")) - quiet))

	# ПЕРВЫЙ РАЗМЕН — БЛОК, ВТОРОЙ УДАР ДОБИВАЕТ. Отвечает он ровно один раз:
	# второй ответ был бы ударом по игроку от рядового из обучающей волны, а
	# бьёт в этом бою только король.
	boss.set("foe_hp", 2)
	var b0 : int = int(boss.get("blocks"))
	var t0 : int = int(boss.get("hits_taken"))
	var d0 : int = int(boss.get("hits_dealt"))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(1.0)
	_check(int(boss.get("blocks")) == b0 + 1,
		"первый размен с рыжим — блок: %d" % (int(boss.get("blocks")) - b0))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(1.4)
	_check(int(boss.get("hits_dealt")) == d0 + 1,
		"второй удар доходит: %d" % (int(boss.get("hits_dealt")) - d0))
	_check(int(boss.get("hits_taken")) == t0,
		"а сам он по игроку так и не попал: %d" % (int(boss.get("hits_taken")) - t0))

	# ── Волна 3: босс ───────────────────────────────────────────────────────
	print("── Волна 3: сам босс ──")
	boss.set("foe_hp", 0)
	var w := await _await_wave(boss, "king", 14.0)
	_check(String(boss.get("current_wave")) == "king",
		"третья волна — сам босс, через %.1f c" % w)
	_check(int(boss.get("king_hp")) == int(boss.KING_HP),
		"и у него полные %d ХП" % int(boss.get("king_hp")))

	# ЗЛЕЕ С КАЖДЫМ ХП. Проверяется не «есть переменная», а то, что пауза между
	# его ударами вправду сокращается: пять одинаковых попаданий — это не пять
	# ступеней сложности, а пять повторов.
	var gap_full : float = float(boss.call("king_gap"))
	boss.set("king_hp", 1)
	var gap_low : float = float(boss.call("king_gap"))
	_check(gap_low < gap_full * 0.7,
		"с потерей ХП бьёт чаще: %.2f c против %.2f" % [gap_low, gap_full])

	# ── Полосы ──────────────────────────────────────────────────────────────
	# СЕГМЕНТАМИ: сегмент = удар. Заливка на пяти хитах превратила бы каждый в
	# незаметный шаг на 20 %.
	print("── Полосы ХП ──")
	_check((boss.get("_boss_segs") as Array).size() == 5,
		"у босса пять реек: %d" % (boss.get("_boss_segs") as Array).size())
	# ТРИ РЕЙКИ У ИГРОКА, И ОНИ СВОИ, а не его жир. Жир — валюта забега: войти в
	# бой можно и со скинни, и с убером, то есть с одной жизнью или с четырьмя, а
	# бой задуман одинаковым для всех.
	_check((boss.get("_hero_segs") as Array).size() == 3,
		"а у игрока три: %d" % (boss.get("_hero_segs") as Array).size())
	boss.set("hero_hp", 3)
	var hp0 : int = int(boss.get("hero_hp"))
	boss.call("foe_punch")
	await _wait(0.8)
	_check(int(boss.get("hero_hp")) == hp0 - 1,
		"одно попадание — одна рейка: %d → %d" % [hp0, int(boss.get("hero_hp"))])
	var seg : Panel = (boss.get("_hero_segs") as Array)[2]
	_check(is_instance_valid(seg) and seg.modulate.a < 0.5,
		"и сбитая рейка гаснет: %.2f" % seg.modulate.a)

	# ── Победа ──────────────────────────────────────────────────────────────
	print("── Победа ──")
	boss.set("king_hp", 0)
	var gone := await _await_free(boss, 14.0)
	_check(gone, "босс добит и убрался за %.1f c" % 14.0)
	_check(not bool(n.get("spells_blocked")), "спелл разблокирован обратно")

	_finish()

func _await_wave(boss: Node, want: String, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if not is_instance_valid(boss):
			break
		if String(boss.get("current_wave")) == want:
			break
		await process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0

func _await_free(boss: Node, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if not is_instance_valid(boss):
			return true
		await process_frame
	return not is_instance_valid(boss)

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
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
