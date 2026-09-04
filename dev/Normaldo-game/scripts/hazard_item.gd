extends Area2D

# ── Предметы под резисты скинов ───────────────────────────────────────────────
# Семь угроз, к которым лестница скинов выдаёт резисты, но которых в игре не
# существовало: сейф, коктейль, коп, яд, птица, штурвал, шаман. Пока их не было,
# семь наград 4–10 уровней были пустыми обещаниями.
#
# Один скрипт на всех — как у effect_item.gd. Различаются они спрайтом, уроном,
# СПОСОБОМ ПОЛЁТА и побочным эффектом, и всё это лежит в KINDS таблицей: заводить
# семь почти одинаковых файлов ради трёх отличающихся строк смысла нет.
#
# Способы полёта (`move`):
#   "straight" — как обычный предмет
#   "wave"     — синусоида по вертикали (птица)
#   "spin"     — прямо, но спрайт крутится (штурвал)
#
# Побочные эффекты навешиваются метаданными и разбираются в normaldo.gd:
#   slow_duration   — замедление после удара
#   invert_duration — реверс управления (шаман)
#
# См. /Концепция/Уровни/1-Канализация.md

const TEX : Dictionary = {
	"safe":     preload("res://assets/items/safe.png"),
	"cocktail": preload("res://assets/items/cocktail.png"),
	"cop":      preload("res://assets/items/cop.png"),
	"poison":   preload("res://assets/items/poison.png"),
	"bird":     preload("res://assets/items/bird.png"),
	"helm":     preload("res://assets/skills/ship_wheel.png"),
	"shaman":   preload("res://assets/items/shaman.png"),
	# Предметы локаций (раскладка по уровням, см. spawner.HAZ_LEVEL). Они попали
	# сюда, а не в свои файлы, ровно по той же причине, что и первые семь:
	# отличаются они спрайтом, уроном и способом полёта, а всё это уже описано
	# таблицей.
	"umbrella": preload("res://assets/items/umbrella.png"),
	"bottle":   preload("res://assets/items/letter_bottle.png"),
	"tire":     preload("res://assets/items/tire.png"),
	"lounger":  preload("res://assets/items/lounger.png"),
	"campfire": preload("res://assets/items/firewood.png"),
}
# Огонь костра — ТЕ ЖЕ кадры, что горят после молотова (`fire.gd`). Отдельного
# рисунка «горящие дрова» не нужно: дрова лежат, огонь пляшет поверх них, — а
# горящий костёр и горящая лужа обязаны выглядеть одним огнём, иначе игрок
# читает их как две разные угрозы.
const FIRE_DIR : String = "res://assets/items/fire2/animations/The_flames_flicker_and_dance_rhythmically_with_th/unknown/"
const FIRE_FRAME_COUNT : int = 5
const FIRE_FPS : float = 10.0
const COP_CALLING := preload("res://assets/items/cop_calling.png")
const EFFECT_ITEM := preload("res://scripts/effect_item.gd")

const HIT_SFX  := preload("res://assets/audio/hit.mp3")
const CAST_SFX := preload("res://assets/audio/magic_poof.mp3")

# px — экранный размер; speed_mult — доля от скорости потока.
const KINDS : Dictionary = {
	# Сейф — самый тяжёлый предмет в игре: медленный, крупный, 2 урона.
	# Медленный намеренно: его видно издалека, но объехать мешает размер.
	"safe":     { "px": 78.0, "dmg": 2, "speed_mult": 0.78, "move": "straight" },
	# Коктейль — замедляющий, урона не наносит (как банан и пиво).
	"cocktail": { "px": 50.0, "dmg": 0, "speed_mult": 1.0,  "move": "straight", "slow": 4.0 },
	# Коп — бьёт на 1 и ВЫЗЫВАЕТ ПОДМОГУ: раз в COP_CALL_PERIOD роняет наручники.
	# Из-за этого он опаснее своего урона, и резист к нему у Бэтмена с Джокером
	# стоит дорого — на 8-м уровне.
	"cop":      { "px": 66.0, "dmg": 1, "speed_mult": 0.92, "move": "straight" },
	# Яд — бьёт и травит: урон плюс замедление.
	"poison":   { "px": 52.0, "dmg": 1, "speed_mult": 1.0,  "move": "straight", "slow": 3.0 },
	# Птица — единственная угроза, летящая по синусоиде: её нельзя объехать по
	# прямой, надо читать фазу.
	"bird":     { "px": 54.0, "dmg": 1, "speed_mult": 1.35, "move": "wave" },
	# Штурвал — оружие Пирата, обёрнутое против игрока: крутится и летит быстро.
	"helm":     { "px": 66.0, "dmg": 1, "speed_mult": 1.2,  "move": "spin" },
	# Шаман — не бьёт больно, а ПРОКЛИНАЕТ: разворачивает управление на 3 с.
	"shaman":   { "px": 68.0, "dmg": 1, "speed_mult": 0.95, "move": "straight", "invert": 3.0 },

	# ── Предметы локаций ─────────────────────────────────────────────────────
	# Зонт — крупный и парусит: летит медленнее потока и покачивается.
	"umbrella": { "px": 86.0, "dmg": 1, "speed_mult": 0.86, "move": "spin", "spin": 1.4 },
	# Бутылка с письмом — не бьёт, а замедляет: разлилось под ноги.
	"bottle":   { "px": 56.0, "dmg": 0, "speed_mult": 1.05, "move": "spin", "spin": 2.6,
	              "slow": 4.0 },
	# Колесо КАТИТСЯ: быстрее потока и крутится в свою сторону.
	"tire":     { "px": 76.0, "dmg": 1, "speed_mult": 1.25, "move": "spin", "spin": 6.0 },
	# Шезлонг — самый длинный предмет уровня: занимает две линии по горизонтали,
	# объехать можно только сверху или снизу.
	"lounger":  { "px": 150.0, "dmg": 1, "speed_mult": 0.82, "move": "straight" },
	# Костёр — дрова плюс живой огонь поверх. Бьёт как огонь, а не как полено.
	"campfire": { "px": 92.0, "dmg": 1, "speed_mult": 0.9,  "move": "straight" },
}

const WAVE_AMP    : float = 46.0
const WAVE_SPEED  : float = 3.2
const COP_CALL_PERIOD : float = 1.1   # через сколько после появления он бросает
const HANDCUFF_DROP_SPEED_MULT : float = 1.25
# Добавка к скорости броска: наручники обязаны ДОГНАТЬ, а не плыть рядом с
# потоком, иначе бросок читается как «коп что-то обронил».
const THROW_EXTRA : float = 90.0

@export var speed : float = 250.0
@export var kind  : String = "safe"

var damage : int = 1

var _cfg     : Dictionary = {}
var _sprite  : Sprite2D   = null
var _base_y  : float      = 0.0
var _wave_t  : float      = 0.0
var _spin    : float      = 0.0
var _cop_t   : float      = 0.0
var _cop_thrown : bool    = false
var _falling : bool       = false
var _fall_vel: Vector2    = Vector2.ZERO

func _ready() -> void:
	_cfg    = KINDS.get(kind, KINDS["safe"])
	damage  = int(_cfg.get("dmg", 1))
	speed  *= float(_cfg.get("speed_mult", 1.0))
	_base_y = position.y

	collision_layer = 2
	collision_mask  = 0
	add_to_group(kind)
	# Коктейль — замедляющий, остальные ударяющие. Группа решает, в какую ветку
	# столкновения он попадёт в normaldo.gd.
	add_to_group("slowing" if kind == "cocktail" else "obstacle")

	if float(_cfg.get("slow", 0.0)) > 0.0:
		set_meta("slow_duration", float(_cfg["slow"]))
		set_meta("slow_sound", HIT_SFX)
	if float(_cfg.get("invert", 0.0)) > 0.0:
		set_meta("invert_duration", float(_cfg["invert"]))

	_sprite = Sprite2D.new()
	_sprite.texture = TEX.get(kind, TEX["safe"])
	ItemSizing.fit_sprite_content(_sprite, float(_cfg.get("px", 56.0)))
	add_child(_sprite)

	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	c.radius = float(_cfg.get("px", 56.0)) * 0.42
	cs.shape = c
	add_child(cs)

	if String(_cfg.get("move", "straight")) == "spin":
		_spin = float(_cfg.get("spin", 5.0))
	if kind == "campfire":
		_add_fire()

func _process(delta: float) -> void:
	if _falling:
		_fall_vel.y += 900.0 * delta
		position    += _fall_vel * delta
		_sprite.rotation += 3.0 * delta
		if position.y > get_viewport_rect().size.y + 200.0:
			queue_free()
		return

	position.x -= speed * delta
	if position.x < -220.0:
		queue_free()
		return

	match String(_cfg.get("move", "straight")):
		"wave":
			_wave_t += delta * WAVE_SPEED
			position.y = _base_y + sin(_wave_t) * WAVE_AMP
			# Наклон по направлению движения — иначе птица «плывёт боком».
			_sprite.rotation = cos(_wave_t) * 0.28
		"spin":
			_sprite.rotation += _spin * delta

	if kind == "cop":
		_tick_cop(delta)

# Огонь поверх дров. Кадры те же, что горят после молотова, — и это не экономия
# на рисунке: горящий костёр и горящая лужа обязаны выглядеть одним и тем же
# огнём, иначе игрок читает их как две разные угрозы.
# Кадры огня одинаковы у всех костров — строим SpriteFrames один раз на всю
# игру, как это делает `fire.gd`: иначе каждый костёр грузит пять картинок и
# плодит свой ресурс.
static var _fire_frames : SpriteFrames

func _add_fire() -> void:
	if _fire_frames == null:
		_fire_frames = SpriteFrames.new()
		_fire_frames.set_animation_loop("default", true)
		_fire_frames.set_animation_speed("default", FIRE_FPS)
		for i in FIRE_FRAME_COUNT:
			var t := load(FIRE_DIR + "frame_%03d.png" % i) as Texture2D
			if t != null:
				_fire_frames.add_frame("default", t)
	if _fire_frames.get_frame_count("default") == 0:
		return
	var f := AnimatedSprite2D.new()
	f.sprite_frames  = _fire_frames
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var px : float = float(_cfg.get("px", 92.0))
	f.scale    = Vector2.ONE * ItemSizing.content_scale(
		_fire_frames.get_frame_texture("default", 0), px * 0.86)
	# Огонь стоит НА дровах, а не в них: поленья лежат внизу кадра, пламя выше.
	f.position = Vector2(0.0, -px * 0.30)
	f.z_index  = 1
	add_child(f)
	f.play("default")

# Коп поднимает руку и КИДАЕТ наручники — ОДИН раз за пролёт и В СТОРОНУ
# Нормальдо. Именно это делает копа опасным: сам он бьёт всего на 1.
#
# Раз, а не каждые 2.6 секунды: коп, сыплющий наручниками весь пролёт, — это не
# угроза, а генератор, от которого уходят один раз и навсегда. Одна заявка на
# пролёт читается как поступок: он увидел, замахнулся, бросил.
#
# И бросок ЛЕТИТ ТУДА, КУДА БРОСИЛИ, а не следует за головой: направление
# берётся один раз, в момент замаха. Самонаводящийся бросок отменял бы уход с
# линии, то есть единственный ответ, который у игрока на него есть.
func _tick_cop(delta: float) -> void:
	if _cop_thrown:
		return
	_cop_t += delta
	if _cop_t < COP_CALL_PERIOD:
		return
	if position.x > get_viewport_rect().size.x or position.x < 40.0:
		return   # за экраном подмогу не зовём
	_cop_thrown = true
	_sprite.texture = COP_CALLING
	_drop_handcuffs()
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(_sprite):
			_sprite.texture = TEX["cop"])

func _drop_handcuffs() -> void:
	var p := get_parent()
	if p == null:
		return
	var hc := Area2D.new()
	hc.set_script(EFFECT_ITEM)
	hc.set("kind", "handcuffs")
	hc.set("speed", speed * HANDCUFF_DROP_SPEED_MULT)
	hc.position = position + Vector2(-10.0, 18.0)
	# Курс — на голову В МОМЕНТ БРОСКА и больше не меняется.
	var head := _find_normaldo()
	if head != null:
		var dir : Vector2 = (head.global_position - global_position).normalized()
		hc.set("vel", dir * (speed * HANDCUFF_DROP_SPEED_MULT + THROW_EXTRA))
	p.add_child(hc)
	var a := AudioStreamPlayer.new()
	a.stream = CAST_SFX
	a.volume_db = -8.0
	p.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

# Сбит гигантской головой ЖИРОБОССА — падает вниз, как обычный предмет.
func _find_normaldo() -> Node2D:
	var n := get_parent()
	while n != null:
		var nm := n.get_node_or_null("Normaldo")
		if nm != null:
			return nm as Node2D
		n = n.get_parent()
	return null

func knock_down() -> void:
	if _falling:
		return
	_falling = true
	collision_layer = 0
	_fall_vel = Vector2(-speed * 0.12, randf_range(-60.0, -10.0))
