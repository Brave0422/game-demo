class_name Projectile
extends Node2D
## 独立弹体：物理步扫掠、穿透去重、回旋去返程、冻结与火环。

## 发射者引用，仅在本关内有效。
var shooter: Node2D
## 武器标识，用于活动弹体上限。
var weapon_id: String = ""
## 弹道类型。
var kind: String = "straight"
## 归一化前进方向。
var direction: Vector2 = Vector2.RIGHT
## 单位/秒速度。
var speed: float = 900.0
## 单次命中伤害。
var damage: int = 1
## 同批发射组 ID。
var attack_id: String = ""
## Boss 同批次伤害上限。
var boss_cap: int = 0
## 允许普通目标命中数。
var remaining_hits: int = 1
## 蓄力弹级别，0 为普通弹。
var charge_level: int = 0
## 是否敌方弹体。
var hostile: bool = false
## 视觉主色。
var tint: Color = Color("ffe397")
## 发射起点用于波动与回旋轨迹。
var start_position: Vector2 = Vector2.ZERO
## 当前年龄，秒。
var age: float = 0.0
## 切刃是否已经返回。
var returning: bool = false
## 当前程已命中实例集合。
var _hit_ids: Dictionary = {}
## 已消失标记，延迟删除前阻止第二次结算。
var _finished: bool = false


## spec 为配置，actor 为发射者，aim 为单位方向，level 为蓄力级别，group_id 为发射组。
func configure(spec: WeaponData, actor: Node2D, aim: Vector2, level: int, group_id: String) -> void:
	shooter = actor
	weapon_id = spec.id
	kind = spec.kind
	direction = aim.normalized()
	speed = spec.speed
	damage = spec.damage if level == 0 else (5 if level == 2 else 2)
	remaining_hits = spec.pierce_count if level == 0 else 2
	charge_level = level
	attack_id = group_id
	boss_cap = spec.target_damage_cap
	tint = spec.tint


## 注册阵营组；所属关卡统一清理这些短生命周期节点。
func _ready() -> void:
	add_to_group("enemy_projectiles" if hostile else "player_projectiles")
	start_position = global_position


## delta 为固定步长；从旧位置扫掠到新位置，避免高速射弹穿墙。
func _physics_process(delta: float) -> void:
	if _finished:
		return
	age += delta
	if age > (5.0 if hostile else 2.0):
		finish()
		return
	if is_instance_valid(shooter) and kind == "ring":
		global_position = shooter.global_position + Vector2(0, -48)
		_hit_circle(global_position, 76.0, true)
		if age >= 0.6:
			finish()
		queue_redraw()
		return
	# previous 为本步扫掠起点。
	var previous: Vector2 = global_position
	# next_position 为弹道计算出的终点，墙碰撞会裁剪它。
	var next_position: Vector2 = previous + direction * speed * delta
	if kind == "wave":
		next_position += (
			direction.orthogonal() * (sin(age * 18.0) - sin((age - delta) * 18.0)) * 24.0
		)
	if kind == "cutter":
		if age >= 0.6 and not returning:
			_begin_return()
		if returning and is_instance_valid(shooter):
			# destination 是玩家当前手炮高度，返程仍受墙阻挡。
			var destination: Vector2 = shooter.global_position + Vector2(0, -64)
			next_position = previous.move_toward(destination, 650.0 * delta)
			if previous.distance_to(destination) < 24.0:
				finish()
		else:
			next_position = (
				start_position + direction * 500.0 * age + Vector2(0, -sin(age / 0.6 * PI) * 86.0)
			)
	# wall_query 中心线可靠检测薄墙，实体交互仍走统一命中入口。
	var wall_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		previous, next_position, 1
	)
	# wall 保存最近实体与精确命中坐标。
	var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(wall_query)
	if not wall.is_empty():
		next_position = wall["position"]
	# radius 使蓄力/冰刃与画面宽度一致。
	var radius: float = 7.0 + charge_level * 7.0
	if kind == "ice" or kind == "cutter":
		radius = 15.0
	if hostile:
		radius = 12.0 if kind != "ground_wave" else 24.0
	# sweep_shape 覆盖宽弹边缘，不能只靠中心射线检测擦墙。
	var sweep_shape: CircleShape2D = CircleShape2D.new()
	sweep_shape.radius = radius
	# motion_query 使用完整运动向量，薄墙也不会被跳过。
	var motion_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	motion_query.shape = sweep_shape
	motion_query.transform.origin = previous
	motion_query.motion = next_position - previous
	motion_query.collision_mask = 1
	# fractions 分别为安全/碰撞位置比例，由物理引擎扫掠计算。
	var fractions: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(motion_query)
	if fractions[0] < 1.0:
		next_position = previous + motion_query.motion * fractions[0]
		motion_query.transform.origin = (
			previous + motion_query.motion * minf(1.0, fractions[1] + 0.01)
		)
		motion_query.motion = Vector2.ZERO
		# contacts 用于取得擦边命中的交互物实体，纯地形同样阻挡。
		var contacts: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(
			motion_query, 1
		)
		wall = {
			"collider": contacts[0]["collider"] if not contacts.is_empty() else null,
			"position": next_position
		}
	_sweep_targets(previous, next_position, radius)
	if not wall.is_empty() and not _finished:
		# collider 是最近世界实体，破坏物/机关可接收攻击。
		var collider: Object = wall["collider"]
		if (
			is_instance_valid(collider)
			and not hostile
			and collider.has_method("receive_projectile")
		):
			collider.receive_projectile(self)
		if kind == "cutter" and not returning:
			_begin_return()
		else:
			finish()
	global_position = next_position
	# camera_position 仅用于出屏回收，不影响任何命中判定。
	var camera_position: Vector2 = (
		get_viewport().get_camera_2d().get_screen_center_position()
		if get_viewport().get_camera_2d()
		else global_position
	)
	if (
		absf(global_position.x - camera_position.x) > 820.0
		or absf(global_position.y - camera_position.y) > 580.0
	):
		finish()
	queue_redraw()


## from/to 为扫掠线段，radius 为宽弹半径；胶囊覆盖完整路径，不按渲染帧采样。
func _sweep_targets(from: Vector2, to: Vector2, radius: float) -> void:
	# shape 为沿运动方向旋转的胶囊体。
	var shape: CapsuleShape2D = CapsuleShape2D.new()
	shape.radius = radius
	shape.height = from.distance_to(to) + radius * 2.0
	# query 只选对应阵营受击区，不扫描拾取或其他弹体。
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((to - from).angle() - PI / 2.0, (from + to) * 0.5)
	query.collision_mask = 4 if hostile else 72
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# hits 按受击区距离排序，穿透有确定顺序。
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 32)
	hits.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				from.distance_squared_to(a.collider.global_position)
				< from.distance_squared_to(b.collider.global_position)
			)
	)
	# hit 是一份物理受击区交集。
	for hit: Dictionary in hits:
		if _finished:
			break
		# target 为受击区实体，射线防止宽弹半径透过薄墙触及背后目标。
		var target: Node2D = hit["collider"].get_parent()
		# sight 检查从扫掠起点到受击区的无遮挡路径。
		var sight: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			from, hit["collider"].global_position, 1
		)
		# obstacle 是路径上的首个实体，允许交互物命中自身。
		var obstacle: Dictionary = get_world_2d().direct_space_state.intersect_ray(sight)
		if not obstacle.is_empty() and obstacle["collider"] != target:
			continue
		_handle_target(target)


## center/radius 描述火环圆形，occlusion 开启实体墙遮挡检测。
func _hit_circle(center: Vector2, radius: float, occlusion: bool) -> void:
	# shape 为火环实际范围。
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	# query 扫描敌人及可攻击机关。
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform.origin = center
	query.collision_mask = 72
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# hit 是火环附近的一个受击区。
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		# target 为受击区所属对象。
		var target: Node2D = hit["collider"].get_parent()
		# ray 从火环中心指向目标受击区，墙体会先截断。
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			center, hit["collider"].global_position, 1
		)
		if occlusion:
			# wall 是目标前方世界实体；目标自己的实体允许命中。
			var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
			if not wall.is_empty() and wall["collider"] != target:
				continue
		_handle_target(target)


## target 为受击区拥有者；去重先于伤害，装甲反馈先于穿透。
func _handle_target(target: Node) -> void:
	if not is_instance_valid(target) or _hit_ids.has(target.get_instance_id()):
		return
	if hostile:
		if target.has_method("receive_hit"):
			target.receive_hit(damage, global_position)
			finish()
		return
	if not target.has_method("receive_projectile"):
		return
	_hit_ids[target.get_instance_id()] = true
	# result 为目标处理结果：blocked、hit、dead，装甲阻挡立即终止穿透。
	var result: String = target.receive_projectile(self)
	if kind == "ring":
		return
	if result == "blocked":
		if kind == "cutter" and not returning:
			_begin_return()
		else:
			finish()
		return
	if kind == "cutter":
		return
	remaining_hits -= 1
	if remaining_hits <= 0 or target.is_in_group("boss"):
		finish()


## 切刃返程重新允许每个目标命中一次；墙碰撞的返程不能继续穿墙。
func _begin_return() -> void:
	returning = true
	_hit_ids.clear()


## 先关闭结算再延迟删除，避免本物理步多个交集重复处理。
func finish() -> void:
	_finished = true
	queue_free()


## 手绘冰晶、回旋刃与火焰；直射弹保留高可读光晕与短尾迹。
func _draw() -> void:
	if kind=="ring":
		draw_arc(Vector2.ZERO,64,age*8,TAU+age*8,48,Color(1,0.52,0.18,0.55),9,true)
		# index 为围绕真实火环判定绘制的四簇火焰。
		for index: int in range(4):
			draw_set_transform(Vector2.from_angle(age*8+index*PI/2)*64,
				age*8+index*PI/2+PI/2)
			PaintedArt.draw(self,"fire",Rect2(-17,-12,34,24))
		draw_set_transform(Vector2.ZERO)
	elif kind=="ice":
		draw_set_transform(Vector2.ZERO,direction.angle())
		PaintedArt.draw(self,"ice",Rect2(-24,-17,48,34))
		draw_set_transform(Vector2.ZERO)
	elif kind=="cutter":
		draw_set_transform(Vector2.ZERO,age*18)
		PaintedArt.draw(self,"cutter",Rect2(-21,-21,42,42))
		draw_set_transform(Vector2.ZERO)
	elif weapon_id=="contra_f" or kind=="fire":
		draw_set_transform(Vector2.ZERO,direction.angle())
		PaintedArt.draw(self,"fire",Rect2(-19,-13,38,26))
		draw_set_transform(Vector2.ZERO)
	elif kind=="laser":
		draw_line(-direction*25,direction*25,tint,8,true)
		draw_line(-direction*22,direction*22,Color.WHITE,2,true)
	elif kind=="ground_wave":
		draw_arc(Vector2(0,24),24,PI,TAU,24,Color("eb82df"),13,true)
	else:
		# radius 对应现有扫掠判定的主要视觉半径。
		var radius: float = (12 if hostile else 7)+charge_level*7
		draw_line(-direction*radius*2,Vector2.ZERO,Color(tint,0.55),radius,true)
		draw_circle(Vector2.ZERO,radius+5,Color(tint,0.13))
		draw_circle(Vector2.ZERO,radius,tint)
		draw_circle(Vector2(-2,-3),radius*0.55,Color("fff8df"))
