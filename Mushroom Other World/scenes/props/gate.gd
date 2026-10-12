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


## 木质机关门与石制底座沿用手绘材质，关闭宽度对应真实实体。
func _draw() -> void:
	if opened:
		PaintedArt.draw(self,"stone",Rect2(-22,-12,44,12))
		return
	draw_rect(Rect2(-16,-height,32,height),Color("5a3d27"))
	# segment 为木门竖向的固定材质段。
	for segment: int in range(ceili(height/64)):
		PaintedArt.draw(self,"crate",Rect2(-16,-height+segment*64,32,
			minf(64,height-segment*64)))
		draw_rect(Rect2(-20,-height+segment*64+12,40,7),Color("4a382a"))
		draw_circle(Vector2(-12,-height+segment*64+15),2,Color("d1ac71"))
		draw_circle(Vector2(12,-height+segment*64+15),2,Color("d1ac71"))
