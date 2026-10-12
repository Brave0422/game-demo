extends Node2D
## 攻击开关：接受所有玩家武器，包括零普通伤害的冰刃。

## 激活后由关卡把对应门打开。
signal activated(stable_id: String, gate_id: String)
## 检查点保存的开关 ID。
@export var stable_id: String = ""
## 对应门稳定 ID。
@export var gate_id: String = ""
## 门相对于开关的位置，用于绘制连接线。
@export var gate_offset: Vector2 = Vector2(260, 0)
## 一次性激活标志。
var active: bool = false


## 注册机关，供关卡捕获恢复状态。
func _ready() -> void:
	add_to_group("switches")


## projectile 是玩家攻击；不依赖伤害数值，冰冻波同样生效。
func receive_projectile(_projectile: Projectile) -> String:
	if not active:
		active = true
		activated.emit(stable_id, gate_id)
		AudioManager.play_sfx("checkpoint", global_position)
		queue_redraw()
	return "blocked"


## 连线与箭头指明对应门；触发后按钮由菱形改为亮圆形。
func _draw() -> void:
	draw_polyline(
		PackedVector2Array(
			[Vector2.ZERO, Vector2(0, 48), gate_offset + Vector2(0, 48), gate_offset]
		),
		Color("7ecaba") if active else Color("687d8e"),
		4,
		true
	)
	draw_circle(Vector2.ZERO, 30, Color("314c5d"))
	if active:
		draw_circle(Vector2.ZERO, 21, Color("92f0c9"))
	else:
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, -24), Vector2(24, 0), Vector2(0, 24), Vector2(-24, 0)]),
			Color("ffd681")
		)
