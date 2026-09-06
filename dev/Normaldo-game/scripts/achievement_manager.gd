extends Node

# ── Счётчики достижений ───────────────────────────────────────────────────────
# Таблица достижений лежит в `achievements.gd` и генерится из спеки. Здесь —
# ВТОРАЯ половина: числа, из которых достижения получаются, и точки, куда игра
# об этих числах сообщает.
#
# ── Почему счётчики, а не «условия» ───────────────────────────────────────────
# Достижение описано парой `stat` + `goal`. Условие пришлось бы вычислять по
# состоянию игры, а счётчик просто лежит, и из него бесплатно получается
# ПРОЦЕНТ: `min(counter / goal, 1)`. Процент нужен полоске на экране, и он же
# нужен Game Center — тот принимает `percentComplete`, а не «да/нет». Без
# процента игрок видит только момент открытия, но не путь к нему.
#
# Счётчиков заметно меньше, чем достижений: шесть достижений про пиццу держатся
# на двух — «съедено всего» и «лучший забег».
#
# ── Три примитива и ни одного больше ──────────────────────────────────────────
# `bump` (прибавить), `set_max` (рекорд) и `mark` (разовое) — это одна и та же
# операция над числом с разным способом слияния. Всё остальное в этом файле —
# крючки `on_*`, которые из событий игры делают вызовы этих трёх. Крючки живут
# ЗДЕСЬ, а не по игре: иначе логика «убер за первые 60 секунд» размазалась бы
# по `hud.gd`, и в точке вызова стояла бы не одна строка, а пять.
#
# ── Индекс, а не перебор ──────────────────────────────────────────────────────
# `_index` — это `stat → [id, …]`, собранный один раз при старте. Поэтому
# съеденная пицца проверяет ЧЕТЫРЕ достижения, а не семьдесят восемь. При
# семидесяти восьми строках и десятках событий в секунду перебор всего списка
# на каждое событие — это то, что потом ищут профайлером.
#
# ── Свой файл, а не общий сейв ────────────────────────────────────────────────
# Спека предлагала положить оба словаря в `SaveData`. На деле это не годится:
# `SaveData._save()` переписывает ВЕСЬ файл, а `bump` зовётся на каждую пиццу —
# десятки раз в секунду. Поэтому счётчики живут отдельным файлом, как у
# `QuestManager`, и пишутся не на каждое изменение, а по `flush()`: конец
# забега, открытие экрана, сворачивание приложения.
#
# См. /Концепция/Достижения.md, scripts/achievements.gd

# Плашку показывают ПОСЛЕ забега, а не в момент открытия: посреди уворота это
# отнятое внимание в тот момент, когда его отнимать нельзя.
signal unlocked(a: Dictionary)   # достижение открыто (после забега)
signal changed                   # счётчики поменялись — экрану перерисоваться

const SAVE_PATH : String = "user://achievements.json"

# Убер — это `fat_state == 3` (SKINNY 0, SLIM 1, ЖИР 2, УБЕР 3), см. normaldo.gd.
const FAT_UBER      : int = 3
const UBER_FAST_SEC : float = 60.0
const NINJA_FAST_SEC: float = 40.0
const NIGHT_FROM_H  : int = 3
const NIGHT_TO_H    : int = 5

var stats : Dictionary = {}   # stat → int, только растёт
var done  : Dictionary = {}   # id → unix-время открытия

# Эпизоды, пройденные без урона, — множеством, а не счётчиком. «Все три эпизода
# без урона» это ТРИ РАЗНЫХ эпизода, а не первый эпизод трижды; счётчик засчитал
# бы второе, и достижение бралось бы повторением самого лёгкого.
var nodmg_eps : Dictionary = {}   # номер эпизода → true

# Зеркало на платформе. Игра считает и показывает САМА, сюда уходит копия —
# см. ach_backend.gd. Отвалилось зеркало (не iOS, не залогинен, экспорт собран
# без плагина) — на экране в игре не меняется ничего.
var backend : AchBackend = AchBackend.new()

var _index    : Dictionary = {}   # stat → Array[Dictionary] строки достижений
var _mirrored : Dictionary = {}   # id → процент, уже ушедший в зеркало
var _dirty : bool = false

# ─── Состояние забега ─────────────────────────────────────────────────────────
# Живёт здесь, чтобы в точках вызова стояло по одной строке.
var _run_active   : bool  = false
var _run_episode  : int   = 0
var _run_secs     : float = 0.0
var _run_damage   : bool  = false
var _run_fat_max  : int   = 0
var _run_pizzas   : int   = 0
var _run_dollars  : int   = 0
var _run_spells   : int   = 0
var _run_reflex   : int   = 0
var _boss_damage  : bool  = false   # получен ли урон в текущем бою с боссом
var _curse_until  : float = -1.0    # до какой секунды забега висит проклятие
# Идёт ли раздача задним числом. На ней плашки не показываются — см. `_check`.
var _catching_up  : bool  = false
var _pending      : Array = []      # открытые за забег — под плашку

func _ready() -> void:
	_build_index()
	_load()
	_catch_up()
	# Проценты за прошлые запуски. Зеркало могло не сойтись: игрок мог играть
	# без сети, переустановить игру или впервые войти в Game Center только
	# сейчас. Проекция идемпотентна — меньший процент Game Center игнорирует, —
	# поэтому отправлять всё разом безопасно и это дешевле, чем помнить, что
	# уже отправлено.
	if backend.available():
		_mirror_all()
		backend.flush()

# Отправить в зеркало ТЕКУЩЕЕ состояние целиком.
func _mirror_all() -> void:
	_mirrored.clear()
	for a in Achievements.registerable():
		if progress(a) > 0.0:
			_mirror(a)

# ─── Индекс ───────────────────────────────────────────────────────────────────
# Кладём САМИ СТРОКИ, а не их id. С id пришлось бы на каждое изменение счётчика
# звать `Achievements.by_id`, а он — линейный перебор семидесяти восьми. Съеденная
# пицца трогает четыре достижения, то есть это было бы четыре перебора на пиццу,
# десятки раз в секунду — ровно то, ради чего индекс и заводился.
func _build_index() -> void:
	_index.clear()
	for a in Achievements.ALL:
		var s := String(a["stat"])
		if not _index.has(s):
			_index[s] = []
		(_index[s] as Array).append(a)

# ─── Три примитива ────────────────────────────────────────────────────────────
func bump(stat: String, n: int = 1) -> void:
	if n <= 0:
		return
	_put(stat, int(stats.get(stat, 0)) + n)

func set_max(stat: String, v: int) -> void:
	if v > int(stats.get(stat, 0)):
		_put(stat, v)

func mark(stat: String) -> void:
	set_max(stat, 1)

# Единственное место, где счётчик меняется. Проверяет только тех, кто на этом
# счётчике висит, — за этим и заведён индекс.
#
# Название не `_set`: так зовётся виртуальный метод Object, и переопределение
# его своей сигнатурой роняет весь скрипт на компиляции.
func _put(stat: String, v: int) -> void:
	if int(stats.get(stat, 0)) == v:
		return
	stats[stat] = v
	_dirty = true
	for a in _index.get(stat, []):
		_check(a)
		_mirror(a)
	changed.emit()

func _check(a: Dictionary) -> void:
	var aid := String(a["id"])
	if done.has(aid):
		return
	if int(stats.get(String(a["stat"]), 0)) < int(a["goal"]):
		return
	done[aid] = int(Time.get_unix_time_from_system())
	_dirty = true
	if _catching_up:
		# ЗАДНИМ ЧИСЛОМ — БЕЗ ПЛАШЕК. Игрок, у которого уже 40 000 пицц, при
		# первом запуске получит десяток достижений разом, и десяток плашек
		# подряд — это не праздник, а очередь, которую надо переждать.
		#
		# Молчать здесь надо ЯВНО. Само по себе оно и так молчало бы: раздача
		# идёт в `_ready` автозагрузки, то есть раньше, чем интерфейс успевает
		# подписаться на сигнал, — но это совпадение порядка загрузки, а не
		# решение, и держаться на нём нельзя.
		return
	_pending.append(a)
	Analytics.event("achievement_unlocked", {
		"id":     aid,
		"tier":   str(int(a["tier"])),
		"points": str(Achievements.points(a)),
	})
	# В забеге плашку не показываем — она уйдёт по `flush_pending()`.
	if not _run_active:
		flush_pending()

# Процент одного достижения — в очередь зеркала. Именно ПРОЦЕНТ, а не факт
# открытия: зарезервированное (`campaign`) в App Store Connect не заведено, и
# отправлять его некуда.
#
# Помним, что уже отправлено. Иначе каждая съеденная пицца заново слала бы
# «проглот — 100 %»: счётчик `pizzas_total` общий на четыре достижения, и три
# из них давно взяты. Game Center такой процент проигнорирует, но запрос всё
# равно уйдёт — а он сетевой.
func _mirror(a: Dictionary) -> void:
	if bool(a.get("reserved", false)):
		return
	var aid := String(a["id"])
	var pct := progress(a) * 100.0
	if pct <= float(_mirrored.get(aid, -1.0)):
		return
	_mirrored[aid] = pct
	backend.submit(aid, pct)

# Показать накопленные плашки. Зовётся экраном смерти / победы.
func flush_pending() -> void:
	if _pending.is_empty():
		return
	var out := _pending.duplicate()
	_pending.clear()
	for a in out:
		unlocked.emit(a)

func pending() -> Array:
	return _pending.duplicate()

# ─── Чтение ───────────────────────────────────────────────────────────────────
func value(stat: String) -> int:
	return int(stats.get(stat, 0))

func counter(a: Dictionary) -> int:
	return mini(value(String(a["stat"])), int(a["goal"]))

func is_done(a: Dictionary) -> bool:
	return done.has(String(a["id"]))

func progress(a: Dictionary) -> float:
	var goal := int(a["goal"])
	if goal <= 0:
		return 1.0
	return clampf(float(value(String(a["stat"]))) / float(goal), 0.0, 1.0)

func category_done(key: String) -> int:
	var n := 0
	for a in Achievements.in_category(key):
		if is_done(a):
			n += 1
	return n

func summary() -> Dictionary:
	var got := 0
	var pts := 0
	for a in Achievements.ALL:
		if is_done(a):
			got += 1
			pts += Achievements.points(a)
	return {
		"done":   got,
		"total":  Achievements.ALL.size(),
		"points": pts,
		"points_all": Achievements.total_points(),
	}

# ─── Раздача задним числом ────────────────────────────────────────────────────
# Зовётся на КАЖДОМ старте, а не «однажды по флажку». Все операции здесь —
# `set_max`, то есть повторный вызов ничего не меняет; зато сейв, переживший
# обновление игры или пришедший с сервера, подтягивается сам, без миграции.
#
# Игрок с 40 000 пицц обязан получить бронзу и серебро сразу, а золото — нет.
func _catch_up() -> void:
	_catching_up = true
	_do_catch_up()
	_catching_up = false

func _do_catch_up() -> void:
	set_max("pizzas_total",    SaveData.total_pizzas)
	set_max("pizzas_run_best", SaveData.best_run())
	set_max("runs_total",      SaveData.total_runs())
	set_max("codex_seen",      SaveData.seen_entries.size())
	set_max("episodes_done",   SaveData.episodes_done)
	if SaveData.episodes_done >= QuestManager.CAMPAIGN_EPISODES:
		mark("campaign_done")

	# Скины: куплено, максимальный уровень, сколько доведено до десятого.
	var owned : int = SaveData.owned_skins.size()
	set_max("skins_owned",  owned)
	# «Классик» дан бесплатно — купленных на один меньше.
	set_max("skins_bought", maxi(0, owned - 1))
	var lvl_max := 0
	var at_ten  := 0
	var played_all := owned > 0
	for id in SaveData.owned_skins:
		var lvl := SaveData.get_skin_level_for(String(id))
		lvl_max = maxi(lvl_max, lvl)
		if lvl >= 10:
			at_ten += 1
		if SaveData.get_skin_runs_for(String(id)) <= 0:
			played_all = false
	set_max("skin_lvl_max", lvl_max)
	set_max("skins_at_10",  at_ten)
	if played_all:
		mark("all_skins_played")

	# Рекорды режимов и место в таблице — их уже ведут другие.
	set_max("endless_best", int(QuestManager.endless_best_secs))
	for mode in SaveData.mode_rank:
		_rank_stat(int(SaveData.mode_rank[mode]))

	set_max("nodmg_episodes", nodmg_eps.size())

# ─── Крючки: забег ────────────────────────────────────────────────────────────
func on_run_started(_is_campaign: bool, is_endless: bool, episode: int = 0) -> void:
	_run_active   = true
	_run_episode  = episode
	_run_secs     = 0.0
	_run_damage   = false
	_run_fat_max  = 0
	_run_pizzas   = 0
	_run_dollars  = 0
	_run_spells   = 0
	_run_reflex   = 0
	_boss_damage  = false
	_curse_until  = -1.0
	bump("runs_total")
	if is_endless:
		bump("endless_runs")
	var h := Time.get_datetime_dict_from_system()["hour"] as int
	if h >= NIGHT_FROM_H and h < NIGHT_TO_H:
		mark("night_run")
	# Скин, которым играют, зачтётся как «сыгранный» только по концу забега —
	# `SaveData.note_run_finished` пишет `runs` именно там.

func on_run_time(secs: float) -> void:
	_run_secs = secs
	_tick_curse()

func on_run_finished() -> void:
	_run_active = false
	if _run_fat_max >= FAT_UBER:
		bump("uber_runs")
	# «Примерочная»: каждым КУПЛЕННЫМ скином сыгран хоть один забег. Считается
	# по сейву, а не по своему списку: забеги уже пишет `SaveData`, вторая копия
	# того же числа разошлась бы с первой.
	var played_all := SaveData.owned_skins.size() > 0
	for id in SaveData.owned_skins:
		if SaveData.get_skin_runs_for(String(id)) <= 0:
			played_all = false
			break
	if played_all:
		mark("all_skins_played")
	flush()
	flush_pending()
	# Пачкой и ВНЕ ЗАБЕГА: каждая отправка — сетевой запрос, и делать их по
	# одному посреди уворота значит тратить кадры на то, чего игрок не увидит.
	backend.flush()

func on_stats_changed(fat_state: int, run_pizzas: int) -> void:
	var delta := maxi(0, run_pizzas - _run_pizzas)
	_run_pizzas = run_pizzas
	bump("pizzas_total", delta)
	set_max("pizzas_run_best", run_pizzas)
	if fat_state > _run_fat_max:
		_run_fat_max = fat_state
		set_max("fat_max", fat_state)
		if fat_state >= FAT_UBER and _run_secs <= UBER_FAST_SEC:
			mark("uber_fast")

func on_dollars_changed(run_dollars: int) -> void:
	var delta := maxi(0, run_dollars - _run_dollars)
	_run_dollars = run_dollars
	bump("money_total", delta)
	set_max("money_run_best", run_dollars)

func on_damage_taken() -> void:
	_run_damage  = true
	_boss_damage = true
	_curse_until = -1.0   # проклятие пережить не удалось

# Сколько секунд подряд игрок держится без урона. Считает `hud`, здесь только
# рекорд — своего секундомера заводить незачем.
func on_clean_time(secs: float) -> void:
	set_max("clean_best", int(secs))

# ─── Крючки: кампания и боссы ─────────────────────────────────────────────────
func on_episode_done(episode: int) -> void:
	if episode <= 0:
		return
	_run_episode = episode
	set_max("episodes_done", maxi(episode, SaveData.episodes_done))
	if not _run_damage:
		nodmg_eps[str(episode)] = true
		set_max("nodmg_episodes", nodmg_eps.size())
		_dirty = true
	if _run_fat_max <= 0:
		mark("skinny_episode")
	if _run_spells <= 0:
		mark("no_spell_episode")

func on_campaign_complete() -> void:
	mark("campaign_done")

func on_boss_reached() -> void:
	mark("boss_reached")

# Начался сам бой. Отдельно от «дошёл до босса»: между ними титр и выход босса,
# а урон, полученный ДО первого удара босса, к бою отношения не имеет.
func on_boss_fight_started() -> void:
	_boss_damage = false

# `secs` — длительность самого боя, не забега.
func on_boss_beaten(boss_id: String, secs: float = -1.0) -> void:
	bump("bosses_beaten")
	if not _boss_damage and boss_id != "":
		mark("boss_nodmg:" + boss_id)
	if boss_id == "ninja" and secs >= 0.0 and secs < NINJA_FAST_SEC:
		mark("ninja_fast")

# ─── Крючки: бесконечный ──────────────────────────────────────────────────────
func on_endless_time(secs: float) -> void:
	set_max("endless_best", int(secs))

func on_hardcore() -> void:
	mark("hardcore_reached")

func on_hardcore_time(secs: float) -> void:
	set_max("hardcore_best", int(secs))

# ─── Крючки: предметы, спеллы, резисты, перки ─────────────────────────────────
# `_count_tag` в normaldo.gd — единственное место, где предмет называет себя по
# имени, и имён там два с половиной десятка. Один вызов оттуда даёт счётчики по
# ВСЕМ предметам разом: и под сегодняшние три достижения (мешки, мэджик боксы,
# зазывалы), и под все будущие.
func on_item(tag: String) -> void:
	if tag == "":
		return
	bump("item:" + tag)

func on_death(tag: String) -> void:
	if tag == "":
		return
	mark("death_by:" + tag)

func on_spell_cast(_skin_id: String = "") -> void:
	_run_spells += 1
	bump("spell_casts")

func on_spell_hit(skin_id: String, n: int = 1) -> void:
	if skin_id == "":
		return
	bump("spell_hits:" + skin_id, n)

func on_resist(tag: String = "") -> void:
	bump("resists")
	if tag == "safe":
		mark("safe_resist")

func on_reflex() -> void:
	_run_reflex += 1
	set_max("reflex_run_best", _run_reflex)

func on_time_stop() -> void:
	bump("time_stops")

# ── Проклятие шамана ─────────────────────────────────────────────────────────
# «Переживи, не потеряв жизнь» — это ОКНО, а не событие: начинается с удара
# шамана и закрывается через его же реверс управления. Окно ведётся здесь, а не
# в `normaldo.gd`, потому что оно и есть достижение: в игре от него ничего не
# зависит, и заводить там второе состояние ради счётчика незачем.
func on_curse_started(dur: float) -> void:
	_curse_until = _run_secs + dur

func _tick_curse() -> void:
	if _curse_until < 0.0 or _run_secs < _curse_until:
		return
	_curse_until = -1.0
	mark("curse_survived")

# ─── Крючки: экраны ───────────────────────────────────────────────────────────
func on_minigame(kind: String) -> void:
	if kind == "":
		return
	bump("minigame:" + kind)

func on_slot_spin(match_count: int, jackpot: bool = false) -> void:
	bump("slot_spins")
	set_max("slot_best_match", match_count)
	if jackpot:
		mark("slot_jackpot")
	flush()

func on_skin_bought() -> void:
	bump("skins_bought")
	set_max("skins_owned", SaveData.owned_skins.size())
	flush()

func on_skin_level(level: int) -> void:
	set_max("skin_lvl_max", level)
	var at_ten := 0
	for id in SaveData.owned_skins:
		if SaveData.get_skin_level_for(String(id)) >= 10:
			at_ten += 1
	set_max("skins_at_10", at_ten)

func on_codex_seen(count: int) -> void:
	set_max("codex_seen", count)

func on_menu_remote() -> void:
	bump("tv_remote")
	flush()

# ─── Крючки: сервер ───────────────────────────────────────────────────────────
# Место в таблице приходит с сервера в ответе `submitScore`. Считать в игре
# нечего, но и хранить «место» напрямую нельзя: место ЛУЧШЕ, когда число
# МЕНЬШЕ, а счётчики у нас только растут. Поэтому хранится перевёрнутое:
# 101 − место. Топ-100 → 1, топ-10 → 91, первое место → 100.
const RANK_BASE : int = 101

func _rank_stat(rank: int) -> void:
	if rank <= 0 or rank > 100:
		return
	set_max("best_rank_inv", RANK_BASE - rank)

func on_rank(rank: int, _mode: String = "") -> void:
	_rank_stat(rank)
	# «Во всех четырёх» — сколько режимов недели, где место вообще есть.
	var n := 0
	for mode in SaveData.mode_rank:
		if int(SaveData.mode_rank[mode]) > 0:
			n += 1
	set_max("modes_ranked_week", n)
	flush()

# ─── Сохранение ───────────────────────────────────────────────────────────────
func flush() -> void:
	if not _dirty:
		return
	_save()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify({
		"stats":     stats,
		"done":      done,
		"nodmg_eps": nodmg_eps,
	}))
	_dirty = false

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var d = json.get_data()
	if not d is Dictionary:
		return
	for k in (d.get("stats", {}) as Dictionary):
		stats[str(k)] = int((d["stats"] as Dictionary)[k])
	for k in (d.get("done", {}) as Dictionary):
		done[str(k)] = int((d["done"] as Dictionary)[k])
	for k in (d.get("nodmg_eps", {}) as Dictionary):
		nodmg_eps[str(k)] = true

# ─── Дев ──────────────────────────────────────────────────────────────────────
func dev_reset() -> void:
	stats.clear()
	done.clear()
	nodmg_eps.clear()
	_pending.clear()
	_mirrored.clear()
	_dirty = true
	_catch_up()
	_save()
	changed.emit()

# Открыть всё — чтобы посмотреть экран целиком, не наигрывая семьдесят восемь
# условий.
func dev_unlock_all() -> void:
	for a in Achievements.ALL:
		set_max(String(a["stat"]), int(a["goal"]))
	_save()
	changed.emit()
