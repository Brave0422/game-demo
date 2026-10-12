extends Control
## 主菜单原创非像素装饰画，复用已下载植被并保持前景文字留白。

## 草地远景纹理。
const SKY: Texture2D = preload("res://assets/art/environment/grassland/nature/bg/bg.png")
## 树木纹理。
const TREE: Texture2D = preload("res://assets/art/environment/grassland/nature/object/tree_2.png")
## 菌盖动画时钟。
var _time: float = 0.0
## 与关卡共用的高清蘑菇装饰画笔。
var _decoration: MushroomDecoration = MushroomDecoration.new()


## delta 为 UI 秒数，主菜单轻微漂浮装饰。
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## 三层草地环境与右侧巨型蘑菇，左侧保留菜单文字空间。
func _draw() -> void:
	draw_texture_rect(SKY, Rect2(Vector2.ZERO, size), false, Color("85bfb4"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.19, 0.23, 0.5))
	draw_circle(Vector2(1130, 145), 98, Color(1.0, 0.89, 0.61, 0.22))
	draw_texture_rect(TREE, Rect2(927, 272, 280, 400), false, Color("b9dcb8"))
	draw_circle(Vector2(1050, 1125), 520, Color("496f68"))
	draw_circle(Vector2(735, 1310), 660, Color("315b59"))
	_decoration.paint(self, Vector2(803, 581 + sin(_time) * 3), 1.0, Color("e78278"))
	_decoration.paint(self, Vector2(1002, 629), 0.57, Color("eeb784"))
	# mote_index 决定漂浮孢子的位置，固定轨迹不影响游戏随机状态。
	for mote_index: int in range(18):
		# point 是单个漂浮孢子的 UI 坐标。
		var point: Vector2 = Vector2(
			620 + fmod(mote_index * 79.0, 590), 110 + fmod(mote_index * 103.0 + _time * 7, 460)
		)
		draw_circle(point, 2 + mote_index % 3, Color(1, 0.91, 0.63, 0.45))
