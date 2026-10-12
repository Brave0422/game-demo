class_name Player
extends CharacterBody2D
## 共用移动、顶砖和输入边界；生命、武器、视觉由子组件负责。

## 死亡通知关卡；关卡在帧末与 Boss 胜利统一仲裁。
signal died
## 角色只读移动配置。
@export var data: CharacterData
## 当前面朝方向，值为 -1 或 1。
var facing: float = 1.0
## 当前是否保持趴下碰撞。
var crouched: bool = false
## 菜单确认后必须先松开射击键，避免 UI 确认同时开火。
var input_locked: bool = true
## 视觉步态累计物理时间。
var animation_time: float = 0.0
## 离地宽限剩余秒数。
var _coyote: float = 0.0
## 跳跃缓存剩余秒数。
var _jump_buffer: float = 0.0
## 受伤水平控制锁定秒数。
var _knockback: float = 0.0
## 独立生命节点，聚合同帧伤害。
@onready var health: Health = $Health
## 独立武器节点，维护能量和弹体事务。
@onready var weapons: WeaponController = $WeaponController
## 枪口世界锚点，由瞄准方向设置。
@onready var muzzle: Marker2D = $Muzzle
## 玩家移动实体碰撞；趴下只修改本实例 Shape。
@onready var body_shape: CollisionShape2D = $BodyShape
## 独立伤害碰撞体，与身体不承担同一碰撞职责。
@onready var hurt_shape: CollisionShape2D = $Hurtbox/Shape
## 分层卡通绘制节点，碰撞不随动画抖动。
@onready var visual: Node2D = $PlayerVisual


## 注入组件依赖和角色资源，建立统一受伤事件连接。
func _ready() -> void:
	add_to_group("player")
	body_shape.shape = body_shape.shape.duplicate()
	hurt_shape.shape = hurt_shape.shape.duplicate()
	health.maximum = data.max_hp
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	weapons.setup(self)
	visual.player = self


## delta 为固定物理步秒数，执行移动、站起检测、顶砖和武器输入。
func _physics_process(delta: float) -> void:
	if health.current <= 0:
		return
	animation_time += delta
	if (
		input_locked
		and not Input.is_action_pressed("shoot")
		and not Input.is_action_pressed("ui_accept")
	):
		input_locked = false
	# horizontal 是左右相抵后的轴输入。
	var horizontal: float = Input.get_axis("move_left", "move_right") if not input_locked else 0.0
	if horizontal != 0.0:
		facing = signf(horizontal)
	_update_stance(horizontal)
	_coyote = 0.1 if is_on_floor() else maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_knockback = maxf(0.0, _knockback - delta)
	if Input.is_action_just_pressed("jump") and not input_locked:
		_jump_buffer = 0.12
	if _jump_buffer > 0.0 and _coyote > 0.0 and not crouched:
		velocity.y = data.jump_speed
		_jump_buffer = 0.0
		_coyote = 0.0
		AudioManager.play_sfx("jump", global_position)
	if Input.is_action_just_released("jump") and velocity.y < -320.0:
		velocity.y = -320.0
	if _knockback <= 0.0:
		# acceleration 区分空中操控、地面加速与无输入制动。
		var acceleration: float = data.acceleration if is_on_floor() else data.air_acceleration
		if horizontal == 0.0:
			acceleration = data.deceleration
		velocity.x = move_toward(
			velocity.x, horizontal * data.speed if not crouched else 0.0, acceleration * delta
		)
	velocity.y = minf(1100.0, velocity.y + data.gravity * delta)
	# previous_vertical 必须在 move_and_slide 将碰撞速度清零前保存。
	var previous_vertical: float = velocity.y
	move_and_slide()
	if previous_vertical < 0.0:
		# collision_index 枚举本步真实碰撞，只有朝下法线代表撞到物体底部。
		for collision_index: int in get_slide_collision_count():
			# collision 为当前头顶/侧面/地面接触信息。
			var collision: KinematicCollision2D = get_slide_collision(collision_index)
			if (
				collision.get_normal().y > 0.7
				and collision.get_collider().has_method("hit_from_below")
			):
				collision.get_collider().hit_from_below()
	global_position.x = maxf(24.0, global_position.x)
	if global_position.y > 980.0:
		health.request_damage(data.max_hp, global_position, true)
	muzzle.position = Vector2(facing * 9, -24 if crouched else -65) + aim_direction() * 49.0
	if not input_locked:
		weapons.tick(delta)
	visual.queue_redraw()


## horizontal 为当前左右输入；站起使用完整体积查询，禁止钻入低顶。
func _update_stance(horizontal: float) -> void:
	# wants_crouch 只有比尔落地且无左右输入时生效。
	var wants_crouch: bool = (
		data.id == "bill"
		and is_on_floor()
		and Input.is_action_pressed("move_down")
		and horizontal == 0.0
	)
	if crouched and not wants_crouch:
		# standing_shape 为目标站立体积，脚底锚点不变。
		var standing_shape: RectangleShape2D = RectangleShape2D.new()
		standing_shape.size = Vector2(40, 86)
		# query 只检测世界实体，排除自己。
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = standing_shape
		query.transform = Transform2D(0.0, global_position + Vector2(0, -45))
		query.collision_mask = 1
		wants_crouch = not get_world_2d().direct_space_state.intersect_shape(query).is_empty()
	crouched = wants_crouch
	body_shape.shape.size = Vector2(60, 36) if crouched else Vector2(42, 88)
	body_shape.position.y = -18 if crouched else -44
	hurt_shape.shape.size = body_shape.shape.size
	hurt_shape.position.y = body_shape.position.y


## 返回角色允许的单位瞄准方向；洛克人始终水平。
func aim_direction() -> Vector2:
	if data.id == "mega_man" or crouched:
		return Vector2(facing, 0)
	# direction 为键盘轴，归一化保证八方向速度一致。
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		return Vector2(facing, 0)
	if is_on_floor() and direction.x == 0.0 and direction.y > 0.0:
		return Vector2(facing, 0)
	return direction.normalized()


## 弹体和敌人通过此统一入口提交 amount 伤害，origin 表示来源位置。
func receive_hit(amount: int, origin: Vector2) -> void:
	health.request_damage(amount, origin)


## 有效受伤时应用一次击退；amount 由生命组件聚合，origin 决定方向。
func _on_damaged(_amount: int, origin: Vector2) -> void:
	velocity = Vector2(180.0 * (1.0 if global_position.x >= origin.x else -1.0), -180.0)
	_knockback = 0.12
	AudioManager.play_sfx("hurt", global_position)


## 停止输入与蓄力并报告死亡；界面由关卡决定。
func _on_died() -> void:
	weapons.cancel_charge()
	input_locked = true
	visual.queue_redraw()
	died.emit()
