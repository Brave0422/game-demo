class_name SporeKing
extends Node2D
## 两阶段 Boss：预警锁定目标，攻击结束才露腹部核心，半血转换只执行一次。

## HP 归零报告胜利候选，由关卡优先于玩家死亡处理。
signal defeated
## 阶段变化和受伤后通知 HUD。
signal changed
## 满血值，可在编辑器调参。
@export var max_hp: int = 120
## 竞技场左边界。
@export var arena_left: float = 42240.0
## 竞技场右边界。
@export var arena_right: float = 43520.0
## 注入的玩家目标。
var player: Player
## 当前生命。
var hp: int = 120
## 当前阶段 1 或 2。
var phase: int = 1
## 状态：idle、intro、telegraph、attack、impact、exposed、transition、phase_change、defeated。
var state: String = "idle"
## 状态剩余秒数。
var timer: float = 0.0
## 招式序号 0～2。
var move_index: int = 0
## 当前招式：slam、fan、wave 或 combo。
var move_kind: String = "slam"
## 预警锁定的落点。
var locked_x: float = 0.0
## 预警锁定的朝向。
var facing: float = -1.0
## 扑砸起始位置。
var _jump_start: Vector2 = Vector2.ZERO
## 待帧末切换第二阶段。
var _phase_pending: bool = false
## 每次攻击组已累计 Boss 伤害。
var _attack_damage: Dictionary = {}
## 表现累计物理时间。
var _time: float = 0.0


## 初始化生命并注册唯一 Boss 组。
func _ready() -> void:
	add_to_group("boss")
	hp = max_hp


## 入场门确认玩家安全位置后调用，Boss 此前不会行动。
func begin() -> void:
	if state != "idle":
		return
	_enter("intro", 1.0)
	AudioManager.change_music("boss")
	changed.emit()


## delta 为物理秒数，状态转换由单一入口负责取消旧计时。
func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if state in ["idle", "defeated"]:
		return
	timer = maxf(0.0, timer - delta)
	if state == "attack" and move_kind == "slam":
		# progress 为扑砸飞行进度；落点固定，不追踪玩家。
		var progress: float = 1.0 - timer / 0.7
		global_position = _jump_start.lerp(Vector2(locked_x, 576), progress)
		global_position.y -= sin(progress * PI) * 245.0
	if state == "impact" and is_instance_valid(player):
		if absf(player.global_position.x - locked_x) < 117 and player.global_position.y > 528:
			player.receive_hit(2, global_position)
	if timer > 0.0:
		return
	match state:
		"intro", "transition", "phase_change":
			_telegraph()
		"telegraph":
			_attack()
		"attack":
			if move_kind == "slam":
				global_position = Vector2(locked_x, 576)
				_enter("impact", 0.2)
				AudioManager.play_sfx("break", global_position)
			else:
				_expose()
		"impact":
			_expose()
		"combo_warning":
			_fan()
			_expose()
		"exposed":
			move_index = (move_index + 1) % 3
			_enter("transition", 0.6)


## 根据阶段循环选招，并锁定当前目标、方向和地面预警。
func _telegraph() -> void:
	move_kind = (
		["slam", "fan", "wave"][move_index] if phase == 1 else ["slam", "combo", "fan"][move_index]
	)
	locked_x = clampf(player.global_position.x, arena_left + 160, arena_right - 160)
	facing = 1.0 if player.global_position.x > global_position.x else -1.0
	_enter("telegraph", 0.85 if move_kind == "slam" else (0.7 if move_kind == "fan" else 0.65))
	AudioManager.play_sfx("warning", global_position)


## 执行已经预警的攻击，二阶段组合追加独立 0.75 秒嘴部预警。
func _attack() -> void:
	match move_kind:
		"slam":
			_jump_start = global_position
			_enter("attack", 0.7)
		"fan":
			_fan()
			_expose()
		"wave", "combo":
			_spawn(Vector2(facing, 0), 260.0, true)
			if move_kind == "combo":
				_enter("combo_warning", 0.75)
				AudioManager.play_sfx("warning", global_position)
			else:
				_expose()


## 发出 3/5 颗非追踪扇形孢子，两阶段最高速度只提高 15%。
func _fan() -> void:
	# angles 是当前阶段的发散角度。
	var angles: PackedFloat32Array = PackedFloat32Array(
		[-30.0, 0.0, 30.0] if phase == 1 else [-40.0, -20.0, 0.0, 20.0, 40.0]
	)
	# angle 为单颗弹相对水平方向的角度。
	for angle: float in angles:
		_spawn(Vector2(facing, 0).rotated(deg_to_rad(angle)), 240.0, false)
	AudioManager.play_sfx("spore", global_position)


## direction 为单位方向，base_speed 为一阶段速度，wave 指地面波。
func _spawn(direction: Vector2, base_speed: float, wave: bool) -> void:
	# projectile 为独立敌方攻击；关卡/阶段切换可统一清理。
	var projectile: Projectile = preload("res://scenes/effects/projectile.tscn").instantiate()
	projectile.hostile = true
	projectile.kind = "ground_wave" if wave else "spore"
	projectile.direction = direction
	projectile.speed = base_speed * (1.15 if phase == 2 else 1.0)
	projectile.tint = Color("e4a2f1")
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(facing * 140, -25 if wave else -78)


## 进入核心暴露窗口；碰撞体仍在，但装甲入口不再拦截。
func _expose() -> void:
	_enter("exposed", 1.8 if phase == 1 else 1.5)
	changed.emit()


## projectile 由弹体提交；按攻击组执行散弹/火环伤害上限。
func receive_projectile(projectile: Projectile) -> String:
	if state != "exposed" or hp <= 0:
		AudioManager.play_sfx("armor", global_position)
		return "blocked"
	# amount 为冰刃对 Boss 特例或普通伤害。
	var amount: int = 2 if projectile.kind == "ice" else projectile.damage
	# accumulated 为同一发攻击已造成的实际伤害。
	var accumulated: int = int(_attack_damage.get(projectile.attack_id, 0))
	if projectile.boss_cap > 0:
		amount = mini(amount, maxi(0, projectile.boss_cap - accumulated))
	_attack_damage[projectile.attack_id] = accumulated + amount
	hp = maxi(0, hp - amount)
	changed.emit()
	if hp <= 0:
		_enter("defeated", 2.0)
		_clear_attacks()
		defeated.emit()
	elif hp <= max_hp / 2 and phase == 1 and not _phase_pending:
		_phase_pending = true
		_change_phase.call_deferred()
	return "hit"


## 本帧全部命中处理后再半血切换，若同帧已死则保留胜利。
func _change_phase() -> void:
	if hp <= 0:
		return
	phase = 2
	move_index = 0
	_clear_attacks()
	_enter("phase_change", 1.0)
	changed.emit()


## 清除敌方残留攻击，阶段怒吼和胜利都调用。
func _clear_attacks() -> void:
	# projectile 为当前场景全部敌方弹体。
	for projectile: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.finish()


## next_state 为新状态，duration 为持续秒数；只有此入口写状态和计时器。
func _enter(next_state: String, duration: float) -> void:
	state = next_state
	timer = duration
	queue_redraw()


## 手绘 Boss 四态与真实预警；核心暴露时亮环，非暴露时降低核心亮度。
func _draw() -> void:
	if state in ["telegraph","attack","impact"] and move_kind=="slam":
		draw_rect(Rect2(locked_x-global_position.x-96,571-global_position.y,192,5),
			Color("ffb18c"))
		draw_line(Vector2(locked_x-global_position.x,541-global_position.y),
			Vector2(locked_x-global_position.x,571-global_position.y),Color("ffe4a5"),4,true)
	# frame 为待机、举拳、喷吐与倒下四态。
	var frame: int = 0
	if state=="defeated":
		frame = 3
	elif state in ["telegraph","attack"] and move_kind=="slam":
		frame = 1
	elif state=="combo_warning" or (state=="telegraph" and move_kind!="slam"):
		frame = 2
	# tint 为第二阶段轻微暖色调制，纹理和剪影不变。
	var tint: Color = Color("ffe1c6") if phase==2 else Color.WHITE
	PaintedArt.draw(self,"boss_%d" % frame,Rect2(-216,-338.4,432,360),tint)
	if state=="exposed":
		draw_arc(Vector2(-18,-85),47,0,TAU,40,Color("fff7a3"),4,true)
		draw_circle(Vector2(-18,-85),54,Color(1,0.8,0.22,0.12))
	elif state!="defeated":
		draw_circle(Vector2(-18,-85),38,Color(0.14,0.08,0.05,0.48))
	if state=="telegraph" or state=="combo_warning":
		draw_colored_polygon(PackedVector2Array(
			[Vector2(-15,-365),Vector2(15,-365),Vector2(0,-341)]),Color("ffe8ad"))
