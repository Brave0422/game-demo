extends Node
## 全流程自动输入巡检：正常血量、真实敌人、允许拾取武器和检查点重试。

## 当前完整关卡。
var _level: MushroomWorld
## 两角色完整运行结果。
var _results: Array[Dictionary] = []
## Boss 扑砸后选择的避让横坐标。
var _boss_goal: float = 42600.0
## 上次 Boss 状态，用于锁定一次预警反应。
var _boss_previous: String = ""


## 从菜单等效的新会话入口开始，不跳过地形、机关或战斗。
func _ready() -> void:
	# character 为当前独立测试角色。
	for character: String in ["bill", "mega_man"]:
		GameSession.start_run(character)
		await _load_level()
		# attempts 统计正常死亡重试，不做无敌或血量修改。
		var attempts: int = 0
		# frame_index 允许最多500秒模拟时间，超时保留实际卡点。
		for frame_index: int in range(30000):
			if frame_index % 1200 == 0:
				print(
					"FULL RUN PROGRESS ",
					character,
					" frame=",
					frame_index,
					" x=",
					_level.player.global_position.x,
					" hp=",
					_level.player.health.current,
					" CP",
					GameSession.checkpoint_index
				)
				if frame_index % 6000 == 0:
					# enemy 输出附近未清怪物的状态，便于区分自动控制器卡住与关卡阻塞。
					for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
						if absf(enemy.global_position.x - _level.player.global_position.x) < 700:
							print(
								"NEARBY ",
								enemy.stable_id,
								" ",
								enemy.data.id,
								" ",
								enemy.state,
								" hp=",
								enemy.hp,
								" at=",
								enemy.global_position
							)
			if _level.boss.hp <= 0:
				break
			if _level.ended and _level.player.health.current <= 0:
				attempts += 1
				print(
					"FULL RUN RETRY ",
					character,
					" CP",
					GameSession.checkpoint_index,
					" x=",
					_level.player.global_position.x
				)
				if attempts > 8:
					break
				GameSession.retry_checkpoint(false)
				_level.queue_free()
				await get_tree().process_frame
				await _load_level()
			if _level.boss_active:
				_drive_boss()
			else:
				_drive_route()
			if character == "bill" or _level.player.weapons.equipped != "mega_buster":
				Input.action_press("shoot")
			elif frame_index % 14 == 0:
				Input.action_press("shoot")
			elif frame_index % 14 == 1:
				Input.action_release("shoot")
			await get_tree().physics_frame
			await get_tree().process_frame
		_results.append(
			{
				"character": character,
				"won": _level.boss.hp <= 0,
				"checkpoint": GameSession.checkpoint_index,
				"position": str(_level.player.global_position),
				"hp": _level.player.health.current,
				"boss_hp": _level.boss.hp,
				"deaths": GameSession.deaths,
				"encounters_completed": _level.completed_encounters.keys(),
				"content_seconds": snappedf(GameSession.content_time(), 0.01),
				"total_seconds": snappedf(GameSession.total_time, 0.01),
				"scope": "自动输入完整关卡，非首次真人试玩时长样本"
			}
		)
		_release_input()
		_level.queue_free()
		await get_tree().process_frame
	# file 保存真实全流程结果，失败会保留位置和检查点。
	var file: FileAccess = FileAccess.open(
		"res://docs/validation/full_run_results.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(_results, "\t"))
	file.close()
	print("FULL RUN: ", JSON.stringify(_results))
	get_tree().quit(
		0 if _results.all(func(result: Dictionary) -> bool: return result["won"]) else 1
	)


## 正常重建关卡并应用已有会话快照，松开旧输入再恢复控制。
func _load_level() -> void:
	_release_input()
	_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
	add_child(_level)
	_level.player.input_locked = false
	_boss_previous = ""
	await get_tree().physics_frame
	await get_tree().process_frame


## 以视野内敌人和地形探针选择正常移动/射击/跳跃输入。
func _drive_route() -> void:
	# actor 为角色，所有动作仍交给实际 Player 处理。
	var actor: Player = _level.player
	# target 为附近与角色射击高度相近的敌人。
	var target: Enemy = null
	# arena 表示玩家是否处于锁门遭遇战，可回头追击场内残敌。
	var arena: bool = false
	# active_encounter_id 限制锁门战只追击场内的有限敌人。
	var active_encounter_id: String = ""
	# 逐一检查遭遇战是否已锁门且尚未结束。
	for encounter: Node in _level.get_node("Encounters").get_children():
		arena = arena or (encounter.started and not encounter.finished)
		if encounter.started and not encounter.finished:
			active_encounter_id = encounter.data.id
	# enemy 只依据可见机制选择，不直接修改敌人状态。
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.state == "dead":
			continue
		if arena and not enemy.stable_id.begins_with(active_encounter_id + "/"):
			continue
		# difference 为敌我位置差，用于射程和高度判断。
		var difference: Vector2 = enemy.global_position - actor.global_position
		if not arena and difference.x < -120:
			continue
		if (absf(difference.x) < 580 and absf(difference.y) < 100) or arena:
			if (
				target == null
				or difference.length() < (target.global_position - actor.global_position).length()
			):
				target = enemy
	Input.action_release("move_left")
	Input.action_release("move_right")
	if target == null:
		Input.action_press("move_right")
	else:
		# distance 是与锁定普通怪的水平距离，盾壳需要主动进入预警范围。
		var distance: float = absf(target.global_position.x - actor.global_position.x)
		# desired_range 使基础枪能等待盾壳开壳；其他敌人在中距离处理。
		var desired_range: float = (
			157.0
			if target.data.id == "beetle"
			else (120.0 if arena and target.data.id == "spitter" else 270.0)
		)
		if (
			distance > desired_range
			or (target.global_position.x - actor.global_position.x) * actor.facing < 0
		):
			Input.action_press(
				"move_right" if target.global_position.x > actor.global_position.x else "move_left"
			)
	# 跳坑期间持续向右，不能因为空中进入射程就急停在坑内。
	if not actor.is_on_floor() and not arena:
		Input.action_release("move_left")
		Input.action_press("move_right")
	# floor_ray/wall_ray 是前方地面与台阶检测，不修改正式角色碰撞。
	var floor_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		actor.global_position + Vector2(80, -8), actor.global_position + Vector2(80, 100), 1
	)
	# 胸口高度探针检测悬空障碍。
	var wall_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		actor.global_position + Vector2(0, -65), actor.global_position + Vector2(100, -65), 1
	)
	# foot_ray 检测低矮台阶，胸口探针不能覆盖这部分高度。
	var foot_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		actor.global_position + Vector2(0, -20), actor.global_position + Vector2(100, -20), 1
	)
	# jump_needed 同时考虑短坑、台阶、敌弹与明确近战窗口。
	var jump_needed: bool = (
		actor.get_world_2d().direct_space_state.intersect_ray(floor_ray).is_empty()
		or not actor.get_world_2d().direct_space_state.intersect_ray(wall_ray).is_empty()
		or not actor.get_world_2d().direct_space_state.intersect_ray(foot_ray).is_empty()
	)
	if arena:
		jump_needed = false
	# 逐一读取敌弹位置，避免直接修改战斗状态。
	for projectile: Node2D in get_tree().get_nodes_in_group("enemy_projectiles"):
		if (
			absf(projectile.global_position.x - actor.global_position.x) < 170
			and absf(projectile.global_position.y - actor.global_position.y) < 100
		):
			jump_needed = true
	if target != null and absf(target.global_position.x - actor.global_position.x) < 125:
		jump_needed = jump_needed or target.state == "attack" or target.data.id == "roller"
	# 锁门场内接近喷吐怪后保持水平射击，避免自动脚本与其周期性弹道同频跳跃。
	if arena and target != null and target.data.id == "spitter":
		jump_needed = false
	# pit_cell 是固定地图短坑起点；测试者已知地形，在坑前 60 单位起跳。
	for pit_cell: int in [82, 132, 184, 224, 371, 442, 491, 524]:
		# approach 为距坑左边缘的水平距离，只影响自动输入策略。
		var approach: float = pit_cell * 64.0 - actor.global_position.x
		if approach > 0 and approach < 320 and actor.global_position.y > 560:
			jump_needed = approach < 60
			Input.action_release("move_left")
			Input.action_press("move_right")
	if not actor.is_on_floor() and actor.velocity.y > 0:
		Input.action_release("jump")
	if actor.is_on_floor() and not Input.is_action_pressed("jump") and jump_needed:
		Input.action_press("jump")


## Boss 根据公开预警正常横移，利用无身体接触伤害区域靠近核心。
func _drive_boss() -> void:
	# actor 与 boss 为正常关卡参与者。
	var actor: Player = _level.player
	# 当前实际 Boss 节点，用于读取公开预警。
	var boss: SporeKing = _level.boss
	if boss.state == "telegraph" and _boss_previous != "telegraph":
		if boss.move_kind == "slam":
			_boss_goal = boss.locked_x + 270 if boss.locked_x < 42880 else boss.locked_x - 270
		else:
			_boss_goal = clampf(
				(
					boss.global_position.x
					+ (-65 if actor.global_position.x < boss.global_position.x else 65)
				),
				42320,
				43430
			)
	_boss_previous = boss.state
	Input.action_release("move_left")
	Input.action_release("move_right")
	if absf(actor.global_position.x - _boss_goal) > 8:
		Input.action_press("move_right" if _boss_goal > actor.global_position.x else "move_left")
	elif (boss.global_position.x - actor.global_position.x) * actor.facing < 0:
		Input.action_press(
			"move_right" if boss.global_position.x > actor.global_position.x else "move_left"
		)
	if not actor.is_on_floor() and actor.velocity.y > 0:
		Input.action_release("jump")


## 清除所有测试输入，确保新角色/重试不会继承按键。
func _release_input() -> void:
	# action 为自动控制可能保持的动作。
	for action: String in ["move_left", "move_right", "jump", "shoot"]:
		Input.action_release(action)
