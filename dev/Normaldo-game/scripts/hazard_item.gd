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
}
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
	"helm":     { "px": 60.0, "dmg": 1, "speed_mult": 1.2,  "move": "spin" },
	# Шаман — не бьёт больно, а ПРОКЛИНАЕТ: разворачивает управление на 3 с.
	"shaman":   { "px": 68.0, "dmg": 1, "speed_mult": 0.95, "move": "straight", "invert": 3.0 },
}

const WAVE_AMP    : float = 46.0
const WAVE_SPEED  : float = 3.2
const COP_CALL_PERIOD : float = 2.6   # как часто коп роняет наручники
const HANDCUFF_DROP_SPEED_MULT : float = 1.25

@export var speed : float = 250.0
@export var kind  : String = "safe"

var damage : int = 1

var _cfg     : Dictionary = {}
var _sprite  : Sprite2D   = null
var _base_y  : float      = 0.0
var _wave_t  : float      = 0.0
var _spin    : float      = 0.0
var _cop_t   : float      = 0.0
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
	ItemSizing.fit_sprite(_sprite, float(_cfg.get("px", 56.0)))
	add_child(_sprite)

	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	c.radius = float(_cfg.get("px", 56.0)) * 0.42
	cs.shape = c
	add_child(cs)

	if String(_cfg.get("move", "straight")) == "spin":
		_spin = 5.0

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

# Коп поднимает руку и роняет наручники — те падают вниз и убивают при касании.
# Именно это делает копа опасным: сам он бьёт всего на 1.
func _tick_cop(delta: float) -> void:
	_cop_t += delta
	if _cop_t < COP_CALL_PERIOD:
		return
	_cop_t = 0.0
	if position.x > get_viewport_rect().size.x or position.x < 40.0:
		return   # за экраном подмогу не зовём
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
	p.add_child(hc)
	var a := AudioStreamPlayer.new()
	a.stream = CAST_SFX
	a.volume_db = -8.0
	p.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

# Сбит гигантской головой ЖИРОБОССА — падает вниз, как обычный предмет.
func knock_down() -> void:
	if _falling:
		return
	_falling = true
	collision_layer = 0
	_fall_vel = Vector2(-speed * 0.12, randf_range(-60.0, -10.0))
