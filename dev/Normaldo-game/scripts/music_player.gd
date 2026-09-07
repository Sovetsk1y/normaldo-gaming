extends AudioStreamPlayer

const FADE_IN_TIME  := 2.0
const FADE_OUT_TIME := 1.5
const TARGET_VOLUME := -10.0

# Текущее затухание/нарастание. Хранится, чтобы следующая команда его УБИЛА:
# затухание смерти длится полторы секунды и «стоп» в конце, а меню со своим
# треком приходит раньше — без этого чужой тюн доводил бы новую музыку до нуля
# и глушил её на полуслове.
var _fade : Tween = null
# Идёт ли сейчас затухание. Снаружи это не видно ничем: playing == true до
# самого конца, а громкость может быть любой и в нарастании тоже.
var _fading_out : bool = false

func is_fading_out() -> bool:
	return _fading_out

func _ready() -> void:
	bus = "Music"
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	volume_db = -80.0

# ── Замедление музыки ────────────────────────────────────────────────────────
# Пока идёт замедление времени, трек играет медленнее и ниже. Мир в этот момент
# обесцвечивается (`world_gray.gd`), и звук обязан ехать за картинкой: замерший
# на обычном темпе трек спорит с тем, что видно, и эффект читается как подвисание
# игры, а не как замедленное время.
#
# `pitch_scale`, а не смена трека: он тянет темп и высоту разом — ровно то, что
# слышно от замедленной записи. Отдельный «медленный» файл пришлось бы держать
# для каждого трека игры и синхронизировать позицию при переключении.
#
# Тюин, а не присваивание: мгновенный скачок высоты слышен как щелчок.
var _slow_tw : Tween = null

func set_slow_mo(on: bool, factor: float = 0.45) -> void:
	if _slow_tw != null and _slow_tw.is_valid():
		_slow_tw.kill()
	_slow_tw = create_tween()
	_slow_tw.tween_property(self, "pitch_scale", factor if on else 1.0, 0.18)

# Вернуть темп немедленно. Нужно на смене трека и на смерти: новый трек обязан
# начинаться в своём темпе, даже если замедление оборвалось вместе со сценой.
func reset_slow_mo() -> void:
	if _slow_tw != null and _slow_tw.is_valid():
		_slow_tw.kill()
	_slow_tw    = null
	pitch_scale = 1.0

func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	_fading_out = false

func start() -> void:
	_kill_fade()
	# Уже играющий трек не перезапускаем: start() зовут и «поднять обратно
	# после мини-игры», и «завести с нуля», и в первом случае прыжок на начало
	# записи слышен как обрыв.
	if not playing:
		play()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", TARGET_VOLUME, FADE_IN_TIME)

func fade_out() -> void:
	_kill_fade()
	var tween := create_tween()
	_fade = tween
	_fading_out = true
	tween.tween_property(self, "volume_db", -80.0, FADE_OUT_TIME)
	await tween.finished
	# Пока мы ждали, музыку могли завести заново (возврат в меню быстрее
	# полутора секунд) — тогда этот стоп уже не наш.
	if _fade == tween:
		_fade       = null
		_fading_out = false
		reset_slow_mo()
		stop()

# True crossfade to a different track (used by the ЖИРОБОСС mini-game to swap in
# hard_track and back). The OUTgoing track keeps playing on a throw-away player
# and fades out, while THIS player switches to the new stream and fades in at the
# same time — overlapping, so there's never a silent gap.
func swap_to(new_stream: AudioStream, fade: float = 1.2, from_pos: float = 0.0) -> void:
	_kill_fade()
	# Новый трек заводится в СВОЁМ темпе. Замедление могло оборваться вместе со
	# сценой (смерть, мини-игра, босс), и `set_slow_mo(false)` до сюда не дойти;
	# унаследованный `pitch_scale` звучал бы как испорченная запись.
	reset_slow_mo()
	if stream != null and playing:
		var old := AudioStreamPlayer.new()
		old.bus       = bus
		old.stream    = stream
		old.volume_db = volume_db
		add_child(old)
		old.play(get_playback_position())
		var tw_o := old.create_tween()
		tw_o.tween_property(old, "volume_db", -80.0, fade)
		tw_o.tween_callback(old.queue_free)

	stream = new_stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	volume_db = -80.0
	play(maxf(0.0, from_pos))
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", TARGET_VOLUME, fade)
