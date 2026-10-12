extends AnimatableBody2D
## 物理步往返平台，端点停留；顶部受阻时停止，避免把乘客夹入天花板。

## 单程位移，水平或竖向。
@export var travel: Vector2 = Vector2(224, 0)
## 匀速移动速度，单位/秒。
@export var speed: float = 80.0
## 当前端点停留秒数。
var _wait: float = 0.3
## 场景配置起点。
var _origin: Vector2 = Vector2.ZERO
## 是否正在前往终点。
var _forward: bool = true


## 记录配置起点；快照重建场景后自然复位。
func _ready() -> void:
	_origin = position


## delta 为物理步长，test_move 检查平台前方实体障碍。
func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	# target 是本次往返终点。
	var target: Vector2 = _origin + travel if _forward else _origin
	# movement 为该物理步的实际位移。
	var movement: Vector2 = position.move_toward(target, speed * delta) - position
	if test_move(global_transform, movement):
		return
	# rider 检查搭乘者头顶是否会撞世界，防止竖直平台夹压。
	for rider: Node in get_tree().get_nodes_in_group("player"):
		if (
			movement.y < 0
			and absf(rider.global_position.x - global_position.x) < 100
			and absf(rider.global_position.y - global_position.y) < 10
		):
			if rider.test_move(rider.global_transform, movement):
				return
	position += movement
	if position.distance_to(target) < 0.1:
		_forward = not _forward
		_wait = 0.3


## 清晰站立面与方向轨道，轨道不参与碰撞。
func _draw() -> void:
	draw_rect(Rect2(-88, 0, 176, 22), Color("385868"))
	draw_rect(Rect2(-88, 0, 176, 7), Color("a0d9c3"))
	draw_line(Vector2(-60, 15), Vector2(60, 15), Color("edc988"), 4, true)
