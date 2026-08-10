---
name: godot-dev
description: Godot 4 developer skill for the Normaldo game reimplementation. Use when working on Godot scenes, GDScript, node architecture, physics, input handling, or porting logic from Flutter Flame. Activate with /godot-dev.
---

# Godot 4 Developer — Normaldo

You are a Godot 4 expert helping port and reimagine the Normaldo game from Flutter Flame.

## Project Context

Normaldo is a mobile endless-runner where the player's head flies through obstacles. Core loop:
- Background scrolls right → items fly in from the right
- Player drags to control the head position
- Eat pizza (score/fat up), dodge obstacles
- Fat state system: skinny → slim → fat → uberFat, each slowing movement
- 5 levels with boss fights at transitions

**Key migration decision:** Replace direct drag-position mapping with inertia/spring mechanics (lerp-based). See `[[Механика управления]]`.

## Godot 4 Architecture Conventions

### Scene Structure
```
Game (Node2D)
├── Background (Node2D)         ← background.gd — infinite scroll
│   ├── BgA (Sprite2D)
│   └── BgB (Sprite2D)
├── Spawner (Node2D)            ← spawner.gd — pattern-based item spawning
└── Normaldo (Area2D)           ← normaldo.gd — layer=1, mask=2
    ├── Sprite2D
    ├── CollisionShape2D        ← CircleShape2D r=32
    ├── StickGauge (Node2D)     ← stick_gauge.gd — depleting arc, z_index=-1 (behind sprite)
    ├── ProximityArea (Area2D)  ← created in _ready() — layer=0, mask=2, r=80
    └── AudioStreamPlayer       ← created in _ready() — eat sounds
```

**z_index note:** `z_index = -1` on child nodes is relative to siblings within the same parent — it renders behind Sprite2D (default z=0) without affecting the rest of the scene.

### Input Handling — Stick Window + Inertia
```gdscript
# normaldo.gd  (extends Area2D)
const LERP_WEIGHTS   = [0.22, 0.16, 0.11, 0.08]  # per fat_state
const MAX_STICK_TIME := 2.5                        # seconds of adhesion per tap

var _target        : Vector2
var _touching      : bool  = false
var _stick_elapsed : float = 0.0

func _input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        if _attached:                     # ignore drag after timer expires
            _target = event.position
    elif event is InputEventScreenTouch:
        if event.pressed:
            if not _waiting_lift:         # only attach after a real finger lift
                _target        = event.position
                _attached      = true
                _stick_elapsed = 0.0
        else:
            _attached     = false
            _waiting_lift = false         # finger up → ready for next tap
            _gauge.hide_gauge()

func _physics_process(delta: float) -> void:
    var w := LERP_WEIGHTS[fat_state]
    if _attached:
        _stick_elapsed += delta
        if _stick_elapsed >= MAX_STICK_TIME:
            _attached     = false
            _waiting_lift = true          # block drag until finger is lifted
            _gauge.hide_gauge()
        else:
            _gauge.show_gauge(1.0 - _stick_elapsed / MAX_STICK_TIME)
    # Both directions use the same weight — fat slows ALL movement equally
    if _attached:
        position = position.lerp(_target, w)
    else:
        position = position.lerp(get_viewport_rect().get_center(), w * 0.25)
```

**Why Stick Window:** pure lerp lets the player hold the finger down forever — the head catches up, restoring direct control. The 2.5 s window enforces the "tap → maneuver → drift" rhythm.

**Why `_waiting_lift`:** when the timer expires mid-drag, `InputEventScreenDrag` events keep firing. Without this flag, they'd keep updating `_target`, causing jitter as the head flips between drifting to center and chasing the finger. `_waiting_lift = true` blocks all drag events until `InputEventScreenTouch` fires with `pressed=false`.

### Fat State System
```gdscript
# fat_state: int — 0=SKINNY 1=SLIM 2=FAT 3=UBER_FAT
const FAT_THRESHOLDS = [3, 7, 12]   # pizzas to reach SLIM, FAT, UBER_FAT
const TEXTURES = [
    preload("res://assets/normaldo/normaldo1.png"),  # SKINNY
    preload("res://assets/normaldo/normaldo2.png"),  # SLIM
    preload("res://assets/normaldo/normaldo3.png"),  # FAT
    preload("res://assets/normaldo/normaldo4.png"),  # UBER_FAT
]

# On pizza eat:
func _eat_pizza() -> void:
    _pizza_count += 1
    for i in FAT_THRESHOLDS.size():
        if _pizza_count >= FAT_THRESHOLDS[i]:
            fat_state = i + 1
    _sprite.texture = TEXTURES[fat_state]

# On obstacle hit:
func _take_hit() -> void:
    if fat_state == 0: _die(); return
    fat_state   -= 1
    _pizza_count = 0 if fat_state == 0 else FAT_THRESHOLDS[fat_state - 1]
    _sprite.texture = TEXTURES[fat_state]
    # 1.5s invincibility + red flash tween
```

### Item Spawner
```gdscript
# Weighted pool via RandomNumberGenerator
func _spawn_item() -> void:
    var item_scene = _roll_item()
    var item = item_scene.instantiate()
    item.position = Vector2(
        get_viewport_rect().size.x + item.width,
        _line_centers_y[randi() % LINE_COUNT]
    )
    add_child(item)
```

### Signals Convention
- Use Godot signals for game events: `pizza_eaten`, `damage_taken`, `fat_state_changed`, `level_changed`, `boss_started`
- GameState autoload subscribes to all; HUD subscribes to display signals

## GDScript Style Rules

- `snake_case` everywhere — variables, functions, files, node names
- `UPPER_SNAKE` for constants and enums
- Type hints always: `var speed: float`, `func take_damage(amount: int) -> void`
- `@export` for designer-tweakable values
- `@onready` for node references: `@onready var sprite := $Sprite2D`
- Prefer `CharacterBody2D` + `move_and_slide()` over `RigidBody2D` for controllable entities
- Items use `Area2D` with collision layers; Normaldo on layer 1, items on layer 2

## Physics Layers
| Layer | Name | Used by |
|-------|------|---------|
| 1 | player | Normaldo hitbox |
| 2 | items | All spawned items |
| 3 | boss | Boss hitboxes |
| 4 | projectile | Boss projectiles |

## Porting from Flutter Flame

| Flutter Flame | Godot 4 |
|---|---|
| `PositionComponent` | `Node2D` / `CharacterBody2D` |
| `DragCallbacks.onDragUpdate` | `_input(InputEventScreenDrag)` |
| `FlameGame.update()` | `_process(delta)` / `_physics_process(delta)` |
| `TimerComponent` | `Timer` node |
| `SpriteAnimationComponent` | `AnimatedSprite2D` |
| `HasCollisionDetection` | `Area2D` + `body_entered` signal |
| BLoC state | Autoload singleton + signals |
| `MoveByEffect` | `Tween` / `AnimationPlayer` |
| `lerp` | `Vector2.lerp()` / `@export` weight |

## Common Pitfalls

- Godot uses Y-down coordinates; flip sprite offsets from Flutter if needed
- `delta` in `_process` is seconds, not milliseconds — multiply speeds accordingly
- Mobile touch input: enable `InputMap` → add touch actions, or use `_input()` with `InputEventScreenDrag`
- For lerp-based movement, use `_physics_process` not `_process` to stay in sync with physics
- Collision shapes must be set on the correct layer/mask or signals won't fire

## Workflow Commands

When asked to implement a feature:
1. Identify the Flutter Flame equivalent (see Porting table)
2. Choose correct Godot node type
3. Write typed GDScript with `@export` for tunables
4. Wire signals in `_ready()` — never use `get_node()` in `_process()`
5. Test in editor with `F5`, check Remote scene tree for node state
6. **Update `Концепция/` notes** if the implementation changes or refines a mechanic

## Lint Check Rule (MANDATORY)

**After every code change, ALWAYS check and fix lint errors before reporting completion.**

### Common GDScript Lint Issues to Watch For

1. **Variable used before declaration**
   ```gdscript
   # WRONG - res_x uses badge_w before it's declared
   var res_x = vp.x - badge_w - 10.0  # badge_w not declared yet!
   var badge_w := 118.0
   
   # CORRECT - declare dependencies first
   var badge_w := 118.0
   var res_x = vp.x - badge_w - 10.0
   ```

2. **Duplicate variable declaration in same scope**
   ```gdscript
   # WRONG - dev_w declared twice
   var dev_w := 100.0
   var dev_x := vp.x - dev_w - res_padding
   var dev_y := vp.y * 0.5
   var dev_w := 100.0  # duplicate!
   
   # CORRECT - each var once
   var dev_w := 100.0
   var dev_x := vp.x - dev_w - res_padding
   var dev_y := vp.y * 0.5
   ```

3. **Type inference on same line with dependency**
   ```gdscript
   # WRONG - res_x depends on res_padding which is declared after
   var res_x = vp.x - res_padding  # res_padding not in scope yet
   var res_padding := 16.0
   
   # CORRECT - use := when variable depends on later declaration
   var res_padding := 16.0
   var res_x := vp.x - res_padding
   ```

### How to Check for Lint Errors

Run this command to find duplicate var declarations within the same function:
```bash
cd scripts && python3 << 'EOF'
import re

def check_lint(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    functions = re.split(r'(func \w+\()', content)
    errors = []
    
    for i in range(1, len(functions), 2):
        func_name = functions[i].strip()
        func_body = functions[i+1] if i+1 < len(functions) else ""
        
        lines = func_body.split('\n')
        var_decls = {}
        
        for j, line in enumerate(lines):
            # Check for var/const declaration
            match = re.match(r'^\s*(var|const)\s+(\w+)\s*[:=]', line)
            if match:
                name = match.group(2)
                if name in var_decls:
                    errors.append(f"DUPLICATE: '{name}' in {func_name} (lines {var_decls[name]+1}, {j+1})")
                else:
                    var_decls[name] = j
            
            # Check for variable used before declaration in same scope
            for var_name in var_decls:
                if var_name in line and '=' in line and 'var ' not in line:
                    if line.index(var_name) < line.index('='):
                        if var_decls[var_name] > j:
                            errors.append(f"USE-BEFORE-DECLARE: '{var_name}' at {func_name}:{j+1}")
        
    if errors:
        for e in errors:
            print(e)
        return False
    print(f"✓ {file_path}: No lint errors")
    return True

import sys
for f in sys.argv[1:]:
    check_lint(f)
EOF
```

### Checklist Before Reporting "Done"

- [ ] No duplicate variable declarations in same function/scope
- [ ] Variables used only after they're declared (dependencies first)
- [ ] All type hints present where needed
- [ ] No `var x = y` where `y` references undeclared variable — use `:=` to force re-assignment

## Concept Sync Rule

The `Концепция/` folder is the design source of truth. After any code change that affects gameplay mechanics:

- **What to check:** Does the change affect how control, fat state, spawning, difficulty, or effects work?
- **If yes:** Update the relevant note in `Концепция/`. At minimum, fix the description and any code snippets shown.
- **If a new sub-mechanic is added** (e.g., Stick Window, new effect): add it to the relevant note under its own `##` section, with `[[wiki links]]` to connected concepts.
- **Never leave a TODO comment** in GDScript as a substitute for a concept update — document it properly.

### Which note to update for which change

| Change type | Primary note | Secondary |
|---|---|---|
| Input / movement feel | `Механика управления` | `Принцип инерции (резинки)` |
| Fat state thresholds / lerp weights | `Система толщины` | `Механика управления` |
| Obstacle patterns / spawn logic | `Паттерны препятствий` | `Прогрессия сложности` |
| Difficulty curve / timing | `Прогрессия сложности` | `Ритм и динамика` |
| New effect / power-up | `Эффекты и бонусы` | relevant mechanic note |
