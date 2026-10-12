extends Node2D
## 在原有 TileMapLayer 碰撞上绘制手绘地形；格子、坑洞、台阶均来自原场景。

## 实体地形层引用，不改动单元和碰撞数据。
var _layers: Array[TileMapLayer] = []


## 隐藏旧地形颜色但保留物理，原有编辑器格子仍可继续编辑。
func _ready() -> void:
	# child 为原场景的草地和地下地形层。
	for child: Node in get_children():
		if child is TileMapLayer:
			_layers.append(child)
			child.self_modulate.a = 0


## 每物理步更新可见区域，镜头移动时按原地图绘制。
func _physics_process(_delta: float) -> void:
	queue_redraw()


## 只绘制镜头附近的固定格子；露出的上边缘才出现草或亮石顶。
func _draw() -> void:
	if not get_viewport().get_camera_2d():
		return
	# left 为可见地形最左格，额外保留一格以适应镜头震动。
	var left: int = floori((get_viewport().get_camera_2d().get_screen_center_position().x-704)/64)
	# layer 为保持原碰撞的地形层。
	for layer: TileMapLayer in _layers:
		# cave 选择石墙或草地主题。
		var cave: bool = layer.name == "DungeonGround"
		# x/y 为本帧可见单元的列与行。
		for x: int in range(left,left+24):
			for y: int in range(13):
				# cell 为原地图中的实体单元坐标。
				var cell: Vector2i = Vector2i(x,y)
				if layer.get_cell_source_id(cell)<0:
					continue
				# exposed 表示上方没有实体，站立边缘与碰撞顶面一致。
				var exposed: bool = layer.get_cell_source_id(cell+Vector2i.UP)<0
				# rect 对应原始 64 单位格，填色避免圆角纹理边缘露缝。
				var rect: Rect2 = Rect2(x*64,y*64,64,64)
				if not cave:
					# top_y 为本列连续实体的顶格，跨行采样保持岩壁纹理连续。
					var top_y: int = y
					while layer.get_cell_source_id(Vector2i(x,top_y-1))>=0:
						top_y -= 1
					# depth 为距离表面的格数；深处只循环岩石，不重复长草。
					var depth: int = y-top_y
					# ground 为连续地表，12 格宽、4 格高一个材质周期。
					var ground: Texture2D = PaintedArt.texture("ground_strip")
					# source_row 为连续岩壁采样行，最顶行含草沿。
					var source_row: int = depth if depth<4 else 2+depth%2
					draw_texture_rect_region(ground,rect,Rect2(
						posmod(x,12)*ground.get_width()/12.0,
						source_row*ground.get_height()/4.0,
						ground.get_width()/12.0,ground.get_height()/4.0))
					if exposed and x%7==3:
						PaintedArt.decoration(self,"flowers",Vector2(x*64+32,y*64+4),24)
					continue
				draw_rect(rect,Color("343849") if cave else Color("71543a"))
				# image 使用两格一个材质周期，让岩块大小与人物和背景一致。
				var image: Texture2D = PaintedArt.texture(
					("stone_top" if cave else "grass_top") if exposed
					else ("stone" if cave else "earth"))
				# region 是 128 单位纹理中的当前 64 格，消除密集小格重复感。
				var region: Rect2 = Rect2(posmod(x,2)*image.get_width()*0.5,
					0 if exposed else posmod(y,2)*image.get_height()*0.5,
					image.get_width()*0.5,image.get_height()*0.5)
				draw_texture_rect_region(image,rect,region)
				if exposed:
					if not cave and x%7==3:
						PaintedArt.decoration(self,"flowers",Vector2(x*64+32,y*64+4),24)
