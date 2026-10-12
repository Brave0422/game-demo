extends Node2D
## 三层视差环境：天空/洞壁、远景轮廓与近景植被；背景不参与碰撞。

## 已下载草地背景纹理。
const SKY: Texture2D = preload("res://assets/art/environment/grassland/nature/bg/bg.png")
## 近景树木纹理。
const TREE: Texture2D = preload("res://assets/art/environment/grassland/nature/object/tree_2.png")
## 小型草丛纹理。
const BUSH: Texture2D = preload("res://assets/art/environment/grassland/nature/object/bush_2.png")
## 运行时相机中心，用于固定绘制可见范围。
var _center: Vector2 = Vector2(640, 360)
## 与菜单统一的高清蘑菇装饰画笔，避免放大小分辨率素材。
var _decoration: MushroomDecoration = MushroomDecoration.new()


## 每物理步读取相机位置，背景不跟随 UI 或窗口尺寸漂移。
func _physics_process(_delta: float) -> void:
	if get_viewport().get_camera_2d():
		_center = get_viewport().get_camera_2d().get_screen_center_position()
	queue_redraw()


## 按环境绘制视差层，世界 y=576 为地面基准。
func _draw() -> void:
	# left 为相机可见区域左边缘。
	var left: float = _center.x - 700
	# cave 为进入地下城后的背景分支。
	var cave: bool = _center.x >= 21760
	draw_rect(Rect2(left, -500, 1400, 1500), Color("20384c") if cave else Color("b8e2d5"))
	if not cave:
		# repeat_index 覆盖相机前后三段远景贴图，避免接缝露空。
		for repeat_index: int in range(-1, 3):
			# x 为速度 0.12 的远景重复贴图位置。
			var x: float = left - fmod(_center.x * 0.12, 1280) + repeat_index * 1280
			draw_texture_rect(SKY, Rect2(x, -20, 1280, 660), false, Color(0.85, 1, 0.93, 0.78))
	else:
		# column_index 按远景坐标循环摆放石柱，作为洞壁中层。
		for column_index: int in range(-1, 7):
			# x 是视差石柱的可见位置。
			var x: float = left + column_index * 280 - fmod(_center.x * 0.22, 280)
			draw_rect(Rect2(x, 50, 72, 580), Color("294659"))
			draw_arc(Vector2(x + 176, 236), 142, PI, TAU, 32, Color("315063"), 24, true)
			draw_circle(Vector2(x + 35, 274), 13, Color("5e7c97"))
	# index 是固定世界装饰索引，仅绘制可见近景，不生成随机路线。
	for index: int in range(int(left / 360) - 1, int((left + 1400) / 360) + 1):
		# x 为固定世界装饰坐标，避免镜头移动时装饰跳动。
		var x: float = index * 360 + 96
		if cave:
			_decoration.paint(self, Vector2(x + 54, 578), 0.55, Color("817eab"))
			draw_circle(Vector2(x + 54, 476), 40, Color(0.55, 0.54, 0.95, 0.08))
		else:
			if index % 3 == 0:
				draw_texture_rect(TREE, Rect2(x, 206, 258, 370), false, Color(0.8, 0.94, 0.82, 0.7))
			draw_texture_rect(BUSH, Rect2(x + 140, 503, 152, 77), false, Color("aad0a1"))
			_decoration.paint(self, Vector2(x + 62, 578), 0.31, Color("da8d7f"))
