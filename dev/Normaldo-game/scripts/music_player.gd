extends AudioStreamPlayer

const FADE_IN_TIME  := 2.0
const FADE_OUT_TIME := 1.5
const TARGET_VOLUME := -10.0

func _ready() -> void:
	bus = "Music"
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	volume_db = -80.0

func start() -> void:
	play()
	var tween := create_tween()
	tween.tween_property(self, "volume_db", TARGET_VOLUME, FADE_IN_TIME)

func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "volume_db", -80.0, FADE_OUT_TIME)
	await tween.finished
	stop()

# True crossfade to a different track (used by the ЖИРОБОСС mini-game to swap in
# hard_track and back). The OUTgoing track keeps playing on a throw-away player
# and fades out, while THIS player switches to the new stream and fades in at the
# same time — overlapping, so there's never a silent gap.
func swap_to(new_stream: AudioStream, fade: float = 1.2, from_pos: float = 0.0) -> void:
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
	var tw_i := create_tween()
	tw_i.tween_property(self, "volume_db", TARGET_VOLUME, fade)
