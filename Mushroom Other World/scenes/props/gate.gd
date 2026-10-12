class_name Gate
extends StaticBody2D
## 开关门、遭遇战门和 Boss 门的共用实体；只由控制器切换。

## 快照使用的稳定门 ID。
@export var stable_id: String = ""
## 初始开启状态。
@export var opened: bool = false
## 门高，普通机关与竞技场边界可分别配置。
@export var height: float = 256.0


## 根据配置建立唯一碰撞形状并应用初始状态。
func _ready() -> void:
	add_to_group("gates")
	$BodyShape.shape = $BodyShape.shape.duplicate()
	$BodyShape.shape.size = Vector2(32, height)
	$BodyShape.position.y = -height * 0.5
	set_open(opened)


## value 为目标门状态，使用延迟碰撞更新适配物理回调。
func set_open(value: bool) -> void:
	opened = value
	$BodyShape.set_deferred("disabled", opened)
	queue_redraw()


## 门打开后只留拱柱底座，关闭时绘制可读竖向格栅。
func _draw() -> void:
	if opened:
		draw_rect(Rect2(-22, -12, 44, 12), Color("759d99"))
		return
	draw_rect(Rect2(-20, -height, 40, height), Color("35485e"))
	# bar_index 是机关门的横向装饰扣，间距固定。
	for bar_index: int in range(int(height / 48)):
		draw_rect(Rect2(-24, -height + bar_index * 48 + 12, 48, 12), Color("99c9ca"))
