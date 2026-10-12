extends Node2D
## 两批有限遭遇战；只有真实死亡推进批次，冻结不算完成。

## 全部六只死亡后报告完成 ID。
signal completed(stable_id: String)
## 静态敌种与场地宽度。
@export var data: EncounterData
## 父关卡注入玩家。
var player: Player
## 生成敌人的关卡实例，由父节点注入。
var level: Node2D
## 是否已触发。
var started: bool = false
## 是否已完成，快照恢复后保持开门。
var finished: bool = false
## 当前批次 0/1。
var wave: int = 0
## 活着的动态敌人稳定 ID 集合。
var _alive: Dictionary = {}
## 波次生成预警剩余秒数。
var _warning: float = -1.0
## 当前生成预警点。
var _spawn_positions: Array[Vector2] = []
## 左右入口门由场景组合提供。
@onready var entrance: Gate = $Entrance
## 出口门直到清完第二批才开启。
@onready var exit_gate: Gate = $Exit


## delta 为物理秒数；玩家完全进入后锁门，下一批生成前预警 0.8 秒。
func _physics_process(delta: float) -> void:
	if finished or not is_instance_valid(player):
		return
	if (
		not started
		and player.global_position.x > global_position.x + 110
		and player.global_position.x < global_position.x + data.width - 110
	):
		started = true
		entrance.set_open(false)
		exit_gate.set_open(false)
		_prepare_wave()
	if _warning >= 0.0:
		_warning -= delta
		if _warning < 0.0:
			_spawn_wave()
	queue_redraw()


## 挑选可见且距玩家至少 256 的预警点；备用点同样在无坑竞技场内。
func _prepare_wave() -> void:
	_warning = 0.8
	_spawn_positions.clear()
	# offset 为候选点，相邻候选至少 144，生成时再次验证玩家安全距离。
	for offset: float in [128.0, 256.0, 384.0, 512.0, 640.0, 768.0, 896.0, 1024.0, 1152.0]:
		# point 为候选世界坐标。
		var point: Vector2 = global_position + Vector2(offset, 0)
		if absf(point.x - player.global_position.x) >= 256:
			_spawn_positions.append(point)
		if _spawn_positions.size() == 3:
			break
	AudioManager.play_sfx("warning", global_position)


## 生成恰好三只；玩家走进预警点时重新预警，绝不贴身刷怪。
func _spawn_wave() -> void:
	if _spawn_positions.size() < 3:
		_prepare_wave()
		return
	# point 为上一轮已显示的生成点；生成前必须重新确认安全。
	for point: Vector2 in _spawn_positions:
		if absf(point.x - player.global_position.x) < 256:
			_prepare_wave()
			return
	# types 为当前批次敌种配置。
	var types: PackedStringArray = data.first_wave if wave == 0 else data.second_wave
	# index 为批次内固定序号，形成可复现 ID。
	for index: int in range(types.size()):
		# id 不依赖运行时节点序号或实例地址。
		var id: String = "%s/wave%d/enemy%d" % [data.id, wave, index]
		# point 是该敌人的落点，蝙蝠初始悬空。
		var point: Vector2 = _spawn_positions[index]
		if types[index] == "bat":
			point.y -= 190
		# enemy 为关卡工厂创建并注入依赖的独立场景。
		var enemy: Enemy = level.spawn_enemy(types[index], point, id, 120.0)
		enemy.defeated.connect(_on_enemy_defeated)
		_alive[id] = true
	_spawn_positions.clear()


## id 为真实死亡实例；当前批全部死亡后才推进。
func _on_enemy_defeated(id: String) -> void:
	_alive.erase(id)
	if not _alive.is_empty():
		return
	if wave == 0:
		wave = 1
		_prepare_wave()
	else:
		finished = true
		entrance.set_open(true)
		exit_gate.set_open(true)
		completed.emit(data.id)


## 绘制生成点的竖向预警形状，不仅依靠颜色。
func _draw() -> void:
	# point 为当前已选定的世界空间生成位置。
	for point: Vector2 in _spawn_positions:
		draw_arc(point - global_position, 34, PI, TAU, 24, Color("ffd382"), 5, true)
		draw_line(
			point - global_position + Vector2(0, -70),
			point - global_position + Vector2(0, -18),
			Color("ffe7b4"),
			5,
			true
		)
