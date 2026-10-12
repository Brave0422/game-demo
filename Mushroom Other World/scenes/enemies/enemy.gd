class_name Enemy
extends CharacterBody2D
## 五怪显式状态机；分别处理巡逻挥击、喷吐、俯冲、滚动及方向护甲。

## 真实死亡信号；冻结不会发出。
signal defeated(stable_id: String)
## 静态敌人机制与数值。
@export var data: EnemyData
## 快照与遭遇战使用的稳定实例 ID。
@export var stable_id: String = ""
## 左右巡逻半径。
@export var patrol_radius: float = 180.0
## 父关卡注入的玩家。
var player: Player
## 当前生命值。
var hp: int = 3
## 状态名：idle、telegraph、attack、recovery、frozen、dead。
var state: String = "idle"
## 当前状态剩余秒数。
var state_time: float = 0.0
## 当前面朝方向。
var facing: float = -1.0
## 配置出生位置，活敌重试时复位。
var home: Vector2 = Vector2.ZERO
## 预警开始时锁定的目标点。
var locked_target: Vector2 = Vector2.ZERO
## 独立攻击冷却，避免恢复后每帧启动。
var _cooldown: float = 0.0
## 动画物理时钟。
var _animation_time: float = 0.0
## 受击闪白剩余秒数。
var _flash: float = 0.0
## 蘑菇已有序列动画资源缓存。
var _mushroom_frames: Dictionary = {}
## 已有蝙蝠两帧纹理。
var _bat_frames: Array[Texture2D] = []
## 身体碰撞节点，怪物只与世界碰撞。
@onready var body_shape: CollisionShape2D = $BodyShape


## 初始化独立生命与图片；只有蝙蝠不使用重力。
func _ready() -> void:
	add_to_group("enemies")
	hp = data.max_hp
	home = global_position
	if data.id == "patrol":
		# animation 对应已有蘑菇资源的动作目录。
		for animation: String in ["idle", "walk", "attack", "hurt", "dead"]:
			# folder 是固定动作目录名。
			var folder: String = {
				"idle": "01_idle",
				"walk": "02_walk",
				"attack": "03_attack",
				"hurt": "04_hurt",
				"dead": "05_dead"
			}[animation]
			# frames 保存当前动作全部可导入纹理。
			var frames: Array[Texture2D] = []
			# frame_index 按连续命名读取，不依赖目录遍历顺序。
			for frame_index: int in range(16):
				# path 是现有动画帧的精确路径。
				var path: String = (
					"res://assets/art/enemies/mushroom/%s/mushroom_%s_%03d.png"
					% [folder, animation, frame_index]
				)
				if ResourceLoader.exists(path):
					frames.append(load(path))
			_mushroom_frames[animation] = frames
	if data.id == "bat":
		_bat_frames.assign(
			[
				load("res://assets/art/enemies/bat/bat_1.png"),
				load("res://assets/art/enemies/bat/bat_2.png")
			]
		)
		body_shape.disabled = true


## delta 为物理步长；未激活敌人保留当前 HP，但不会在视野外发动攻击。
func _physics_process(delta: float) -> void:
	if state == "dead":
		state_time -= delta
		_animation_time += delta
		modulate.a = clampf(state_time / 0.4, 0.0, 1.0)
		queue_redraw()
		if state_time <= 0:
			queue_free()
		return
	if not is_instance_valid(player):
		return
	if absf(global_position.x - player.global_position.x) > 1920.0:
		return
	_animation_time += delta
	_flash = maxf(0.0, _flash - delta)
	state_time = maxf(0.0, state_time - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if state == "frozen":
		if state_time <= 0.0:
			_enter_state("recovery", 0.5)
		queue_redraw()
		return
	if state == "telegraph" and state_time <= 0.0:
		_enter_state("attack", data.attack_time)
		if data.id == "spitter":
			_spawn_spore()
	elif state == "attack":
		_update_attack(delta)
		if state_time <= 0.0:
			_enter_state("recovery", data.recovery_time)
	elif state == "recovery" and state_time <= 0.0:
		_enter_state("idle", 0.0)
		_cooldown = 1.2 if data.id == "bat" else (1.0 if data.id == "beetle" else 0.2)
	if state == "idle":
		_update_idle(delta)
	if data.id != "bat":
		velocity.y = minf(1100.0, velocity.y + 1800.0 * delta)
		move_and_slide()
	if data.contact_damage > 0 and state == "idle":
		_contact_attack(Vector2(0, -32), Vector2(78, 66), data.contact_damage)
	if global_position.y > 950:
		_die()
	queue_redraw()


## delta 为物理秒数；五种行为各自有移动与触发条件。
func _update_idle(delta: float) -> void:
	# difference 为到玩家的位移，预警时才锁定，不在攻击中追踪。
	var difference: Vector2 = player.global_position - global_position
	if data.id == "bat":
		global_position = global_position.move_toward(
			home + Vector2(sin(_animation_time) * 100, 0), data.movement_speed * delta
		)
	elif data.id == "spitter":
		velocity.x = 0.0
		facing = signf(difference.x) if difference.x != 0.0 else facing
	else:
		# floor_probe 检查前方有没有落脚地面，避免地面怪自行掉坑。
		var floor_probe: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position + Vector2(facing * 48, -16),
			global_position + Vector2(facing * 48, 60),
			1
		)
		if (
			is_on_wall()
			or absf(global_position.x - home.x) >= patrol_radius
			or (
				is_on_floor()
				and get_world_2d().direct_space_state.intersect_ray(floor_probe).is_empty()
			)
		):
			facing *= -1.0
		velocity.x = facing * data.movement_speed
	if data.id == "roller" or _cooldown > 0.0:
		return
	# visible_range 防止尚未进入镜头的敌人开始攻击预警。
	var visible_range: bool = absf(difference.x) < 560.0
	if difference.length() < data.detection_range and visible_range:
		locked_target = player.global_position + Vector2(0, -40)
		facing = 1.0 if difference.x >= 0.0 else -1.0
		velocity.x = 0.0
		_enter_state("telegraph", data.telegraph_time)
		AudioManager.play_sfx("warning", global_position)


## delta 为物理秒数；只有攻击窗口主动提交近战候选。
func _update_attack(delta: float) -> void:
	match data.id:
		"patrol":
			_contact_attack(Vector2(facing * 52, -35), Vector2(80, 70), 1)
		"beetle":
			_contact_attack(Vector2(facing * 65, -40), Vector2(100, 80), 1)
		"bat":
			global_position = global_position.move_toward(locked_target, 300.0 * delta)
			_contact_attack(Vector2(0, -25), Vector2(94, 48), 1)


## offset 为局部中心、size 为攻击矩形、amount 为伤害；身体重叠本身不伤人。
func _contact_attack(offset: Vector2, size: Vector2, amount: int) -> void:
	# attack_area 为世界空间攻击矩形。
	var attack_area: Rect2 = Rect2(global_position + offset - size * 0.5, size)
	# player_area 使用玩家当前站立/趴下碰撞体，保持视觉和判定一致。
	var player_area: Rect2 = Rect2(
		player.global_position + player.body_shape.position - player.body_shape.shape.size * 0.5,
		player.body_shape.shape.size
	)
	if attack_area.intersects(player_area):
		player.receive_hit(amount, global_position)


## 喷吐沿预警锁定方向发射一颗孢子，之后不追踪。
func _spawn_spore() -> void:
	# projectile 为独立敌弹，碰玩家或世界立即回收。
	var projectile: Projectile = preload("res://scenes/effects/projectile.tscn").instantiate()
	projectile.hostile = true
	projectile.kind = "spore"
	projectile.tint = Color("ed93da")
	projectile.speed = 220.0
	projectile.direction = (locked_target - (global_position + Vector2(0, -50))).normalized()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(facing * 44, -50)
	_cooldown = 2.4
	AudioManager.play_sfx("spore", global_position)


## projectile 携带攻击方向与冰冻类型；返回 blocked 或 hit 供弹体回收。
func receive_projectile(projectile: Projectile) -> String:
	if state == "dead":
		return "hit"
	# front_hit 用命中来源位置统一判定火环、穿透弹和回旋弹护甲。
	var front_hit: bool = (projectile.global_position.x - global_position.x) * facing > 0.0
	if data.id == "beetle" and state != "recovery" and state != "frozen" and front_hit:
		AudioManager.play_sfx("armor", global_position)
		return "blocked"
	if projectile.kind == "ice":
		_enter_state("frozen", 2.5)
		velocity = Vector2.ZERO
	else:
		hp = maxi(0, hp - projectile.damage)
		_flash = 0.12
		AudioManager.play_sfx("hit", global_position)
		if hp <= 0:
			_die()
	return "hit"


## next_state 为目标状态，duration 为持续秒数；切换时取消旧近战移动。
func _enter_state(next_state: String, duration: float) -> void:
	state = next_state
	state_time = duration
	velocity.x = 0.0


## 原子标记死亡后发出稳定 ID，冻结永远不进入此路径。
func _die() -> void:
	if state == "dead":
		return
	_enter_state("dead", 0.4)
	_animation_time = 0.0
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit(stable_id)
	set_physics_process(true)
	queue_redraw()


## 绘制轮廓、明确预警形状、冻结和血量；基础素材来自已下载资源。
func _draw() -> void:
	if not data:
		return
	# color 为各机制标识色，形状也各自不同。
	var color: Color = Color("9fcb64")
	if data.id == "patrol" and not _mushroom_frames.is_empty():
		# animation 为当前状态对应动作，移动与待机分离。
		var animation: String = (
			"dead"
			if state == "dead"
			else (
				"hurt"
				if _flash > 0
				else (
					"attack" if state == "attack" else ("walk" if absf(velocity.x) > 0 else "idle")
				)
			)
		)
		# frames 为已加载动作帧。
		var frames: Array = _mushroom_frames[animation]
		if not frames.is_empty():
			draw_set_transform(Vector2.ZERO, 0, Vector2(-facing, 1))
			draw_texture_rect_region(
				frames[int(_animation_time * 10) % frames.size()],
				Rect2(-48, -84, 96, 84),
				Rect2(28, 65, 252, 207)
			)
			draw_set_transform(Vector2.ZERO)
	elif data.id == "bat" and not _bat_frames.is_empty():
		draw_texture_rect(
			_bat_frames[int(_animation_time * 8) % 2],
			Rect2(-62, -70, 124, 80),
			false,
			Color("c29beb")
		)
	elif data.id == "roller":
		# spike_index 绘制十二根真实尖刺，冻结时由冰壳覆盖。
		for spike_index: int in range(12):
			# angle 是滚动旋转后的当前尖刺角度。
			var angle: float = spike_index * TAU / 12 + _animation_time * facing * 2
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(0, -36) + Vector2.from_angle(angle - 0.17) * 29,
						Vector2(0, -36) + Vector2.from_angle(angle) * 45,
						Vector2(0, -36) + Vector2.from_angle(angle + 0.17) * 29
					]
				),
				Color("34484a")
			)
		draw_circle(Vector2(0, -36), 32, Color("ba784b"))
		draw_arc(
			Vector2(0, -36), 22, _animation_time, 5 + _animation_time, 24, Color("f6c174"), 5, true
		)
	elif data.id == "beetle":
		draw_style_box(_style(Color("a898c8")), Rect2(-43, -48, 86, 43))
		draw_circle(Vector2(-facing * 25, -26), 16, Color("ffc387"))
		# shield_offset 打开护甲时将盾片抬起，不能只换颜色。
		var shield_offset: Vector2 = Vector2(
			facing * 27, -44 if state == "recovery" or state == "frozen" else -24
		)
		draw_style_box(
			_style(Color("628e99")), Rect2(shield_offset - Vector2(17, 32), Vector2(34, 64))
		)
		draw_line(
			shield_offset + Vector2(0, -21),
			shield_offset + Vector2(0, 18),
			Color("d4eee4"),
			4,
			true
		)
	else:
		draw_style_box(_style(Color("eed497")), Rect2(-23, -50, 46, 48))
		draw_circle(Vector2(0, -62), 40, Color("364b44"))
		draw_circle(Vector2(0, -64), 35, color)
		draw_circle(Vector2(-16, -77), 9, Color("f8e9b9"))
		draw_style_box(_style(Color("d8954b")), Rect2(facing * 22 - 17, -56, 34, 27))
		draw_circle(Vector2(facing * 37, -42), 10, Color("3b3b47"))
	if state == "telegraph":
		draw_colored_polygon(
			PackedVector2Array([Vector2(-12, -126), Vector2(12, -126), Vector2(0, -105)]),
			Color("ffe492")
		)
		draw_line(Vector2(0, -136), Vector2(0, -145), Color("fff3ce"), 5, true)
		if data.id == "bat":
			draw_line(
				Vector2(0, -25), locked_target - global_position, Color(1, 0.55, 0.5, 0.5), 3, true
			)
	if state == "attack" and data.id in ["patrol", "beetle"]:
		draw_arc(
			Vector2(facing * 32, -40),
			50,
			-1.3 if facing > 0 else 1.8,
			1.3 if facing > 0 else 4.5,
			24,
			Color("ffd57e"),
			9,
			true
		)
	if state == "frozen":
		draw_style_box(_style(Color(0.5, 0.86, 1, 0.5)), Rect2(-48, -94, 96, 94))
		draw_line(Vector2(-25, -80), Vector2(20, -12), Color("d4fbff"), 3, true)
	if hp < data.max_hp:
		draw_rect(Rect2(-30, -103, 60, 5), Color("334453"))
		draw_rect(Rect2(-30, -103, 60.0 * hp / data.max_hp, 5), Color("f9b879"))
	if state != "dead":
		modulate = Color(1.8, 1.8, 1.8) if _flash > 0 else Color.WHITE


## color 为填色，返回统一卡通圆角描边样式。
func _style(color: Color) -> StyleBoxFlat:
	# style 为当前绘制层使用的轻量画笔。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("304550")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	return style
