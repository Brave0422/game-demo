extends Node2D
## 参考图同风格的手绘远景与植被视差；只绘制可见区域，不参与碰撞。

## 当前相机中心，每物理步同步。
var _center: Vector2 = Vector2(640,360)
## 固定孢子漂浮时钟，不参与游戏随机状态。
var _time: float = 0.0


## delta 为物理秒数；镜头坐标只影响背景的显示位置。
func _physics_process(delta: float) -> void:
	_time += delta
	if get_viewport().get_camera_2d():
		_center = get_viewport().get_camera_2d().get_screen_center_position()
	queue_redraw()


## 使用镜像重复保持连续卷轴；近景脚底处于可行走地形背后。
func _draw() -> void:
	# left 为本帧可见边界。
	var left: float = _center.x-640
	# cave 为地下主题分支。
	var cave: bool = _center.x>=21760
	# width 为宽背景的世界显示尺寸。
	var width: float = 1600
	# offset 为低速视差位移。
	var offset: float = _center.x*0.16
	# index 为覆盖视口左右的重复段。
	for index: int in range(floori(offset/width)-1,floori(offset/width)+2):
		# x 为这一段的世界起点。
		var x: float = left+index*width-offset
		draw_set_transform(Vector2(x+(width if index%2!=0 else 0),-120),0,
			Vector2(-1 if index%2!=0 else 1,1))
		PaintedArt.draw(self,"cave" if cave else "forest",Rect2(0,0,width,900),
			Color("ded7e9") if cave else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	# index 为固定种植的世界位置，随镜头滚动但不会跳动。
	for index: int in range(floori(left/420)-1,ceili((left+1280)/420)+1):
		# x 为装饰的固定世界位置。
		var x: float = index*420+90
		if cave:
			PaintedArt.decoration(self,"purple_mushrooms",Vector2(x+60,580),
				100 if index%2==0 else 65,Color("c3b5d8"))
		else:
			if index%3==0:
				PaintedArt.decoration(self,"tree",Vector2(x+190,580),310,Color("d1dfbd"))
			PaintedArt.decoration(self,"red_mushrooms",Vector2(x,580),
				110 if index%2==0 else 78,Color("e6e1cb"))
			PaintedArt.decoration(self,"flowers",Vector2(x+225,580),45)
	# mote 为少量漂浮微光，不覆盖主要射弹。
	for mote: int in range(12):
		draw_circle(Vector2(left+fmod(mote*131.0-_time*8,1280),
			140+fmod(mote*79.0+_time*6,365)),1.5,
			Color(0.85,0.60,1,0.3) if cave else Color(1,0.96,0.64,0.35))
