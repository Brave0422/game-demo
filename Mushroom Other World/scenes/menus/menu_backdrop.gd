extends Control
## 主菜单使用同一手绘森林和角色肖像；左侧深色渐变保证中文可读。

## 微光动画时钟。
var _time: float = 0.0
## 真正连续的渐变纹理，避免逐条透明矩形重叠产生竖线。
var _shade: GradientTexture2D = GradientTexture2D.new()


## 初始化一次左深右浅的菜单遮罩，后续只重绘纹理。
func _ready() -> void:
	# gradient 保存三处颜色和透明度控制点。
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.48,1.0])
	gradient.colors = PackedColorArray([Color(0.045,0.09,0.10,0.90),
		Color(0.045,0.09,0.10,0.28),Color(0.045,0.09,0.10,0)])
	_shade.gradient = gradient
	_shade.width = 1280
	_shade.height = 1


## delta 为 UI 秒数，用于孢子微光。
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## 背景与角色构成菜单插画，文字和按钮由主场景独立管理。
func _draw() -> void:
	PaintedArt.draw(self,"forest",Rect2(Vector2.ZERO,size))
	draw_texture_rect(_shade,Rect2(Vector2.ZERO,size),false)
	PaintedArt.decoration(self,"red_mushrooms",Vector2(1105,718),290)
	PaintedArt.decoration(self,"flowers",Vector2(770,722),120)
	PaintedArt.draw(self,"bill_00",Rect2(735,300,350,315))
	PaintedArt.draw(self,"mega_00",Rect2(953,342,310,279))
	# mote 为菜单漂浮孢子，确定轨迹不改随机状态。
	for mote: int in range(18):
		draw_circle(Vector2(610+fmod(mote*83.0,650),
			70+fmod(mote*103.0+_time*7,560)),2+mote%2,Color(1,0.94,0.68,0.55))
