class_name MushroomDecoration
extends RefCounted
## 可复用的高清蘑菇装饰画笔，菜单与关卡共用；无碰撞和游戏状态。

## 蘑菇柄的圆角样式，只创建一次避免每帧分配。
var _stem: StyleBoxFlat = StyleBoxFlat.new()
## 蘑菇帽的圆角样式，颜色由调用位置传入。
var _cap: StyleBoxFlat = StyleBoxFlat.new()


## 初始化一致的描边与圆角，便于全局调整装饰画风。
func _init() -> void:
	_stem.bg_color = Color("eed3a0")
	_stem.border_color = Color("37544f")
	_stem.set_border_width_all(5)
	_stem.set_corner_radius_all(26)
	_cap.border_color = Color("37544f")
	_cap.set_border_width_all(6)
	_cap.corner_radius_top_left = 112
	_cap.corner_radius_top_right = 112
	_cap.corner_radius_bottom_left = 25
	_cap.corner_radius_bottom_right = 25


## canvas 为绘制节点，origin 为脚底，比例与帽色控制装饰；结束后还原绘制变换。
func paint(canvas: CanvasItem, origin: Vector2, scale_factor: float, cap_color: Color) -> void:
	canvas.draw_set_transform(origin, -0.08, Vector2.ONE * scale_factor)
	canvas.draw_style_box(_stem, Rect2(-39, -139, 78, 139))
	_cap.bg_color = cap_color
	canvas.draw_style_box(_cap, Rect2(-128, -224, 256, 134))
	canvas.draw_circle(Vector2(-48, -173), 23, Color("ffe9c6"))
	canvas.draw_circle(Vector2(47, -190), 27, Color("ffe9c6"))
	canvas.draw_circle(Vector2(93, -123), 13, Color("ffe9c6"))
	canvas.draw_circle(Vector2(-10, -53), 4, Color("465a4e"))
	canvas.draw_circle(Vector2(15, -53), 4, Color("465a4e"))
	canvas.draw_arc(Vector2(4, -44), 11, 0, PI, 16, Color("987765"), 3, true)
	canvas.draw_set_transform(Vector2.ZERO)
