extends Area2D
## 顺序检查点触发器；生命和快照提交由关卡帧末仲裁。

## 玩家进入时报告序号和安全出生点。
signal reached(index: int, spawn: Vector2)
## CP0～CP5 的序号。
@export var index: int = 0
## 当前是否已成为有效检查点。
var active: bool = false
## 动画累计秒数。
var _time: float = 0.0


## 连接玩家进入，场景配置掩码只检测玩家实体。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	active = index <= GameSession.checkpoint_index


## delta 为物理秒数，用于检查点光环轻微动画。
func _physics_process(delta: float) -> void:
	_time += delta
	active = index <= GameSession.checkpoint_index
	queue_redraw()


## body 为进入的角色；重复检查点不会发出提交请求。
func _on_body_entered(body: Node2D) -> void:
	if body is Player and index > GameSession.checkpoint_index:
		reached.emit(index, global_position)


## 绘制旗帜、蘑菇灯和 CP 编号；激活后颜色与形状变化。
func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -146), Color("45666b"), 7, true)
	draw_colored_polygon(
		PackedVector2Array([Vector2(3, -140), Vector2(65, -124), Vector2(3, -106)]),
		Color("86dfb4") if active else Color("f9d483")
	)
	draw_circle(Vector2(0, -150), 12, Color("b3f9df") if active else Color("fff0ba"))
	draw_arc(
		Vector2(0, -60), 50 + sin(_time * 2) * 4, PI, TAU, 32, Color(0.7, 1, 0.8, 0.25), 5, true
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(13, -117),
		"CP%d" % index,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		17,
		Color("25464a")
	)
