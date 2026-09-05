extends Control

# Top-left run-time cooldown badges for the active skin's skills.
#  • one circle per skill — each RESIST item gets its OWN circle (they cool down
#    in parallel), then the active ability, then the passive.
#  • on trigger the circle lights up and the glow recedes around the ring while
#    a seconds-left number sits in the centre (white, thin black outline).
#  • when the cooldown ends the badge blinks once and plays a ready sound
#    (sound asset added later — _READY_SFX is loaded if present).

const UI_FONT  := preload("res://assets/fonts/RussoOne-Regular.ttf")
const SMOKE_TEX := preload("res://assets/bosses/ninja_foot/smoke.png")
const CASEY_TEX := preload("res://assets/items/casey_mask.png")
const COMPASS_TEX := preload("res://assets/items/compass.png")
const HAT_TEX     := preload("res://assets/items/magic_hat.png")
const COLA_TEX    := preload("res://assets/items/cola.png")
# Венцы 10-го уровня. Часы — та же картинка, что у предмета «песочные часы», и
# это НЕ лень: перк мага делает ровно то же, что предмет, и разные картинки под
# одно действие заставляли бы игрока искать разницу, которой нет.
const HOURGLASS_TEX := preload("res://assets/items/hourglass.png")
const WEB_TEX       := preload("res://assets/skills/spider_man/web1.png")

# 34 было мало: кружок в углу экрана и так на периферии зрения.
const D    : float = 40.0
const PAD  : float = 10.0
const GAP  : float = 9.0

const RING_RESIST := Color(0.90, 0.20, 0.18)
const RING_ACTIVE := Color(0.35, 1.00, 0.45)
const RING_PASS   := Color(0.32, 0.58, 1.00)

var _active_badge : Control = null   # the active-ability circle, for deny pulses

# Картинка и имя резиста берутся у SkinProgression — там они одни на всю игру.
# Здесь была СВОЯ копия обеих таблиц, и она отстала от лестницы на пятнадцать
# предметов: кружки собаки, птицы, сейфа и ещё дюжины рисовались пустыми
# чёрными дисками, хотя на экране деталей скина те же резисты показывались
# правильно.

func setup(nrm: Node) -> void:
	for c in get_children():
		c.queue_free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sid : String = SaveData.active_skin
	var specs : Array = []

	# Resists — one badge per item (parallel cooldowns).
	for r in SkinSkills.get_resists(sid):
		var items : Array = r.get("items", [r.get("item", "")])
		var cd : int = int(r.get("cd", 8))
		for tag in items:
			if tag == "":
				continue
			var nm : String = SkinProgression.item_name(str(tag))
			var icon : Texture2D = SkinProgression.resist_icon(str(tag))
			# НЕТ КАРТИНКИ — НЕТ КРУЖКА. Пустой чёрный диск не сообщает ничего и
			# читается как поломка; отсутствие кружка честнее. Дойти сюда можно
			# только новым резистом без иконки — за этим следит smoke_skins.
			if icon == null:
				continue
			specs.append({ "key": "resist:" + str(tag), "tex": icon,
				"sym": "", "mod": Color(1, 1, 1), "ring": RING_RESIST,
				"title": "РЕЗИСТ · " + nm, "desc": "Ломает «" + nm + "» без урона. Откат " + str(cd) + " c." })

	# Active ability.
	var ab : Dictionary = SkinSkills.get_ability(sid)
	if not ab.is_empty():
		var a_title : String = "АКТИВКА · " + str(ab.get("label", ""))
		var a_desc  : String = str(ab.get("desc", ""))
		var a_charges : bool = int(ab.get("charges", 1)) > 1   # show a charge counter
		if ab.get("type", "") == SkinSkills.RYAGALITY:
			specs.append({ "key": "active", "tex": SMOKE_TEX, "sym": "",
				"mod": RING_ACTIVE, "ring": RING_ACTIVE, "title": a_title, "desc": a_desc, "chg": a_charges })
		elif String(ab.get("icon", "")) != "":
			# Спелл со своей иконкой рисуется ею, а не общей звёздочкой: «✦» у
			# всех одинаковый и о самом спелле не говорит ничего.
			specs.append({ "key": "active", "tex": load(String(ab.get("icon", ""))), "sym": "",
				"mod": Color(1, 1, 1), "ring": RING_ACTIVE, "title": a_title, "desc": a_desc, "chg": a_charges })
		else:
			specs.append({ "key": "active", "tex": null, "sym": "✦",
				"mod": Color(1, 1, 1), "ring": RING_ACTIVE, "title": a_title, "desc": a_desc, "chg": a_charges })

	# Пассивка. Раньше она висела статичным ★ весь забег: один и тот же кружок,
	# который ничего не сообщает, а ряд неподвижных кружков глаз перестаёт
	# замечать целиком. Постоянно включённая пассивка («аэродинамика»,
	# «ловкость») из ряда убрана — про неё игрок читает на карточке скина ДО
	# забега. В ряду остаются только пассивки со СРОКОМ: они появляются на время
	# действия и этим что-то сообщают.
	var pas : Dictionary = SkinSkills.get_passive(sid)
	if not pas.is_empty() and str(pas.get("id", "")) == "scars":
		specs.append({ "key": "passive:scars", "tex": CASEY_TEX, "sym": "",
			"mod": Color(1, 1, 1), "ring": RING_PASS, "dyn": true,
			"title": "НЕУЯЗВИМОСТЬ", "desc": "Маска Кейси — неуязвимость к урону." })

	# Компас-дебафф (реверс управления) — динамический кружок для ЛЮБОГО скина,
	# появляется только пока действует реверс (ключ "compass" в normaldo._skill_cd).
	specs.append({ "key": "compass", "tex": COMPASS_TEX, "sym": "",
		"mod": Color(1, 1, 1), "ring": Color(0.75, 0.40, 1.00), "dyn": true,
		"title": "РЕВЕРС", "desc": "Компас перевернул управление на 5 c." })

	# Эффекты подобранных предметов — такие же динамические кружки: появляются
	# только на время действия и для любого скина.
	specs.append({ "key": "item:magic_hat", "tex": HAT_TEX, "sym": "",
		"mod": Color(1, 1, 1), "ring": Color(0.45, 0.60, 1.00), "dyn": true,
		"title": "ШЛЯПА МАГА", "desc": "Иммунитет к замедляющим предметам." })
	specs.append({ "key": "item:cola", "tex": COLA_TEX, "sym": "",
		"mod": Color(1, 1, 1), "ring": Color(1.00, 0.35, 0.30), "dyn": true,
		"title": "БАНКА КОЛЫ", "desc": "Голова двигается быстрее." })

	# ВЕНЦЫ 10-го УРОВНЯ. В ряду они постоянные, а не динамические: у обоих есть
	# ОТКАТ, и весь смысл кружка — показать, готов перк прямо сейчас или ещё
	# копится. Динамический (появляющийся только на время действия) отвечал бы
	# на вопрос «действует ли», а у этих двоих вопрос обратный — «есть ли он у
	# меня на следующий удар».
	var lvl : int = int(SaveData.skin_level)
	if SkinProgression.has_perk(sid, lvl, "time_slow"):
		specs.append({ "key": "perk:time_slow", "tex": HOURGLASS_TEX, "sym": "",
			"mod": Color(1, 1, 1), "ring": Color(0.55, 0.85, 1.00),
			"title": "ОСТАНОВКА ВРЕМЕНИ",
			"desc": "Раз в 30 c мир сам замедляется на 3 c." })
	if SkinProgression.has_perk(sid, lvl, "spider_reflex"):
		specs.append({ "key": "perk:spider_reflex", "tex": WEB_TEX, "sym": "",
			"mod": Color(1, 1, 1), "ring": Color(0.95, 0.25, 0.30),
			"title": "ПАУЧЬЯ РЕАКЦИЯ",
			"desc": "Раз в 10 c один удар уходит в пустоту сам." })

	# Laid out from this layer's origin — the HUD positions the layer itself
	# (under the resources strip, right of the fat panel).
	var x := 0.0
	for s in specs:
		var b := Badge.new()
		b.nrm      = nrm
		b.key      = s["key"]
		b.tex      = s["tex"]
		b.symbol   = s["sym"]
		b.icon_mod = s["mod"]
		b.ring_col = s["ring"]
		b.dynamic  = s.get("dyn", false)
		b.charges_badge = s.get("chg", false)
		b.title    = s.get("title", "")
		b.desc     = s.get("desc", "")
		b.position = Vector2(x, 0.0)
		add_child(b)
		if s["key"] == "active":
			_active_badge = b
		x += D + GAP

	# Pulse the active badge when the player tries to fire it during cooldown.
	if is_instance_valid(nrm) and nrm.has_signal("active_denied") \
			and not nrm.active_denied.is_connected(_on_active_denied):
		nrm.active_denied.connect(_on_active_denied)

func _on_active_denied() -> void:
	if is_instance_valid(_active_badge):
		_active_badge.pulse_deny()

# ── One cooldown circle ───────────────────────────────────────────────────────
class Badge extends Control:
	var nrm      : Node
	var key      : String
	var tex      : Texture2D
	var symbol   : String   = ""
	var icon_mod : Color    = Color(1, 1, 1)
	var ring_col : Color    = Color(1, 1, 1)
	var dynamic  : bool     = false   # only visible while the effect is running
	var charges_badge : bool = false  # active ability with a charge counter
	var title    : String   = ""
	var desc     : String   = ""

	var _frac      : float = 0.0
	var _num       : float = 0.0
	var _charges   : int   = 0
	var _was_cool  : bool  = false
	var _snd       : AudioStreamPlayer
	var _tip       : Control = null

	func _ready() -> void:
		custom_minimum_size = Vector2(D, D)
		size                = Vector2(D, D)
		pivot_offset        = size * 0.5
		# STOP so we catch touch/press for the tooltip (parent layer is IGNORE).
		mouse_filter        = Control.MOUSE_FILTER_STOP
		if dynamic:
			visible = false
		_snd = AudioStreamPlayer.new()
		var ready_path := "res://assets/audio/skill_ready.mp3"
		if ResourceLoader.exists(ready_path):
			_snd.stream = load(ready_path)
		_snd.volume_db = -6.0
		add_child(_snd)

	# Show the tooltip while a finger/mouse is held on the circle.
	func _gui_input(ev: InputEvent) -> void:
		var pressed_evt := (ev is InputEventScreenTouch) or \
			(ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if pressed_evt:
			if ev.pressed:
				_show_tip()
			else:
				_hide_tip()

	func _show_tip() -> void:
		if is_instance_valid(_tip) or title == "":
			return
		var pc := PanelContainer.new()
		pc.z_index      = 200
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.08, 0.96)
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(6)
		sb.border_color = ring_col
		sb.set_border_width_all(1)
		pc.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		pc.add_child(vb)
		var nl := Label.new()
		nl.add_theme_font_override("font", UI_FONT)
		nl.add_theme_font_size_override("font_size", 10)
		nl.add_theme_color_override("font_color", Color(ring_col.r, ring_col.g, ring_col.b).lightened(0.35))
		nl.text = title
		vb.add_child(nl)
		if desc != "":
			var dl := Label.new()
			dl.add_theme_font_override("font", UI_FONT)
			dl.add_theme_font_size_override("font_size", 8)
			dl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(148.0, 0.0)
			dl.text = desc
			vb.add_child(dl)
		add_child(pc)
		pc.position = Vector2(-4.0, D + 5.0)   # right at the circle, just below it
		_tip = pc
		call_deferred("_clamp_tip")

	func _clamp_tip() -> void:
		if not is_instance_valid(_tip):
			return
		var vpw : float = get_viewport_rect().size.x
		var over : float = (_tip.global_position.x + _tip.size.x) - (vpw - 6.0)
		if over > 0.0:
			_tip.position.x -= over

	func _hide_tip() -> void:
		if is_instance_valid(_tip):
			_tip.queue_free()
		_tip = null

	func _exit_tree() -> void:
		_hide_tip()

	func _process(_dt: float) -> void:
		if not is_instance_valid(nrm):
			return
		var tot : float = nrm.skill_cd_total(key)
		var rem : float = nrm.skill_cd_remaining(key)
		if charges_badge:
			# Спелл заперт тактом босса — кружок гаснет. Гасим `self_modulate`, а
			# не `modulate`: по `modulate` ходят твины готовности и отказа, и
			# затемнение они стёрли бы на первом же срабатывании.
			self_modulate = Color(1, 1, 1, 0.35) if bool(nrm.get("spells_blocked")) \
				else Color(1, 1, 1, 1)
			# Show charge count while charges remain; the cooldown sweep only
			# appears once all charges are spent.
			var newc : int = nrm.active_charges()
			var cd_on := newc <= 0 and rem > 0.0
			_frac = (rem / tot) if (cd_on and tot > 0.0) else 0.0
			_num  = rem
			if _was_cool and not cd_on:
				_blink_ready()
			# Redraw only while the sweep animates or when the charge count /
			# cooling state changes — an idle badge doesn't change, so skip the
			# per-frame redraw (это была постоянная нагрузка каждый кадр).
			if cd_on or newc != _charges or _was_cool != cd_on:
				queue_redraw()
			_charges  = newc
			_was_cool = cd_on
			return
		var cooling := rem > 0.0
		_frac = (rem / tot) if tot > 0.0 else 0.0
		_num  = rem
		if dynamic:
			# Appear on activation, vanish when the effect ends (no ready blink).
			if cooling and not _was_cool:
				_pop_in()
			if not cooling and _was_cool:
				_hide_tip()
			visible = cooling
			_was_cool = cooling
			if cooling:
				queue_redraw()
			return
		if _was_cool and not cooling:
			_blink_ready()
		# Static resist/passive/active badge: redraw only while cooling down or on
		# the frame it settles. When idle it's a fixed image — no per-frame redraw.
		if cooling or _was_cool != cooling:
			queue_redraw()
		_was_cool = cooling

	func _pop_in() -> void:
		visible  = true
		scale    = Vector2(0.4, 0.4)
		modulate = Color(1, 1, 1, 1)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _blink_ready() -> void:
		modulate = Color(2.2, 2.2, 2.2, 1.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.40)
		if _snd.stream != null:
			_snd.play()

	# "Denied" feedback: a quick red-tinted size pulse (used when the player taps
	# the active ability while it's still on cooldown).
	func pulse_deny() -> void:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate", Color(1.6, 0.5, 0.4, 1.0), 0.10)
		tw.chain().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), 0.18)

	func _draw() -> void:
		var c := size * 0.5
		var r := D * 0.5
		# Кольцо + тёмный диск. Тонкая чёрная окантовка снаружи — кружок висит
		# поверх кирпичной стены, и без неё цветное кольцо на ней теряется.
		draw_circle(c, r + 1.5, Color(0, 0, 0, 0.55))
		draw_circle(c, r, ring_col)
		draw_circle(c, r - 3.0, Color(0.05, 0.05, 0.06, 0.96))
		# Icon (texture) or symbol. The item is drawn a bit LARGER than the disc so
		# it pokes out past the ring, keeping its aspect ratio.
		if tex != null:
			var isz := D * 1.16
			var ts := tex.get_size()
			var k := isz / maxf(ts.x, ts.y)
			var iw := ts.x * k
			var ih := ts.y * k
			draw_texture_rect(tex, Rect2(c - Vector2(iw, ih) * 0.5, Vector2(iw, ih)), false, icon_mod)
		elif symbol != "":
			var fs := int(D * 0.5)
			var w := UI_FONT.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(UI_FONT, Vector2(c.x - w * 0.5, c.y + fs * 0.36), symbol,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, icon_mod)
		# Cooldown sweep: dim the face, draw the receding glow arc + number.
		if _frac > 0.0:
			draw_circle(c, r - 3.0, Color(0, 0, 0, 0.50))
			var ang : float = _frac * TAU
			draw_arc(c, r - 1.6, -PI * 0.5, -PI * 0.5 + ang, 36,
				Color(ring_col.r, ring_col.g, ring_col.b, 0.95), 3.0, true)
			var txt := str(int(ceil(_num)))
			var nfs := int(D * 0.46)
			var nw := UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
			var np := Vector2(c.x - nw * 0.5, c.y + nfs * 0.36)
			# Thin (0.5 px) black outline via 4 offset draws, then white on top.
			for off in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
				draw_string(UI_FONT, np + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(0, 0, 0))
			draw_string(UI_FONT, np, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(1, 1, 1))
		# Charge counter (bottom-right pip) while charges remain.
		if charges_badge and _charges > 0:
			var br := Vector2(size.x - D * 0.16, size.y - D * 0.16)
			var rr := D * 0.27
			draw_circle(br, rr, Color(ring_col.r, ring_col.g, ring_col.b, 1.0))
			draw_circle(br, rr - 1.5, Color(0.05, 0.05, 0.06, 1.0))
			var ct := str(_charges)
			var cfs := int(D * 0.34)
			var cw := UI_FONT.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
			draw_string(UI_FONT, Vector2(br.x - cw * 0.5, br.y + cfs * 0.36), ct,
				HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(1, 1, 1))
