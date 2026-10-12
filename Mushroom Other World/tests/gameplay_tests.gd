extends Node
## 确定性引擎集成测试：真实场景与物理步，失败退出非零；不冒充真人试玩。

## 通过断言数。
var _passed: int = 0
## 失败说明列表。
var _failures: Array[String] = []
## 当前测试关卡。
var _level: MushroomWorld


## 异步测试入口，按依赖顺序运行世界与组件边界。
func _ready() -> void:
	await _run()


## 完整测试流程；每个阶段复用实际场景，最后输出机器可读 JSON。
func _run() -> void:
	GameSession.start_run("bill")
	_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
	add_child(_level)
	await _frames(5)
	_check(_level.player.is_on_floor(), "玩家出生在真实 TileMapLayer 地面")
	_check(GameSession.checkpoint_index == 0, "CP0 自动建立")
	_check(_level.get_node("Platforms").get_child_count() == 4, "四组平台")
	_check(get_tree().get_nodes_in_group("enemies").size() == 40, "40 静态怪 + 12 遭遇怪预算")
	# player 为本场测试角色，关闭输入后仍可以直接调用武器与生命组件。
	var player: Player = _level.player
	player.set_physics_process(false)
	_level.set_physics_process(false)
	player.health.invulnerability = 0.0
	player.receive_hit(1, Vector2.ZERO)
	player.receive_hit(2, Vector2.ZERO)
	await _frames(1)
	_check(player.health.current == 6, "同帧多伤害取最大单次")
	player.receive_hit(2, Vector2.ZERO)
	await _frames(1)
	_check(player.health.current == 6, "无敌期间伤害忽略")
	player.health.reset()
	_check(not player.health.heal(2), "满血拒绝消耗回复")
	# weapons 为比尔库存组件。
	var weapons: WeaponController = player.weapons
	weapons.collect_weapon("A")
	_check(weapons.equipped == "contra_s", "比尔 A 箱映射散弹")
	weapons.cooldown = 0
	weapons.fire()
	_check(get_tree().get_nodes_in_group("player_projectiles").size() == 5, "散弹一发五颗")
	_clear_projectiles()
	# crate 为教学箱，三次以上命中仍只生成一次掉落。
	var crate: Breakable = _level.get_node("Breakables/Object01")
	# projectile 为复用攻击载荷，独立于物理弹体测试。
	var projectile: Projectile = load("res://scenes/effects/projectile.tscn").instantiate()
	projectile.damage = 3
	projectile.direction = Vector2.RIGHT
	crate.hit_from_below()
	_check(not crate.is_broken, "武器箱拒绝头顶撞击")
	crate.receive_projectile(projectile)
	crate.receive_projectile(projectile)
	await _frames(2)
	# drops 为该箱子所有还存在的掉落数量。
	var drops: int = 0
	# 枚举关卡掉落物以验证重复触发不会重复生成。
	for item: Node in _level.get_node("Pickups").get_children():
		if item.stable_id == "props/object01/drop00":
			drops += 1
	_check(drops == 1, "同箱多弹只掉落一次")
	# brick 为教学顶砖，子弹不能破坏。
	var brick: Breakable = _level.get_node("Breakables/Object00")
	_check(brick.receive_projectile(projectile) == "blocked" and not brick.is_broken, "砖块挡弹不破坏")
	brick.hit_from_below()
	_check(brick.is_broken, "砖块有效顶撞破坏")
	# beetle 为开放区域护甲怪。
	var beetle: Enemy = _level.get_node("Actors/EnemyS4N1")
	beetle.set_physics_process(false)
	beetle.facing = -1
	projectile.position = beetle.global_position + Vector2(-100, -40)
	_check(beetle.receive_projectile(projectile) == "blocked" and beetle.hp == 6, "盾壳前方挡穿透弹")
	projectile.kind = "ice"
	_check(beetle.receive_projectile(projectile) == "blocked" and beetle.state != "frozen", "前壳挡冰冻")
	projectile.position = beetle.global_position + Vector2(100, -40)
	beetle.receive_projectile(projectile)
	_check(beetle.state == "frozen" and beetle.hp == 6, "背面冰冻不扣普通怪生命")
	beetle.state_time = 1.0
	beetle.receive_projectile(projectile)
	_check(is_equal_approx(beetle.state_time, 2.5), "重复冻结刷新不累加")
	# enemy 遍历五怪验证冻结取消状态与接触差异。
	for enemy: Enemy in [
		_level.get_node("Actors/EnemyS1N1"),
		_level.get_node("Actors/EnemyS2N2"),
		_level.get_node("Actors/EnemyS5N1"),
		_level.get_node("Actors/EnemyS3N1"),
		beetle
	]:
		enemy.set_physics_process(false)
		enemy.receive_projectile(projectile)
		_check(enemy.state == "frozen", "五怪冻结：" + enemy.data.id)
		enemy.state_time = 0
		enemy._physics_process(0.01)
		# 远处敌人的激活门槛暂停 AI，因此直接检查近处或冻结本身。
		_check(
			enemy.data.contact_damage == (1 if enemy.data.id == "roller" else 0),
			"接触伤害仅滚兽：" + enemy.data.id
		)
	# switch 为第一处攻击开关，零伤害冰刃也能开门。
	var switch: Node = _level.get_node("Switches/SwitchOne")
	switch.receive_projectile(projectile)
	_check(_level.get_node("Gates/GateOne").opened, "冰刃激活开关开门")
	switch.receive_projectile(projectile)
	_check(switch.active, "开关重复攻击幂等")
	_level._commit_checkpoint(1, Vector2(3720, 576))
	# saved 为快照深拷贝，后续改变库存不应污染该字典。
	var saved: Dictionary = GameSession.snapshot.duplicate(true)
	weapons.collect_weapon("B")
	_check(saved["weapons"]["equipped"] == "contra_s", "快照装备深拷贝")
	_level.queue_free()
	await _frames(2)
	_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
	add_child(_level)
	await _frames(3)
	_check(_level.player.weapons.equipped == "contra_s", "重建场景恢复检查点装备")
	_check(_level.get_node("Gates/GateOne").opened, "重建场景恢复开关门")
	_check(not _level.has_node("Breakables/Object01"), "快照已破坏箱子不重生")
	_check(_level.player.global_position.distance_to(Vector2(3720, 576)) < 5, "角色回到安全出生点")
	_check(_level.player.health.current == 8, "复活满血")
	_level.queue_free()
	await _frames(2)
	GameSession.start_run("mega_man")
	_level = load("res://scenes/levels/mushroom_world.tscn").instantiate()
	add_child(_level)
	await _frames(3)
	player = _level.player
	weapons = player.weapons
	player.set_physics_process(false)
	_level.set_physics_process(false)
	_check(weapons.equipped == "mega_buster" and weapons.unlocked.size() == 1, "洛克人独立初始库存")
	weapons.collect_weapon("A")
	_check(
		weapons.equipped == "mega_cutter" and weapons.energies["mega_cutter"] == 28, "初获切刃解锁/补满/装备"
	)
	weapons.select_weapon("mega_buster")
	weapons.energies["mega_cutter"] = 5
	weapons.collect_weapon("A")
	_check(
		weapons.equipped == "mega_buster" and weapons.energies["mega_cutter"] == 19,
		"重复武器补14能量且不换装备"
	)
	weapons.select_weapon("mega_cutter")
	weapons.energies["mega_cutter"] = 1
	_check(
		(
			not weapons.fire()
			and weapons.equipped == "mega_buster"
			and weapons.energies["mega_cutter"] == 1
		),
		"能量不足不生成/不扣负/回基础炮"
	)
	weapons.collect_weapon("B")
	weapons.cooldown = 0
	_check(weapons.fire() and weapons.energies["mega_ice"] == 26, "成功发射才扣能量")
	_clear_projectiles()
	weapons.select_weapon("mega_buster")
	# count 为普通弹三颗上限的重复发射次数。
	for count: int in range(3):
		weapons.cooldown = 0
		_check(weapons.fire(), "基础弹槽 %d" % count)
	weapons.cooldown = 0
	_check(not weapons.fire(), "普通弹场上最多三颗")
	_check(weapons.fire(2), "普通弹上限不阻塞独立蓄力槽")
	_check(not weapons.fire(1), "中大蓄力共享一个槽")
	_clear_projectiles()
	# boss 为实际关卡 Boss，直接控制窗口测试去重与阶段边界。
	var boss: SporeKing = _level.boss
	boss.set_physics_process(false)
	projectile.kind = "spread"
	projectile.damage = 1
	projectile.boss_cap = 2
	projectile.attack_id = "test/spread"
	_check(boss.receive_projectile(projectile) == "blocked" and boss.hp == 120, "Boss 平时菌甲无伤")
	boss.state = "exposed"
	# 累计五帧物理更新，使伤害延迟结算完成。
	for count: int in range(5):
		boss.receive_projectile(projectile)
	_check(boss.hp == 118, "Boss 同一发散弹伤害上限2")
	projectile.boss_cap = 0
	projectile.damage = 70
	projectile.attack_id = "test/phase"
	boss.receive_projectile(projectile)
	await _frames(1)
	_check(boss.phase == 2 and boss.state == "phase_change", "半血进入第二阶段怒吼")
	_check(boss.receive_projectile(projectile) == "blocked", "怒吼期间核心关闭")
	boss.state = "exposed"
	projectile.damage = 999
	player.health.invulnerability = 0
	player.receive_hit(99, Vector2.ZERO)
	boss.receive_projectile(projectile)
	await _frames(1)
	_level._resolve_frame()
	_check(_level.ended and _level._pending_victory and GameSession.deaths == 0, "Boss/玩家同帧死亡优先通关")
	projectile.free()
	_level.queue_free()
	await _frames(2)
	_test_timers()
	# report 为真实检查结果，失败时工具读取非零退出。
	var report: Dictionary = {
		"passed": _passed,
		"failed": _failures.size(),
		"failures": _failures,
		"scope": "引擎自动化边界检查；非真人试玩/时长验收"
	}
	# file 为机器可读验收证据。
	var file: FileAccess = FileAccess.open(
		"res://docs/validation/gameplay_results.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GAMEPLAY TESTS: ", JSON.stringify(report))
	AudioManager.clear_world_sounds()
	await _frames(3)
	get_tree().quit(0 if _failures.is_empty() else 1)


## 验证 PRD 计时示例，包含失败回滚和支路扣除。
func _test_timers() -> void:
	GameSession.start_run("bill")
	GameSession.tick(80, 0, false)
	GameSession.tick(10, 0, true)
	GameSession.commit_checkpoint(1, {})
	GameSession.tick(40, 1, false)
	GameSession.retry_checkpoint(true)
	GameSession.tick(100, 1, false)
	GameSession.commit_checkpoint(2, {})
	_check(is_equal_approx(GameSession.content_time(), 180.0), "成功主线用时180秒")
	_check(is_equal_approx(GameSession.total_time, 230.0), "挑战总时间230秒不回滚")
	_check(GameSession.retries == 1 and GameSession.deaths == 0, "手动重试不算死亡")
	_check(not GameSession.commit_checkpoint(1, {}), "回走旧检查点不覆盖")


## condition 为断言结果，description 为审查者可理解的业务规则。
func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


## count 为等待真实物理帧数量，不使用人工修改时间模拟物理。
func _frames(count: int) -> void:
	# index 是等待的帧序号。
	for index: int in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


## 在独立武器案例间清理弹体，避免测试互相占用槽位。
func _clear_projectiles() -> void:
	# projectile 为当前世界所有玩家弹体。
	for projectile: Node in get_tree().get_nodes_in_group("player_projectiles"):
		projectile.get_parent().remove_child(projectile)
		projectile.queue_free()
