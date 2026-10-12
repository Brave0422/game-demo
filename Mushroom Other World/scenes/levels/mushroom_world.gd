class_name MushroomWorld
extends Node2D
## 关卡协调层：依赖注入、稳定 ID 注册、快照、计时与终局仲裁。

## 死亡反馈结束后请求主界面显示重试菜单。
signal player_died
## Boss 胜利演出后请求结算。
signal cleared
## 给 HUD 的短文本反馈。
signal hint_requested(message: String)
## 只读关卡静态配置。
@export var data: LevelData
## 当前世界破坏集合。
var broken_ids: Dictionary = {}
## 当前静态敌人死亡集合。
var dead_ids: Dictionary = {}
## 当前已拾取集合。
var collected_ids: Dictionary = {}
## 已完成有限遭遇战集合。
var completed_encounters: Dictionary = {}
## 是否已终止正常可操作计时。
var ended: bool = false
## 是否已开始 Boss 锁屏。
var boss_active: bool = false
## 当前区段下标。
var section: int = 0
## 稳定对象注册表。
var _objects: Dictionary = {}
## 待帧末处理死亡候选。
var _pending_death: bool = false
## 待帧末处理胜利候选。
var _pending_victory: bool = false
## 待帧末提交检查点。
var _pending_checkpoint: int = -1
## 检查点安全出生坐标。
var _pending_spawn: Vector2 = Vector2.ZERO
## 终局反馈延迟秒数，不计入游戏时间。
var _ending_time: float = 0.0
## 已发出终局 UI 信号，防止每帧重复。
var _ending_emitted: bool = false
## 当前环境音乐名。
var _environment: String = ""
## 受伤反馈剩余秒数；视觉震动不改变碰撞与预警世界坐标。
var _shake_time: float = 0.0
## 所选角色，子场景在编辑器中可单独检查。
@onready var player: Player = $Actors/Player
## Boss 独立场景。
@onready var boss: SporeKing = $Actors/SporeKing
## 稳定地面怪和弹体的所属容器。
@onready var actors: Node2D = $Actors
## 关卡独立相机；Boss 战时锁定整个房间。
@onready var camera: Camera2D = $CameraRig


## 在子场景就绪前注入角色配置，确保玩家组件按选择正确初始化。
func _enter_tree() -> void:
	$Actors/Player.data = load("res://resources/characters/%s.tres" % GameSession.character_id)


## 注入依赖并建立稳定 ID 注册，再恢复检查点。
func _ready() -> void:
	process_physics_priority = 1000
	player.died.connect(func() -> void: _pending_death = true)
	player.health.damaged.connect(func(_amount: int, _origin: Vector2) -> void: _shake_time = 0.15)
	player.weapons.hint_requested.connect(
		func(message: String) -> void: hint_requested.emit(message)
	)
	boss.player = player
	boss.defeated.connect(func() -> void: _pending_victory = true)
	# enemy 为静态敌人，每个都在场景中保存稳定 ID。
	for enemy: Node in $Actors.get_children():
		if enemy is Enemy:
			_wire_enemy(enemy)
	# object 为独立可破坏物场景。
	for object: Breakable in $Breakables.get_children():
		_register(object.stable_id, object)
		object.broken.connect(_on_broken)
	# pickup 为地图预置补给。
	for pickup: Pickup in $Pickups.get_children():
		_wire_pickup(pickup)
	# checkpoint 为 CP0～CP5 场景。
	for checkpoint: Area2D in $Checkpoints.get_children():
		checkpoint.reached.connect(_request_checkpoint)
	# gate 为机关门和 Boss 入口门。
	for gate: Gate in $Gates.get_children():
		_register(gate.stable_id, gate)
	# switch 为攻击开关。
	for switch: Node2D in $Switches.get_children():
		_register(switch.stable_id, switch)
		switch.activated.connect(_on_switch)
	# encounter 为有限遭遇战控制器。
	for encounter: Node2D in $Encounters.get_children():
		_register(encounter.data.id, encounter)
		encounter.player = player
		encounter.level = self
		encounter.completed.connect(_on_encounter_completed)
	if not GameSession.snapshot.is_empty():
		_restore(GameSession.snapshot)
	else:
		_commit_checkpoint(0, player.global_position)
	camera.global_position = Vector2(
		clampf(player.global_position.x + 160, 640, data.width - 640), 360
	)
	camera.reset_smoothing()
	_update_environment()


## delta 为物理秒数；最后运行以便帧末统一判定胜利、死亡和检查点。
func _physics_process(delta: float) -> void:
	if ended:
		_ending_time -= delta
		if _ending_time <= 0 and not _ending_emitted:
			_ending_emitted = true
			if _pending_victory:
				cleared.emit()
			else:
				player_died.emit()
		return
	section = 0
	# index 是八个区段边界的顺序索引。
	for index: int in range(data.section_starts.size()):
		if player.global_position.x >= data.section_starts[index]:
			section = index
	# branch 为两条可选上层支路，成功用时中单独扣除。
	var branch: bool = (
		(
			player.global_position.x > 6300 and player.global_position.x < 7550
			or player.global_position.x > 25800 and player.global_position.x < 27400
		)
		and player.global_position.y < 355
	)
	GameSession.tick(delta, section, branch)
	if not boss_active and player.global_position.x >= 42360:
		boss_active = true
		$Gates/BossEntrance.set_open(false)
		camera.global_position = Vector2(42880, 360)
		camera.reset_smoothing()
		boss.begin()
		hint_requested.emit("孢子大王 · 避开预警，攻击发光腹部")
	if boss_active:
		camera.global_position = Vector2(42880, 360)
	else:
		camera.global_position = Vector2(
			clampf(player.global_position.x + player.facing * 160, 640, data.width - 640), 360
		)
		# encounter 为已触发的竞技场，锁住镜头以保证所有生成点都可见。
		for encounter: Node2D in $Encounters.get_children():
			if encounter.started and not encounter.finished:
				camera.global_position = Vector2(encounter.global_position.x + 640, 360)
	_shake_time = maxf(0.0, _shake_time - delta)
	camera.offset = (
		Vector2(sin(_shake_time * 150) * 4, cos(_shake_time * 170) * 2)
		if _shake_time > 0 and SaveService.settings["shake"]
		else Vector2.ZERO
	)
	_update_environment()
	_resolve_frame.call_deferred()


## 帧末仲裁：胜利优先于同时死亡，死亡优先于检查点补血。
func _resolve_frame() -> void:
	if ended:
		return
	if _pending_victory:
		ended = true
		_ending_time = 2.0
		player.set_physics_process(false)
		player.weapons.cancel_charge()
		SaveService.record_clear(GameSession.character_id, GameSession.total_time)
		AudioManager.change_music("victory")
		_free_projectiles()
		_stop_enemies()
	elif _pending_death or player.health.current <= 0:
		_pending_death = true
		ended = true
		_ending_time = 0.8
		GameSession.deaths += 1
		AudioManager.play_sfx("death", player.global_position)
		_free_projectiles()
		_stop_enemies()
	elif _pending_checkpoint > GameSession.checkpoint_index:
		_commit_checkpoint(_pending_checkpoint, _pending_spawn)
	_pending_checkpoint = -1


## index/spawn 由检查点触发器提供；这里只记录，不立即补血。
func _request_checkpoint(index: int, spawn: Vector2) -> void:
	if index > _pending_checkpoint:
		_pending_checkpoint = index
		_pending_spawn = spawn


## index 为新检查点，spawn 为安全脚底坐标；捕获未拾取掉落避免永久丢失。
func _commit_checkpoint(index: int, spawn: Vector2) -> void:
	if index <= GameSession.checkpoint_index:
		return
	player.health.reset(0.0 if index > 0 else 1.5)
	# pending 保存所有当前还在场内的道具，包括地图预置与箱子掉落。
	var pending: Array[Dictionary] = []
	# pickup 是当前关卡道具，已排队删除的不会进入快照。
	for pickup: Node in $Pickups.get_children():
		if not pickup.is_queued_for_deletion():
			pending.append(pickup.capture())
	# switches 为开关状态字典。
	var switches: Dictionary = {}
	# switch 为配置中的开关实例。
	for switch: Node in $Switches.get_children():
		switches[switch.stable_id] = switch.active
	# gates 为普通机关门状态，Boss 重试须重新开放。
	var gates: Dictionary = {}
	# gate 为可恢复的普通门。
	for gate: Gate in $Gates.get_children():
		gates[gate.stable_id] = gate.opened
	GameSession.commit_checkpoint(
		index,
		{
			"spawn": spawn,
			"weapons": player.weapons.capture(),
			"broken": broken_ids.duplicate(),
			"dead": dead_ids.duplicate(),
			"collected": collected_ids.duplicate(),
			"pickups": pending,
			"switches": switches,
			"gates": gates,
			"encounters": completed_encounters.duplicate()
		}
	)
	if index > 0:
		hint_requested.emit("CP%d 已激活 · 生命恢复 · 当前装备已保存" % index)
		AudioManager.play_sfx("checkpoint", spawn)


## state 为会话快照；先恢复静态对象，再重建掉落和角色，最后恢复音乐。
func _restore(state: Dictionary) -> void:
	broken_ids = state["broken"].duplicate()
	dead_ids = state["dead"].duplicate()
	collected_ids = state["collected"].duplicate()
	completed_encounters = state["encounters"].duplicate()
	# id 是应从初始场景移除的稳定对象。
	for id: String in broken_ids.keys() + dead_ids.keys():
		if _objects.has(id) and is_instance_valid(_objects[id]):
			_remove_object(_objects[id])
	# pickup 先清除地图初始道具，再按快照完整重建，防止重复。
	for pickup: Node in $Pickups.get_children():
		_remove_object(pickup)
	# record 保存一个待拾取物的纯值数据。
	for record: Dictionary in state["pickups"]:
		_spawn_pickup(record["id"], record["kind"], record["position"], record["safe"])
	# id 为开关或门稳定标识。
	for id: String in state["switches"]:
		_objects[id].active = state["switches"][id]
		_objects[id].queue_redraw()
	# id 为普通门的稳定标识。
	for id: String in state["gates"]:
		_objects[id].set_open(state["gates"][id])
	# id 为已完成遭遇战；重新进入不再刷怪。
	for id: String in completed_encounters:
		_objects[id].finished = true
		_objects[id].entrance.set_open(true)
		_objects[id].exit_gate.set_open(true)
	player.global_position = state["spawn"]
	player.velocity = Vector2.ZERO
	player.health.reset()
	player.weapons.restore(state["weapons"])
	$Gates/BossEntrance.set_open(true)


## object 立即退出场景树再排队删除，避免恢复时产生一帧旧对象交互。
func _remove_object(object: Node) -> void:
	object.get_parent().remove_child(object)
	object.queue_free()


## id 为稳定标识；拒绝重复 ID 并报告具体冲突。
func _register(id: String, object: Node) -> void:
	assert(not id.is_empty(), "对象缺少稳定 ID: %s" % object.name)
	assert(not _objects.has(id), "重复稳定 ID: %s" % id)
	_objects[id] = object


## enemy 为待连接独立实例，静态和遭遇战生成均走同一入口。
func _wire_enemy(enemy: Enemy) -> void:
	_register(enemy.stable_id, enemy)
	enemy.player = player
	enemy.defeated.connect(_on_enemy_defeated)


## type 为资源名、point 为脚底坐标、id 为稳定实例 ID、radius 为巡逻半径。
func spawn_enemy(type: String, point: Vector2, id: String, radius: float) -> Enemy:
	# enemy 是本批新实例，设计资源只读共享。
	var enemy: Enemy = preload("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.data = load("res://resources/enemies/%s.tres" % type)
	enemy.stable_id = id
	enemy.position = point
	enemy.patrol_radius = radius
	actors.add_child(enemy)
	_wire_enemy(enemy)
	return enemy


## id 为死亡敌人；只保存静态死亡，未完成遭遇战重试必须从第一批重新开始。
func _on_enemy_defeated(id: String) -> void:
	if not id.begins_with("e1/") and not id.begins_with("e2/"):
		dead_ids[id] = true


## id/drop/point 描述刚被破坏的物体；掉落稳定 ID 由来源派生。
func _on_broken(id: String, drop: String, point: Vector2) -> void:
	if broken_ids.has(id):
		return
	broken_ids[id] = true
	if not drop.is_empty():
		# safe 为附近固定地面高度，掉落从可接触位置出现且不会落入坑。
		var safe: Vector2 = Vector2(point.x, 540)
		_spawn_pickup.call_deferred(id + "/drop00", drop, safe, safe)


## id 为唯一掉落 ID，kind 为内容，point/safe 分别为当前位置和安全落点。
func _spawn_pickup(id: String, kind: String, point: Vector2, safe: Vector2) -> void:
	# pickup 为独立拾取实例，不复用共享运行状态。
	var pickup: Pickup = preload("res://scenes/props/pickup.tscn").instantiate()
	pickup.stable_id = id
	pickup.kind = kind
	pickup.position = point
	$Pickups.add_child(pickup)
	pickup.safe_position = safe
	_wire_pickup(pickup)


## pickup 注入当前玩家与拾取事件接收器。
func _wire_pickup(pickup: Pickup) -> void:
	pickup.player = player
	pickup.collected.connect(_on_collected)


## id/message 来自成功产生效果的道具；记录后只显示一次提示。
func _on_collected(id: String, message: String) -> void:
	collected_ids[id] = true
	hint_requested.emit(message)


## stable_id 为来源开关、gate_id 为目标门；门状态在快照时读取。
func _on_switch(_stable_id: String, gate_id: String) -> void:
	assert(_objects.has(gate_id), "缺少开关目标门: " + gate_id)
	_objects[gate_id].set_open(true)
	hint_requested.emit("通路已打开")


## id 为完整清完的遭遇战，保存一次完成标志。
func _on_encounter_completed(id: String) -> void:
	completed_encounters[id] = true
	hint_requested.emit("遭遇战完成 · 前方通路已打开")


## 根据实际角色位置选择草地/地下/Boss 音乐。
func _update_environment() -> void:
	# environment 是当前所需环境状态。
	var environment: String = (
		"boss" if boss_active else ("dungeon" if player.global_position.x >= 21760 else "grassland")
	)
	if environment != _environment:
		_environment = environment
		AudioManager.change_music(environment)


## 终局清理所有弹体，避免胜利后再次伤人。
func _free_projectiles() -> void:
	# projectile 为两阵营所有存活弹体。
	for projectile: Node in (
		get_tree().get_nodes_in_group("enemy_projectiles")
		+ get_tree().get_nodes_in_group("player_projectiles")
	):
		projectile.finish()


## 终局立即停用所有敌人 AI，死亡反馈时间内不再继续生成弹体。
func _stop_enemies() -> void:
	# enemy 为本关当前所有普通怪和 Boss。
	for enemy: Node in (
		get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss")
	):
		enemy.set_physics_process(false)
