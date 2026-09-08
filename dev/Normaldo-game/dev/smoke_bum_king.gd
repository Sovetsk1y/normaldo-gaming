extends SceneTree

# Headless-проверка босса «Старый пират» (король бомжей).
#   godot --headless --path . --script res://dev/smoke_bum_king.gd
#
# Бой про ДИСТАНЦИЮ: двигаться можно как обычно, но круг тесный, кулак достаёт
# ровно на длину руки, а противник идёт за тобой сам. Ломается это тихо:
#
#   1. БЛОК ПЕРЕСТАЁТ БЫТЬ БЛОКОМ. Замахи сошлись в один кадр, а разбор выдал
#      попадание — потому что проверка попаданий стоит выше ничьей. На экране
#      это выглядит как «иногда блокирует, иногда нет».
#   2. ДИСТАНЦИЯ ПЕРЕСТАЁТ ЗНАЧИТЬ. Удар начинает доходить с любого расстояния —
#      и весь бой сводится к тому, кто раньше нажал.
#   3. ВОЛНЫ УЧАТ НЕ ТОМУ. Серый ударил на обучении, рыжий начал первым, порядок
#      «сначала блок, потом попадание» перевернулся.
#   4. КРУГ ОТПУСКАЕТ. Нормальдо уходит в толпу, и бой рассыпается.
#
# См. scripts/bum_king.gd, /Концепция/Босс — Старый пират.md

const BUM_KING := preload("res://scripts/bum_king.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 89

# Пауза, за которую кулак успевает дорасти до полного размера: треть замаха
# плюс запас на кадр. Меряем руки только после неё.
const SWING_TIME_GROW : float = 0.14

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
	print("── Место в кампании ──")
	var lv : Array = sp.CAMPAIGN_LEVELS
	_check(String((lv[2] as Dictionary)["boss"]) == "bum_king",
		"третий эпизод зовёт своего босса: %s" % [(lv[2] as Dictionary)["boss"]])
	_check(not sp.call("boss_is_temp", 2), "и он больше не «взаймы»")
	_check(String((lv[1] as Dictionary)["boss"]) == "croc",
		"крокодил остался на втором")

	# ── Арена ───────────────────────────────────────────────────────────────
	print("── Арена ──")
	var boss : Node2D = Node2D.new()
	boss.set_script(BUM_KING)
	boss.call("setup", n, sp, game, true)
	game.add_child(boss)
	await _wait(0.2)

	var vp : Vector2 = get_root().get_visible_rect().size
	var crowd : Array = boss.get("_crowd")
	# ТОЛПА ПЛОТНАЯ И МНОГОЛЮДНАЯ: сквозь редкое кольцо видно стену, и «уходить
	# некуда» держится только на словах.
	_check(crowd.size() >= 100, "толпа плотная: %d бомжей" % crowd.size())
	# Число запоминаем ЧИСЛОМ, а не массивом: `_crowd` возвращается ссылкой, и
	# «сравним размер потом» сравнивало бы массив сам с собой.
	var crowd_n0 : int = crowd.size()
	# И РОСТОМ КАК В ПОТОКЕ. Бомж в забеге — около 66 px на экране; мельче — и
	# толпа читается не как «те самые бомжи», а как их уменьшенные копии.
	var px_min : float = 1e9
	for c in crowd:
		var s : Sprite2D = c
		px_min = minf(px_min, s.texture.get_size().y * s.scale.y)
	_check(px_min >= 50.0, "и ростом не мельче потока: самый мелкий %.0f px" % px_min)
	# РАЗНОШЁРСТНАЯ: серые с рыжими вперемешку и примерно поровну.
	var grey := 0
	var ging := 0
	for c in crowd:
		if (c as Sprite2D).texture == boss.CROWD_TEX[1]: grey += 1
		else: ging += 1
	_check(mini(grey, ging) * 2 >= maxi(grey, ging),
		"серых и рыжих поровну: %d / %d" % [grey, ging])
	# ОВАЛОМ, а не дугой: круг обязан быть закрыт со всех сторон.
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

	# А ВНУТРЬ КРУГА НЕ ЛЕЗЕТ: там дерутся.
	var c_arena : Vector2 = boss.call("_arena_center")
	var r_arena : Vector2 = boss.call("_arena_radii")
	var inside := 0
	for c in crowd:
		if _in_ellipse((c as Node2D).position, c_arena, r_arena):
			inside += 1
	_check(inside == 0, "и не лезет в круг боя: внутри %d" % inside)

	_check(bool(n.get("spells_blocked")),
		"спелл заперт: единственный жест боя занят ударом")

	# ── КРУГ ДЕРЖИТ, НО НЕ ПРИКОВЫВАЕТ ──────────────────────────────────────
	# Управление обычное, то самое, которым играли весь забег. Отнимается ровно
	# одно — право уйти с арены. Раньше Нормальдо был приклеен к точке и свайп
	# отдавал пружиной: замысел держался, но всё выученное за забег на время боя
	# выключалось.
	print("── Движение в круге ──")
	_check(bool(n.call("is_input_enabled")),
		"управление у игрока НЕ отобрано")
	# Внутри круга ходит свободно: сдвинули — там и остался.
	var spot : Vector2 = c_arena + Vector2(r_arena.x * 0.4, -r_arena.y * 0.4)
	n.position = spot
	await _wait(0.2)
	_check(n.position.distance_to(spot) < 4.0,
		"внутри круга ходит свободно: остался в %.0f px от цели"
			% n.position.distance_to(spot))
	# А за круг не пускает — не запретом ввода, а зажимом позиции.
	n.position = Vector2(vp.x * 0.97, vp.y * 0.06)
	await _wait(0.2)
	_check(_in_ellipse(n.position, c_arena, r_arena),
		"а за круг не выпускает: вернулся в %s" % [n.position.round()])

	# ── ИНТЕРФЕЙС ЗАБЕГА СПРЯТАН ────────────────────────────────────────────
	print("── Чистый экран ──")
	var hud : Node = game.get_node_or_null("HUD")
	var hidden : Array = hud.get("_boss_hidden")
	_check(not hidden.is_empty(), "интерфейс забега спрятан: узлов %d" % hidden.size())
	var pause_btn : Button = hud.get("_pause_btn_hit")
	_check(is_instance_valid(pause_btn) and pause_btn.visible,
		"а кнопка паузы осталась")

	# ── Полосы ХП ───────────────────────────────────────────────────────────
	# СЕГМЕНТАМИ: сегмент = удар. И СВОЯ СЛЕВА, ЧУЖАЯ СПРАВА — как стоят сами
	# бойцы. Раньше было наоборот, и в горячий момент рейки читались задом
	# наперёд: игрок смотрел, как «у него убавилось», а убавилось у него самого.
	print("── Полосы ХП ──")
	var hs : Array = boss.get("_hero_segs")
	var bs : Array = boss.get("_boss_segs")
	# СКОЛЬКО У ВЫШЕДШЕГО ХП — СТОЛЬКО И СЕГМЕНТОВ. До волн и на волнах рядовых
	# полоса ОДНА: пять сегментов, из которых четыре погашены весь бой, читались
	# как «бомжа надо бить пять раз». Пять появляются вместе с пиратом — это
	# проверяется ниже, на его волне.
	_check(bs.size() == 1, "у рядового ОДНА рейка: %d" % bs.size())
	_check(hs.size() == 3, "а у игрока три: %d" % hs.size())
	_check((hs[0] as Panel).position.x < (bs[0] as Panel).position.x,
		"своя полоса СЛЕВА, чужая справа: %.0f против %.0f"
			% [(hs[0] as Panel).position.x, (bs[0] as Panel).position.x])
	# И ПОДПИСАНЫ. Две одинаковые полоски по краям экрана ничем не отличаются,
	# кроме цвета, а цвет в драке разбирать некогда.
	var hero_lbl : Label = boss.get("_hero_name")
	_check(is_instance_valid(hero_lbl) and not hero_lbl.text.strip_edges().is_empty(),
		"своя подписана: «%s»" % [hero_lbl.text if hero_lbl != null else ""])

	# ── УДАР — ДАБЛ-ТАП ─────────────────────────────────────────────────────
	# Одиночным тапом бить нельзя: тем же пальцем игрок ВЕДЁТ ГОЛОВУ, и каждое
	# касание для движения засчитывалось ударом — кулак уходил в пустоту, а к
	# моменту, когда он нужен, был на перезарядке.
	print("── Дабл-тап ──")
	boss.set("_running", true)
	var p_before : int = int(boss.get("punches"))
	boss.set("_p_cd", 0.0)
	_tap(boss, Vector2(300.0, 200.0))
	await _wait(0.5)                       # заведомо дольше окна дабл-тапа
	_check(int(boss.get("punches")) == p_before,
		"одиночный тап НЕ бьёт: ударов %d" % (int(boss.get("punches")) - p_before))
	_tap(boss, Vector2(300.0, 200.0))
	_tap(boss, Vector2(306.0, 204.0))      # второй быстро и рядом
	await process_frame
	_check(int(boss.get("punches")) == p_before + 1,
		"а дабл-тап бьёт: ударов %d" % (int(boss.get("punches")) - p_before))

	# ── КУЛАКИ: ОДИН РАЗМЕР И ВЕРНАЯ СТОРОНА ────────────────────────────────
	# Обе ошибки тихие и обе были.
	#
	# РАЗМЕР считался по КАДРУ текстуры, а не по рисунку в нём. У кулака пирата
	# кадр 500×500 при рисунке в 275 по ширине, у зелёного рисунок занимает почти
	# весь кадр — и одно и то же число давало руки, отличающиеся вдвое: игрок бил
	# лапой, а бомж кулачком.
	#
	# СТОРОНА: кулак Нормальдо нарисован костяшками ВПРАВО, кулак пирата — ВЛЕВО,
	# а зеркалили обоих по одному правилу «бьёт влево — отрази». Пират получал
	# свой кулак отражённым и бил тыльной стороной.
	print("── Кулаки ──")
	boss.set("_running", true)
	boss.set("_p_swing", {})
	boss.set("_e_swing", {})
	boss.set("_p_cd", 0.0)
	# Кулаки от прежних ударов живут в кадре ещё четверть секунды. Если их не
	# убрать, в «размен» попадёт чужой замах из прошлой сцены — и мерить будем
	# не то. Первая версия проверки именно на это и попалась.
	for old in _fists_of(boss):
		old.free()
	# Пират бьёт только когда он есть: без спрайта противника `foe_punch()`
	# выходит сразу, и в кадре остаётся один кулак вместо размена.
	boss.call("_spawn_foe", boss.CROWD_TEX[1], boss.FOE_PX, Color.WHITE)
	# Замер — не бой: размен успевает разрешиться и попал бы в счётчики, а по ним
	# ниже проверяются волны. Запоминаем и возвращаем как было.
	var c_hit  : int = int(boss.get("hits_dealt"))
	var c_take : int = int(boss.get("hits_taken"))
	var c_blk  : int = int(boss.get("blocks"))
	n.position = c_arena
	boss.set("_foe_pos", n.position + Vector2(120.0, 0.0))
	boss.call("punch")
	boss.call("foe_punch")
	# Рука ВЫРАСТАЕТ за первую треть замаха. Меряем после того, как выросла:
	# на середине роста две руки честно разного размера, и это не ошибка.
	await _wait(SWING_TIME_GROW)
	var fists : Array = _fists_of(boss)
	_check(fists.size() == 2, "в размене два кулака: %d" % fists.size())
	if fists.size() == 2:
		var w0 : float = _fist_px(fists[0])
		var w1 : float = _fist_px(fists[1])
		_check(absf(w0 - w1) <= maxf(w0, w1) * 0.12,
			"и они ОДНОГО размера: %.0f против %.0f px" % [w0, w1])
		# Игрок бьёт вправо своим «вправо» — зеркалить нечего; пират бьёт влево
		# своим «влево» — тоже. Отражённым в этом размене не должен быть ни один.
		var mirrored : Array = []
		for f in fists:
			if (f as Sprite2D).flip_h:
				mirrored.append((f as Sprite2D).texture.resource_path.get_file())
		_check(mirrored.is_empty(),
			"и ни один не отражён: бьют своей стороной, %s" % [mirrored])
		# ЧЕЙ КУЛАК СВЕРХУ — ТОТ И БИЛ ВТОРЫМ. Бил вторым пират (`foe_punch`
		# вызван после `punch`), значит наверху обязан быть ЕГО кулак: в блоке
		# две руки сходятся в одной точке, и на равном слое встреча не читается.
		var top : Sprite2D = fists[0]
		for f in fists:
			if (f as Sprite2D).z_index > top.z_index:
				top = f
		_check(top.z_index == int(boss.FIST_Z_TOP)
				and top.texture == boss.F_FIST,
			"сверху кулак того, кто ударил ВТОРЫМ: %s на слое %d"
				% [top.texture.resource_path.get_file(), top.z_index])
	boss.set("_p_swing", {})
	boss.set("_e_swing", {})
	# Подставного противника убираем: дальше волны ставят своего.
	boss.call("_clear_foe")
	boss.set("hits_dealt", c_hit)
	boss.set("hits_taken", c_take)
	boss.set("blocks",     c_blk)

	# ── Волна 1: серый ПРЕСЛЕДУЕТ и не бьёт ─────────────────────────────────
	print("── Волна 1: серый ──")
	var waited := await _await_wave(boss, "grey", 12.0)
	_check(String(boss.get("current_wave")) == "grey",
		"волна серого пошла через %.1f c" % waited)
	var foe : Sprite2D = boss.get("_foe_sprite")
	_check(is_instance_valid(foe) and foe.texture == boss.CROWD_TEX[1],
		"и это СЕРЫЙ бомж, а не рыжий")
	var foe_lbl : Label = boss.get("_foe_name")
	_check(is_instance_valid(foe_lbl) and foe_lbl.text.contains("СЕР"),
		"и подпись над его рейками — его: «%s»" % [foe_lbl.text if foe_lbl != null else ""])
	_check(int(boss.get("foe_hp")) == int(boss.FOE_HP),
		"одна рейка: %d" % int(boss.get("foe_hp")))
	# И НА ЭКРАНЕ ОНА ОДНА, а не одна из пяти. Пять сегментов, четыре из которых
	# погашены, читались как «его надо бить пять раз».
	_check((boss.get("_boss_segs") as Array).size() == 1,
		"и полоса у него из одного сегмента: %d"
			% (boss.get("_boss_segs") as Array).size())
	# ПИРАТ ВСЁ ЭТО ВРЕМЯ СТОИТ В ТОЛПЕ — его зовут из кольца, а не подвозят
	# из-за края экрана, когда придёт очередь.
	var king_in_crowd : Sprite2D = boss.get("_king_crowd")
	_check(is_instance_valid(king_in_crowd) and king_in_crowd.texture == boss.F_IDLE,
		"а пират ждёт своей очереди В ТОЛПЕ")
	# И РЯДОВОЙ ТОЖЕ ВЫШЕЛ ИЗ КОЛЬЦА, а не из-за края: он появился внутри экрана,
	# и в толпе стало на одного меньше — это и есть тот, кто вышел.
	_check((boss.get("_crowd") as Array).size() < crowd_n0
			and is_instance_valid(foe) and foe.position.x < vp.x,
		"и вышел он ИЗ ТОЛПЫ: в кольце стало %d вместо %d, и он внутри экрана"
			% [(boss.get("_crowd") as Array).size(), crowd_n0])
	# ЧЕМ БИТЬ — НАПИСАНО НА ЭКРАНЕ. Жест здесь не тот, что в забеге: там тем же
	# дабл-тапом кастуют спелл, и догадаться об этом неоткуда.
	var hint : Label = boss.get("_hint")
	_check(is_instance_valid(hint) and hint.text.contains("ДВОЙНОЕ"),
		"подсказка про двойное нажатие на экране: «%s»"
			% [hint.text if hint != null else ""])

	# ПРЕСЛЕДУЕТ ПО ВСЕМУ КРУГУ, а не едет по одной горизонтали. Ставим героя в
	# сторону и смотрим, что противник пошёл ЗА НИМ, в том числе по вертикали:
	# едущий по прямой враг свободному игроку не соперник — от него достаточно
	# отойти вбок.
	n.set("_dev_immortal", true)
	n.position = c_arena + Vector2(-r_arena.x * 0.5, r_arena.y * 0.6)
	# Сперва он ВХОДИТ — идёт от края к кругу, и это не преследование: пока он
	# входит, круг его не держит и цель у него другая. Меряем погоню после входа.
	var t_in := Time.get_ticks_msec()
	while String(boss.get("_foe_state")) == "enter" \
			and float(Time.get_ticks_msec() - t_in) < 6000.0:
		await process_frame
	_check(String(boss.get("_foe_state")) != "enter",
		"вошёл в круг своим ходом за %.1f c"
			% (float(Time.get_ticks_msec() - t_in) / 1000.0))
	var p0 : Vector2 = boss.get("_foe_pos")
	await _wait(1.2)
	var p1 : Vector2 = boss.get("_foe_pos")
	_check(p1.distance_to(n.position) < p0.distance_to(n.position) - 20.0,
		"идёт за тобой: %.0f → %.0f px до героя"
			% [p0.distance_to(n.position), p1.distance_to(n.position)])
	_check(absf(p1.y - p0.y) > 8.0,
		"и по вертикали тоже, а не по одной линии: %.0f px" % absf(p1.y - p0.y))

	# ── ДИСТАНЦИЯ РЕШАЕТ ────────────────────────────────────────────────────
	# Удар — замах на длину руки, а не летящий снаряд. Издалека он не достаёт, и
	# это главное правило боя: подойти — это ход.
	print("── Дистанция ──")
	boss.set("foe_hp", 9)      # учебный манекен: меряем разбор, а не выживание
	boss.set("_foe_state", "") # и стоящий смирно: преследование сейчас мешает
	var far : Vector2 = c_arena + Vector2(r_arena.x * 0.9, 0.0)
	n.position = c_arena - Vector2(r_arena.x * 0.9, 0.0)
	boss.set("_foe_pos", far)
	var d0 : int = int(boss.get("hits_dealt"))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(0.6)
	_check(int(boss.get("hits_dealt")) == d0,
		"издалека удар НЕ достаёт: попаданий %d" % (int(boss.get("hits_dealt")) - d0))

	# А ТУДА, КУДА ДОЕЗЖАЕТ РИСУНОК КУЛАКА, — доходит. Ставим противника на две
	# трети дальности: раньше засчитывалось только вплотную (166 px от центра до
	# центра), при том что картинка кулака в 215 px проезжала по нему задолго до
	# этого — игрок видел, как рука проходит сквозь бомжа, и ничего не менялось.
	var reach : float = float(boss.SWING_REACH) + float(boss.FIST_R)
	boss.set("_foe_pos", n.position + Vector2(reach * 0.95, 0.0))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(0.6)
	_check(int(boss.get("hits_dealt")) == d0 + 1,
		"а на длину руки (%.0f px) доходит: %d"
			% [reach * 0.95, int(boss.get("hits_dealt")) - d0])
	# И РАНЬШЕ ЭТОГО НЕ ДОХОДИЛО БЫ. Проверка держит саму починку: вернись
	# дальность к «центр в центр» — и этот удар снова станет промахом.
	_check(reach * 0.95 > float(boss.SWING_REACH) + float(boss.HEAD_R),
		"и это дальше прежнего «вплотную»: %.0f против %.0f px"
			% [reach * 0.95, float(boss.SWING_REACH) + float(boss.HEAD_R)])
	# УДАР РАЗВОДИТ ОБОИХ. После размена бойцы обязаны разойтись: стоящие вплотную
	# начинают следующий размен без дистанции, то есть без самой игры.
	# Ставим на дистанцию удара заново: прошлое попадание уже развело их, и
	# следующий удар просто не дошёл бы — мерили бы «два промаха».
	boss.set("_foe_pos", n.position + Vector2(120.0, 0.0))
	var gap_before : float = n.position.distance_to(boss.get("_foe_pos"))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(0.5)
	_check(n.position.distance_to(boss.get("_foe_pos")) > gap_before + 20.0,
		"попадание разводит обоих: %.0f → %.0f px"
			% [gap_before, n.position.distance_to(boss.get("_foe_pos"))])

	# И СМОТРИТ ОН НА ПРОТИВНИКА, а не туда, куда последний раз вели пальцем.
	boss.set("_foe_pos", n.position - Vector2(140.0, 0.0))
	await _wait(0.2)
	_check(bool(n.get("_facing_left")),
		"противник слева — Нормальдо смотрит влево")
	boss.set("_foe_pos", n.position + Vector2(140.0, 0.0))
	await _wait(0.2)
	_check(not bool(n.get("_facing_left")),
		"противник справа — и он разворачивается вправо")

	# ПОЛУЧИЛ — МИГНУЛ КРАСНЫМ. Попадание обязано быть видно на том, кто его
	# получил: рейка стоит в верху экрана, куда в размене не смотрят. Бьём ещё
	# раз и следим за спрайтом с этого момента — вспышка коротка, и по следам
	# прошлого удара её уже не поймать. Ставим его обратно на дистанцию удара:
	# прошлое попадание только что развело их.
	boss.set("_foe_pos", n.position + Vector2(120.0, 0.0))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	var hurt : Sprite2D = boss.get("_foe_sprite")
	var reddened := false
	var t_red := Time.get_ticks_msec()
	while is_instance_valid(hurt) and float(Time.get_ticks_msec() - t_red) < 600.0:
		if hurt.modulate.r > hurt.modulate.g + 0.2:
			reddened = true
			break
		await process_frame
	_check(reddened, "и получивший МИГАЕТ КРАСНЫМ")
	# Дать замаху доиграть: пока он в кадре, следующий удар не начнётся, и
	# проверка перезарядки ниже мерила бы не перезарядку, а этот хвост.
	await _wait(0.4)
	_check(int(boss.get("hits_taken")) == 0,
		"а серый не ответил ни разу: %d" % int(boss.get("hits_taken")))
	_check(int(boss.get("blocks")) == 0, "и блока на обучении не было")

	# ── Перезарядка ─────────────────────────────────────────────────────────
	# Меряется результат, а не флаг: три тапа подряд обязаны дать РОВНО ОДИН
	# удар, а не «не больше одного» — второе прошло бы и на неработающем ударе.
	print("── Перезарядка ──")
	var fill : ColorRect = boss.get("_cd_fill")
	_check(fill != null, "полоска перезарядки есть")
	var before : int = int(boss.get("hits_dealt"))
	# Ставим его обратно на дистанцию удара: каждое попадание отбрасывает
	# противника назад, и после двух предыдущих он уже вне досягаемости — три
	# тапа дали бы ноль попаданий, и провалилась бы проверка перезарядки, хотя
	# перезарядка тут ни при чём.
	boss.set("_foe_pos", n.position + Vector2(120.0, 0.0))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	boss.call("punch")
	boss.call("punch")
	await _wait(0.8)
	_check(int(boss.get("hits_dealt")) - before == 1,
		"три тапа подряд дают ровно один удар: %d"
			% (int(boss.get("hits_dealt")) - before))
	if fill != null:
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
	boss.set("_foe_pos", n.position + Vector2(90.0, 0.0))

	# 1. Замах в замах — БЛОК, и никто не попал.
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	boss.call("foe_punch")
	await _wait(0.8)
	_check(int(boss.get("blocks")) == 1,
		"замах в замах — блок: %d" % int(boss.get("blocks")))
	_check(int(boss.get("hits_dealt")) == 0 and int(boss.get("hits_taken")) == 0,
		"и НИКТО не попал: %d / %d"
			% [int(boss.get("hits_dealt")), int(boss.get("hits_taken"))])

	# 2. Только твой замах — попал ты.
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(0.8)
	_check(int(boss.get("hits_dealt")) == 1 and int(boss.get("hits_taken")) == 0,
		"один твой замах — попал ты: %d / %d"
			% [int(boss.get("hits_dealt")), int(boss.get("hits_taken"))])

	# 3. Только его — получил ты.
	boss.call("foe_punch")
	await _wait(0.8)
	_check(int(boss.get("hits_taken")) == 1,
		"один его замах — получил ты: %d" % int(boss.get("hits_taken")))

	# ── Волна 2: рыжий отвечает, но не начинает ─────────────────────────────
	print("── Волна 2: рыжий ──")
	boss.set("foe_hp", 0)          # отпускаем манекен — идёт следующая волна
	await _await_wave(boss, "ginger", 8.0)
	_check(String(boss.get("current_wave")) == "ginger", "волна рыжего пошла")
	_check(int(boss.get("foe_hp")) == int(boss.FOE_HP),
		"и у него одна рейка: %d" % int(boss.get("foe_hp")))
	boss.set("_foe_state", "")
	boss.set("_foe_pos", n.position + Vector2(90.0, 0.0))
	# Сам он не начинает НИКОГДА: ответ — это реакция на удар, а удара нет.
	var quiet : int = int(boss.get("hits_taken"))
	await _wait(2.2)
	_check(int(boss.get("hits_taken")) == quiet,
		"первым не бьёт: получили %d за 2.2 c простоя"
			% (int(boss.get("hits_taken")) - quiet))

	# ИЗДАЛЕКА ОН НЕ ОТВЕЧАЕТ. Раньше рыжий отвечал на ЛЮБОЙ замах, хоть с другого
	# конца арены: игрок бил в воздух, рыжий — в свой, и совпадение по времени
	# засчитывалось блоком. Блок — это встреча двух кулаков, а не два промаха.
	var far_b : int = int(boss.get("blocks"))
	boss.set("_foe_pos", c_arena + Vector2(r_arena.x * 0.95, 0.0))
	n.position = c_arena - Vector2(r_arena.x * 0.95, 0.0)
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(1.0)
	_check(int(boss.get("blocks")) == far_b,
		"через всю арену он НЕ отвечает: блоков %d"
			% (int(boss.get("blocks")) - far_b))

	# ПЕРВЫЙ РАЗМЕН — БЛОК, ВТОРОЙ УДАР ДОБИВАЕТ. Блок не тратит его рейку, он
	# её откладывает; отвечает рыжий ровно один раз.
	n.position = c_arena
	boss.set("_foe_pos", n.position + Vector2(90.0, 0.0))
	var b0 : int = int(boss.get("blocks"))
	var t0 : int = int(boss.get("hits_taken"))
	var dd : int = int(boss.get("hits_dealt"))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(1.0)
	_check(int(boss.get("blocks")) == b0 + 1,
		"первый размен с рыжим — блок: %d" % (int(boss.get("blocks")) - b0))
	boss.set("_foe_pos", n.position + Vector2(90.0, 0.0))
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	await _wait(1.4)
	_check(int(boss.get("hits_dealt")) == dd + 1,
		"второй удар доходит: %d" % (int(boss.get("hits_dealt")) - dd))
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
	# И ТОЛЬКО ТЕПЕРЬ ПОЛОСА СТАНОВИТСЯ НА ПЯТЬ. До него на ней стояла одна рейка
	# рядового: длина полосы и говорит, кто вышел.
	_check((boss.get("_boss_segs") as Array).size() == int(boss.KING_HP),
		"и полоса выросла до пяти сегментов: %d"
			% (boss.get("_boss_segs") as Array).size())
	var king_lbl : Label = boss.get("_foe_name")
	_check(is_instance_valid(king_lbl) and king_lbl.text.contains("ПИРАТ"),
		"и подписана его именем: «%s»" % [king_lbl.text if king_lbl != null else ""])
	# ВЫХОДИТ ОН НЕ СРАЗУ: сперва толпа его зовёт, и только потом он шагает из
	# кольца. Мгновенный выход означал бы, что зов не успел прочитаться.
	var king_ring : Sprite2D = boss.get("_king_crowd")
	var ring_at : Vector2 = king_ring.position if is_instance_valid(king_ring) \
		else Vector2.ZERO
	var t_out := Time.get_ticks_msec()
	while is_instance_valid(boss.get("_king_crowd")) \
			and float(Time.get_ticks_msec() - t_out) / 1000.0 < 6.0:
		await process_frame
	var called : float = float(Time.get_ticks_msec() - t_out) / 1000.0
	_check(called >= float(boss.KING_CALL_TIME) * 0.5,
		"толпа зовёт его %.1f c, и только потом он выходит" % called)
	# ВЫШЕЛ ОН ИЗ ТОЛПЫ, а не из-за края экрана: копии в кольце больше нет, а сам
	# он стоит там, где она стояла, — внутри экрана, а не за ним.
	_check(not is_instance_valid(boss.get("_king_crowd")),
		"из толпы он ВЫШЕЛ: копии в кольце не осталось")
	_check(ring_at.distance_to(boss.get("_foe_pos")) < 40.0,
		"и появился РОВНО ТАМ, где стоял в кольце: %.0f px от места"
			% ring_at.distance_to(boss.get("_foe_pos")))
	var king_at : Vector2 = boss.get("_foe_pos")
	_check(king_at.x < vp.x,
		"и вышел он ИЗНУТРИ экрана, а не из-за края: x = %.0f при ширине %.0f"
			% [king_at.x, vp.x])
	# И ОН ЕДИНСТВЕННЫЙ, КТО НАПАДАЕТ САМ: рядовые только преследуют и отвечают.
	_check(bool(boss.get("_foe_attacks")), "и он нападает сам")

	# ЗЛЕЕ С КАЖДОЙ РЕЙКОЙ. Проверяется не «есть переменная», а то, что отдышка
	# между бросками вправду сокращается.
	var gap_full : float = float(boss.call("king_gap"))
	boss.set("king_hp", 1)
	var gap_low : float = float(boss.call("king_gap"))
	_check(gap_low < gap_full * 0.7,
		"с потерей ХП бросается чаще: %.2f c против %.2f" % [gap_low, gap_full])
	boss.set("king_hp", int(boss.KING_HP))

	# РЫВОК ЕСТЬ. Он и делает бой боем: подойти и уйти надо успеть между
	# бросками, а стоящий столбом враг свободному игроку не соперник.
	var saw_dash := false
	var t_end := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < t_end:
		var st : String = String(boss.get("_foe_state"))
		if st == "dash" or st == "charge":
			saw_dash = true
			break
		await process_frame
	_check(saw_dash, "и бросается на тебя, а не стоит столбом")

	# ── УМ КОРОЛЯ ───────────────────────────────────────────────────────────
	# Он был лёгким не из-за чисел, а из-за рисунка: приходил по прямой и стоял
	# в заряде, то есть сам подходил под кулак и ждал. Проверяется поэтому не
	# «стало сложнее», а каждое из решений, которые у него появились.
	print("── Ум короля ──")
	n.position = c_arena
	boss.set("hero_hp", 3)

	# КРУЖИТ. За полторы секунды обхода направление на него обязано смениться:
	# идущий по прямой держит угол, а этот заходит то с одной стороны, то с
	# другой — стоять и ждать его на длине руки больше нельзя.
	# Ставим его В СЕРЕДИНУ его полосы: оказавшись ближе, он сперва разрывает
	# дистанцию, и почти всё смещение уходит по радиусу, а не по кругу.
	var band_mid : float = float(boss.call("_king_near")) + float(boss.KING_BAND) * 0.5
	boss.set("_foe_pos", c_arena + Vector2(band_mid, 0.0))
	boss.call("_enter_stalk")
	var axis0 : Vector2 = (Vector2(boss.get("_foe_pos")) - n.position).normalized()
	var near_seen : float = 1e9
	# Меряется НАИБОЛЬШЕЕ боковое смещение за окно, и в пикселях, а не в градусах.
	# Во-первых, сторону обхода он меняет сам и к концу окна может вернуться почти
	# туда же — по концам это выглядело бы как «стоял на месте». Во-вторых, угол
	# здесь обманывает: арена низкая, а держится он далеко, и на его дистанции
	# даже полный уход вбок — это доли радиана.
	var swing_max : float = 0.0
	var t_orb := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t_orb) < 2000.0 and is_instance_valid(boss):
		if String(boss.get("_foe_state")) == "stalk":
			near_seen = minf(near_seen,
				n.position.distance_to(boss.get("_foe_pos")))
			var off : Vector2 = Vector2(boss.get("_foe_pos")) - n.position
			swing_max = maxf(swing_max, absf(off.dot(axis0.orthogonal())))
		boss.set("hero_hp", 3)
		await process_frame
	_check(swing_max > 40.0,
		"кружит вокруг, а не идёт по прямой: уходил вбок на %.0f px" % swing_max)
	# И ДЕРЖИТ ПОЛОСУ: вплотную не липнет, драться в упор не даёт.
	_check(near_seen >= float(boss.call("_king_near")) * 0.7,
		"и держится ДАЛЬШЕ твоей руки: ближе всего подошёл на %.0f px при полосе от %.0f"
			% [near_seen, float(boss.call("_king_near"))])

	# ЧИТАЕТ ЗАМАХ. Двадцать четыре удара в упор — хоть на один он обязан
	# ответить блоком или уходом. Ноль ответов значит, что чтение отвалилось.
	var reads := 0
	for i in 24:
		boss.call("_enter_stalk")
		boss.set("_foe_pos", n.position + Vector2(150.0, 0.0))
		boss.set("_p_cd", 0.0)
		boss.set("_p_swing", {})
		boss.call("punch")
		await process_frame
		var st2 : String = String(boss.get("_foe_state"))
		if st2 == "parry" or st2 == "backstep":
			reads += 1
		boss.set("hero_hp", 3)
	_check(reads > 0, "читает замах: ответил на %d из 24" % reads)
	boss.set("_p_swing", {})
	boss.set("_e_swing", {})

	# ФИНТИТ. Часть зарядов — обман, и решается это на входе в заряд, а не в
	# середине: решай он посреди, телеграф был бы честным ровно до того момента,
	# когда врать выгодно.
	var feints := 0
	for i in 24:
		boss.call("_enter_charge")
		if bool(boss.get("_feint")):
			feints += 1
	_check(feints > 0, "финтит: обманных зарядов %d из 24" % feints)
	# И финт кончается ОТСКОКОМ, а не рывком.
	boss.set("_foe_state", "charge")
	boss.set("_foe_state_t", 0.0)
	boss.set("_feint", true)
	boss.set("_foe_pos", n.position + Vector2(200.0, 0.0))
	await _wait(0.5)
	_check(String(boss.get("_foe_state")) != "dash",
		"и финт кончается не рывком: %s" % [String(boss.get("_foe_state"))])

	# БЬЁТ ПО ЛИНИИ, А НЕ В ТОЧКУ. Ушёл вбок — его удар прошёл мимо. Раньше он
	# целился туда, где игрок оказывался НА МОМЕНТ БРОСКА, и уйти от рывка было
	# нельзя никак: заряд обещал линию, а удар приходил по тебе.
	boss.call("_enter_stalk")
	boss.set("_e_swing", {})
	boss.set("_foe_pos", n.position + Vector2(150.0, 0.0))
	var t_line : int = int(boss.get("hits_taken"))
	boss.set("hero_hp", 3)
	boss.call("foe_punch", n.position)          # бьёт в точку, где игрок стоит
	n.position = n.position + Vector2(0.0, 120.0)   # ...а игрок ушёл вбок
	await _wait(0.6)
	_check(int(boss.get("hits_taken")) == t_line,
		"ушёл с линии — его удар мимо: получил %d"
			% (int(boss.get("hits_taken")) - t_line))
	# А оставшись на линии — получаешь.
	boss.set("_e_swing", {})
	boss.set("_foe_pos", n.position + Vector2(150.0, 0.0))
	boss.call("foe_punch", n.position)
	await _wait(0.6)
	# Здесь важно «дошло», а не «ровно один»: пока идёт замер, свой ход делает и
	# сам бой — джеб после отдышки прилетает вторым, и точное число ловило бы не
	# правило, а совпадение.
	_check(int(boss.get("hits_taken")) >= t_line + 1,
		"а на линии — получаешь: %d" % (int(boss.get("hits_taken")) - t_line))

	# ОТДЫШКА ЧЕСТНАЯ: в ней он не читает. Это не поблажка, а весь смысл его
	# броска — он рискует, ты наказываешь. Читай он и здесь, наказывать было бы
	# негде, и бой стал бы лотереей «дадут ли ударить».
	var read_in_rec := 0
	for i in 24:
		boss.set("_foe_state", "recover")
		boss.set("_foe_state_t", 0.0)
		boss.set("_foe_pos", n.position + Vector2(150.0, 0.0))
		boss.set("_p_cd", 0.0)
		boss.set("_p_swing", {})
		boss.call("punch")
		if String(boss.get("_foe_state")) != "recover":
			read_in_rec += 1
		boss.set("hero_hp", 3)
	_check(read_in_rec == 0,
		"в отдышке он НЕ читает: ответил %d раз из 24" % read_in_rec)
	boss.set("_p_swing", {})
	boss.set("_e_swing", {})

	# СТОЙКОСТЬ. Сбивает его каждый второй удар: пока сбивало каждое попадание,
	# размен с ним был бесплатным — бей, и его заряд не доходит никогда.
	boss.set("_king_hits", 0)
	boss.set("king_hp", 5)
	boss.set("_foe_state", "charge")
	boss.set("_foe_state_t", 0.0)
	boss.set("_foe_pos", n.position + Vector2(150.0, 0.0))
	boss.call("_land_on_foe")
	_check(String(boss.get("_foe_state")) == "charge",
		"первое попадание заряд НЕ сбивает: %s" % [String(boss.get("_foe_state"))])
	boss.set("_foe_state", "charge")
	boss.set("_foe_state_t", 0.0)
	boss.set("_foe_pos", n.position + Vector2(150.0, 0.0))
	boss.call("_land_on_foe")
	_check(String(boss.get("_foe_state")) == "recover",
		"а второе — сбивает: %s" % [String(boss.get("_foe_state"))])
	boss.set("king_hp", int(boss.KING_HP))

	# ── Одно попадание — одна рейка ─────────────────────────────────────────
	print("── Рейки ──")
	boss.set("hero_hp", 3)
	boss.set("_foe_state", "")
	boss.set("_foe_pos", n.position + Vector2(90.0, 0.0))
	var hp0 : int = int(boss.get("hero_hp"))
	boss.call("foe_punch")
	await _wait(0.8)
	_check(int(boss.get("hero_hp")) == hp0 - 1,
		"одно попадание — одна рейка: %d → %d" % [hp0, int(boss.get("hero_hp"))])
	var seg : Panel = (boss.get("_hero_segs") as Array)[2]
	_check(is_instance_valid(seg) and seg.modulate.a < 0.5,
		"и сбитая рейка гаснет: %.2f" % seg.modulate.a)
	# И ПОСЛЕ СВОЕГО ПОПАДАНИЯ ОН НЕ СТОИТ В ТВОЕЙ ТОЧКЕ. Рывок целился ровно в
	# позицию головы, и не ушедший игрок обнаруживал пирата прямо в себе.
	_check(n.position.distance_to(boss.get("_foe_pos")) >= float(boss.call("_min_gap")),
		"ударив, он не оказывается в твоей позиции: %.0f px при минимуме %.0f"
			% [n.position.distance_to(boss.get("_foe_pos")),
				float(boss.call("_min_gap"))])

	# И В РЫВКЕ ТОЖЕ НЕ ПРОХОДИТ НАСКВОЗЬ: круг тесный, разогнаться он успевает
	# по-настоящему, а сойтись в одну точку не должен ни разу.
	boss.set("_foe_state", "approach")
	var min_seen : float = 1e9
	var t_dash := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t_dash) < 5000.0 and is_instance_valid(boss):
		# Рейки игроку возвращаем: здесь меряется дистанция, а не выживание, а
		# король за пять секунд успевает добить — и до финала дело бы не дошло.
		boss.set("hero_hp", 3)
		min_seen = minf(min_seen, n.position.distance_to(boss.get("_foe_pos")))
		await process_frame
	_check(min_seen >= float(boss.call("_min_gap")) - 4.0,
		"и в разгоне ближе минимума не подходит: %.0f px" % min_seen)

	# ── Победа ──────────────────────────────────────────────────────────────
	# Финал длинный — падение, пицца, разбег толпы, вынос — и ломается он молча:
	# любой шаг может не сыграть, а бой всё равно кончится и босс уберётся.
	# Поэтому проверяются сами шаги, пока они идут.
	print("── Победа ──")
	var fallen : Sprite2D = boss.get("_foe_sprite")
	boss.set("king_hp", 0)

	# ПАДАЕТ НАБОК. Не оседает и не исчезает: заваливается и остаётся лежать —
	# дальше в этом же положении его и унесут.
	var laid := false
	var fin_end := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < fin_end and is_instance_valid(boss):
		if is_instance_valid(fallen) and absf(fallen.rotation) > 1.2:
			laid = true
			break
		await process_frame
	_check(laid, "босс заваливается набок: поворот %.2f"
		% (fallen.rotation if is_instance_valid(fallen) else 0.0))

	# И СВЕРХУ ПАДАЕТ ПИЦЦА — тот же знак, что у крокодила: «босс кончился».
	var pie_seen := false
	fin_end = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < fin_end and is_instance_valid(boss):
		if _pizza_of(boss) != null:
			pie_seen = true
			break
		await process_frame
	_check(pie_seen, "и на него падает пицца")

	# ТРОЕ ОСТАЮТСЯ, остальные разбегаются. Проверяется, что толпа именно
	# редеет: расходящийся овал целиком читался бы как обратная перемотка входа.
	fin_end = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < fin_end and is_instance_valid(boss):
		await process_frame
	var still := 0
	if is_instance_valid(boss):
		for c in (boss.get("_crowd") as Array):
			if is_instance_valid(c) and (c as Sprite2D).modulate.a > 0.5:
				still += 1
	_check(still <= 12, "толпа разбегается, остаются единицы: %d" % still)

	# А НОСИЛЬЩИКИ ОСТАЮТСЯ ПОД НИМ. Здесь была тихая поломка: качание в толпе —
	# вечный твин по абсолютной координате, и он никем не выключался. Носильщики
	# подбегали под тело, а качание тут же тянуло их обратно в кольцо — король
	# уезжал один, а между ним и «носильщиками» зияла пустота через пол-экрана.
	if is_instance_valid(boss) and is_instance_valid(fallen):
		var near := 0
		for c in (boss.get("_crowd") as Array):
			if not is_instance_valid(c):
				continue
			var s : Sprite2D = c
			if s.modulate.a > 0.5 \
					and s.position.distance_to(fallen.position) < float(boss.BOSS_PX):
				near += 1
		_check(near >= 2,
			"а носильщики держатся ПРИ ТЕЛЕ, а не уезжают в кольцо: рядом %d"
				% near)

	var gone := await _await_free(boss, 14.0)
	_check(gone, "босс добит и убрался за %.1f c" % 14.0)
	_check(not bool(n.get("spells_blocked")), "спелл разблокирован обратно")

	_finish()

# Кулаки в кадре: спрайты на слое кулаков.
func _fists_of(boss: Node) -> Array:
	var out : Array = []
	for c in boss.get_children():
		if c is Sprite2D and (c as Sprite2D).z_index >= int(boss.FIST_Z) \
				and (c as Sprite2D).z_index <= int(boss.FIST_Z_TOP):
			out.append(c)
	return out

# Ширина РИСУНКА кулака на экране — по ней и сравниваются руки. По кадру
# сравнивать нельзя: он у этих двух текстур разный, и именно это и было ошибкой.
func _fist_px(f: Sprite2D) -> float:
	return float(ItemSizing.content_rect(f.texture).size.x) * absf(f.scale.x)

# Пицца в финале: спрайт с текстурой пиццы, лежащий поверх всех.
func _pizza_of(boss: Node) -> Sprite2D:
	for c in boss.get_children():
		if c is Sprite2D and (c as Sprite2D).z_index == int(boss.PIZZA_Z):
			return c
	return null

func _tap(boss: Node, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed  = true
	ev.position = at
	boss.call("_input", ev)

func _in_ellipse(p: Vector2, c: Vector2, r: Vector2) -> bool:
	var d := p - c
	return (d.x * d.x) / maxf(1.0, r.x * r.x) + (d.y * d.y) / maxf(1.0, r.y * r.y) <= 1.0

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
		if not is_instance_valid(boss) or not boss.is_inside_tree():
			return true
		await process_frame
	return false

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
