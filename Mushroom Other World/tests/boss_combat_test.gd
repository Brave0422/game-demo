extends Node
## 自动输入 Boss 试玩：只用基础武器、正常 HP 和物理，无伤害/能量作弊。

## 本次实际关卡。
var _level: MushroomWorld
## 各角色独立测试结果。
var _results: Array[Dictionary] = []


## 从 CP5 等效门前位置开始，两角色分别尝试基础武器战斗。
func _ready() -> void:
	# character 是当前测试角色，每次创建全新会话。
	for character: String in ["bill", "mega_man"]:
		GameSession.start_run(character)
		_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
		add_child(_level)
		_level.player.global_position = Vector2(42400, 576)
		_level.player.input_locked = false
		_level.player.health.damaged.connect(
			func(amount: int, origin: Vector2) -> void:
				print(
					"BOT DAMAGE ",
					character,
					" amount=",
					amount,
					" move=",
					_level.boss.move_kind,
					" state=",
					_level.boss.state,
					" player=",
					_level.player.global_position,
					" origin=",
					origin
				)
		)
		await get_tree().physics_frame
		# goal_x 是躲避扑砸后保持的安全横向位置。
		var goal_x: float = 42600
		# elapsed 为本次测试实际模拟物理时间。
		var elapsed: float = 0.0
		# previous_state 检测预警开始，目标只锁定一次。
		var previous_state: String = ""
		# frame_index 为最多240秒的60Hz物理帧序号。
		for frame_index: int in range(14400):
			# player/boss 为真实场景中的战斗参与者。
			var player: Player = _level.player
			# 当前实际 Boss 节点，用于读取公开攻击状态。
			var boss: SporeKing = _level.boss
			if boss.hp <= 0 or player.health.current <= 0:
				break
			elapsed += 1.0 / 60.0
			if boss.state == "telegraph" and previous_state != "telegraph":
				if boss.move_kind == "slam":
					goal_x = boss.locked_x + 270 if boss.locked_x < 42880 else boss.locked_x - 270
				else:
					# 朝预警锁定方向的内侧靠近，利用 Boss 身体无接触伤害的公开规则。
					goal_x = clampf(
						(
							boss.global_position.x
							+ (-65 if player.global_position.x < boss.global_position.x else 65)
						),
						42320,
						43430
					)
			previous_state = boss.state
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(player.global_position.x - goal_x) > 8:
				Input.action_press(
					"move_right" if goal_x > player.global_position.x else "move_left"
				)
			else:
				# 以一帧方向输入转向核心，属于普通可用操作。
				if (boss.global_position.x - player.global_position.x) * player.facing < 0:
					Input.action_press(
						(
							"move_right"
							if boss.global_position.x > player.global_position.x
							else "move_left"
						)
					)
			if not player.is_on_floor() and player.velocity.y > 0:
				Input.action_release("jump")
			# danger 表示已读到明确弹体靠近，正常跳跃躲避。
			var danger: bool = false
			# 逐一读取敌弹位置，转为正常跳跃输入。
			for projectile: Node2D in get_tree().get_nodes_in_group("enemy_projectiles"):
				if (
					absf(projectile.global_position.x - player.global_position.x) < 170
					and projectile.global_position.y > 440
				):
					danger = true
			if player.is_on_floor() and danger:
				Input.action_press("jump")
			if character == "bill":
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
				"player_hp": _level.player.health.current,
				"boss_hp": _level.boss.hp,
				"seconds": snappedf(elapsed, 0.01),
				"mode": "基础武器自动输入；无血量/伤害修改，不代表首次玩家时长"
			}
		)
		# action 为需要跨场景清理的所有保持输入。
		for action: String in ["move_left", "move_right", "shoot", "jump"]:
			Input.action_release(action)
		_level.queue_free()
		await get_tree().process_frame
	# file 保存真实结果，包括失败，不为了通过修改原始测试报告。
	var file: FileAccess = FileAccess.open(
		"res://docs/validation/boss_combat_results.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(_results, "\t"))
	file.close()
	print("BOSS COMBAT: ", JSON.stringify(_results))
	get_tree().quit(
		0 if _results.all(func(result: Dictionary) -> bool: return result["won"]) else 1
	)
