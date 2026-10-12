extends Node
## 输入与实际物理回归：跳跃、趴下、薄墙、平台、遭遇战和两角色主线路线。

## 本次通过数。
var _passed: int = 0
## 失败说明。
var _failures: Array[String] = []
## 本次实际关卡。
var _level: MushroomWorld


## 按固定步执行可重复场景，最终写入证据并返回退出码。
func _ready() -> void:
	await _run()


## 测试套件主流程；每种行为都操作真实节点和物理空间。
func _run() -> void:
	GameSession.start_run("bill")
	_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
	add_child(_level)
	await _frames(4)
	_level.set_physics_process(false)
	# enemy 暂停 AI，使移动测试只验证地形而不混入战斗难度。
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	# player 为当前共用移动控制器实例。
	var player: Player = _level.player
	player.input_locked = false
	Input.action_press("move_left")
	Input.action_press("move_right")
	await _frames(12)
	_check(absf(player.velocity.x) < 1, "同时按左右速度为零")
	_release_input()
	Input.action_press("move_right")
	await _frames(36)
	_check(player.global_position.x > 320, "加速达到水平320并前进")
	_release_input()
	player.global_position = Vector2(180, 576)
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press("jump")
	# minimum_y 为完整跳跃中脚底最高位置。
	var minimum_y: float = 576
	# 采样六十帧长按跳跃轨迹。
	for frame_index: int in range(60):
		await _frames(1)
		minimum_y = minf(minimum_y, player.global_position.y)
	Input.action_release("jump")
	_check(minimum_y > 380 and minimum_y < 410, "完整跳跃高度约187")
	await _frames(15)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	minimum_y = 576
	# 采样五十五帧短按跳跃轨迹。
	for frame_index: int in range(55):
		await _frames(1)
		minimum_y = minf(minimum_y, player.global_position.y)
	_check(minimum_y > 475, "松开跳跃显著降低跳高")
	Input.action_press("move_down")
	await _frames(3)
	_check(player.crouched and player.body_shape.shape.size.y == 36, "比尔地面趴下体积")
	# roof 为站起体积测试的低顶实体，不参与正式关卡。
	var roof: StaticBody2D = _wall(Vector2(180, 516), Vector2(160, 16))
	Input.action_release("move_down")
	await _frames(4)
	_check(player.crouched, "低顶阻挡站起")
	roof.queue_free()
	await _frames(4)
	_check(not player.crouched, "低顶移除后可站起")
	player.global_position = Vector2(5100, 576)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await _frames(15)
	Input.action_press("jump")
	await _frames(53)
	_release_input()
	_check(player.global_position.x > 5440 and player.global_position.y < 600, "真实物理跨越192宽短坑")
	await _frames(15)
	# platform 为第一组水平平台，验证乘客自动随动。
	var platform: AnimatableBody2D = _level.get_node("Platforms/Platform1")
	player.global_position = platform.global_position + Vector2(0, -3)
	player.velocity = Vector2.ZERO
	await _frames(5)
	# initial_offset 是搭乘开始时的相对横向距离。
	var initial_offset: float = player.global_position.x - platform.global_position.x
	await _frames(45)
	_check(
		absf(player.global_position.x - platform.global_position.x - initial_offset) < 10,
		"水平平台实际搭乘不滑落"
	)
	get_tree().paused = true
	# paused_position 是暂停瞬间平台世界坐标。
	var paused_position: Vector2 = platform.global_position
	await get_tree().create_timer(0.05, true).timeout
	_check(platform.global_position == paused_position, "暂停冻结平台位置")
	get_tree().paused = false
	player.global_position = Vector2(180, 576)
	player.velocity = Vector2.ZERO
	await _frames(3)
	# wall 为 2 单位薄墙，用来捕获高速激光穿墙回归。
	var wall: StaticBody2D = _wall(Vector2(400, 512), Vector2(2, 180))
	# target 为墙后的真实敌人，禁用 AI 防止离开验证位置。
	var target: Enemy = _level.spawn_enemy("patrol", Vector2(470, 576), "test/thin_wall_target", 0)
	target.set_physics_process(false)
	player.weapons.collect_weapon("B")
	player.facing = 1
	player.weapons.cooldown = 0
	player.weapons.fire()
	await _frames(30)
	_check(target.hp == 3, "1200速度激光不能穿2单位薄墙")
	wall.queue_free()
	await _frames(2)
	player.weapons.cooldown = 0
	player.weapons.fire()
	await _frames(30)
	_check(not is_instance_valid(target) or target.hp <= 0, "移除墙后激光扫掠可命中真实敌人")
	# encounter 为真实 E1，选择中央站位覆盖候选点不足的回归。
	var encounter: Node2D = _level.get_node("Encounters/EncounterOne")
	player.global_position = encounter.global_position + Vector2(640, 0)
	player.velocity = Vector2.ZERO
	await _frames(60)
	_check(encounter._alive.size() == 3, "中央站位仍安全生成恰好三只")
	# enemy 是该批真实敌人，距离要求以初始 home 验证。
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.stable_id.begins_with("e1/wave0"):
			_check(absf(enemy.home.x - player.global_position.x) >= 256, "遭遇战生成距玩家至少256")
			enemy.state = "frozen"
			enemy.state_time = 2.5
	_check(not encounter.finished and not encounter.exit_gate.opened, "冻结末敌不结束遭遇战")
	# 逐一击杀第一批敌人，推动下一批刷新。
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.stable_id.begins_with("e1/wave0"):
			enemy._die()
	await _frames(60)
	_check(encounter.wave == 1 and encounter._alive.size() == 3, "第二批仍恰好三只")
	# 逐一击杀第二批敌人，验证出口开门。
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.stable_id.begins_with("e1/wave1"):
			enemy._die()
	await _frames(2)
	_check(encounter.finished and encounter.exit_gate.opened, "清完六只立即开门")
	_level.queue_free()
	await _frames(3)
	await _test_charge_inputs()
	await _test_routes()
	# report 保存成功项、失败项与测试范围说明。
	var report: Dictionary = {
		"passed": _passed,
		"failed": _failures.size(),
		"failures": _failures,
		"scope": "真实物理输入与路线可达性；路线测试停用敌人AI，不是基础武器战斗通关证明"
	}
	# file 是版本化的测试证据文件。
	var file: FileAccess = FileAccess.open(
		"res://docs/validation/physics_results.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PHYSICS TESTS: ", JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)


## 使用真实按键保持与松开，验证蓄力级别和暂停中释放不补发。
func _test_charge_inputs() -> void:
	GameSession.start_run("mega_man")
	_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
	add_child(_level)
	await _frames(4)
	_level.set_physics_process(false)
	_level.player.input_locked = false
	Input.action_press("shoot")
	await _frames(30)
	Input.action_release("shoot")
	await _frames(2)
	_check(_has_charge(1), "真实J按住0.5秒松手生成中弹")
	await _frames(120)
	Input.action_press("shoot")
	await _frames(72)
	Input.action_release("shoot")
	await _frames(2)
	_check(_has_charge(2), "真实J按住1.2秒松手生成大弹")
	_level.queue_free()
	await _frames(3)


## level 为需要查找的弹体蓄力等级，返回场上是否存在对应弹体。
func _has_charge(level: int) -> bool:
	# projectile 为当前玩家存活弹体。
	for projectile: Node in get_tree().get_nodes_in_group("player_projectiles"):
		if projectile.charge_level == level:
			return true
	return false


## 两角色穿越固定主线地形；停用战斗且开门，单独验证移动可达性。
func _test_routes() -> void:
	# character 为两种角色的共用路线案例。
	for character: String in ["bill", "mega_man"]:
		GameSession.start_run(character)
		_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
		add_child(_level)
		await _frames(4)
		_level.set_physics_process(false)
		# child 是会阻挡自动路线验证的战斗/交互节点，测试中独立关闭。
		for child: Node in _level.get_node("Actors").get_children():
			if child != _level.player:
				child.set_physics_process(false)
		# 逐一移除机关门，使本项仅验证地形通行。
		for child: Node in _level.get_node("Gates").get_children():
			child.set_open(true)
		# 逐一移除遭遇战触发器，使本项仅验证地形通行。
		for child: Node in _level.get_node("Encounters").get_children():
			child.finished = true
		# 逐一移除可破坏物，使本项仅验证地形通行。
		for child: Node in _level.get_node("Breakables").get_children():
			child.queue_free()
		_level.player.input_locked = false
		# frame_index 以固定60Hz走完整个路线，最多200秒模拟时间。
		for frame_index: int in range(12000):
			# actor 为当前测试玩家。
			var actor: Player = _level.player
			if actor.global_position.x > 43200 or actor.health.current <= 0:
				break
			Input.action_press("move_right")
			# floor_ray 检查前方120处落脚地面，近坑前起跳。
			var floor_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				actor.global_position + Vector2(112, -8),
				actor.global_position + Vector2(112, 100),
				1
			)
			# wall_ray 检查当前脚前的台阶侧面。
			var wall_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				actor.global_position + Vector2(0, -20),
				actor.global_position + Vector2(100, -20),
				1
			)
			if not actor.is_on_floor() and actor.velocity.y > 0:
				Input.action_release("jump")
			if actor.is_on_floor() and not Input.is_action_pressed("jump"):
				if (
					actor.get_world_2d().direct_space_state.intersect_ray(floor_ray).is_empty()
					or not (
						actor.get_world_2d().direct_space_state.intersect_ray(wall_ray).is_empty()
					)
				):
					Input.action_press("jump")
			await _frames(1)
		_check(
			_level.player.global_position.x > 43200,
			(
				"%s 固定主线路线可达：x=%.0f y=%.0f"
				% [character, _level.player.global_position.x, _level.player.global_position.y]
			)
		)
		_release_input()
		_level.queue_free()
		await _frames(3)


## position/size 为测试实体的世界中心与尺寸，返回可释放的 StaticBody2D。
func _wall(position: Vector2, size: Vector2) -> StaticBody2D:
	# body 为只属于测试场景的世界实体。
	var body: StaticBody2D = StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	# shape 为实际矩形体积。
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	# collision 为实体物理节点。
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


## count 为真实物理帧数量，使用 fixed-fps 运行可加速但不改变步长。
func _frames(count: int) -> void:
	# index 为等待帧序号。
	for index: int in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


## 释放测试注入的全部动作，避免跨案例输入残留。
func _release_input() -> void:
	# action 是测试中可能保持的玩家输入动作。
	for action: String in ["move_left", "move_right", "move_down", "jump", "shoot"]:
		Input.action_release(action)


## condition 为断言，message 为中文业务说明。
func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)
