extends SceneTree
## 离线烘焙固定地形为 TileMapLayer；只在开发阶段手动运行，不在游戏中生成地图。


## 创建两套 64 格地形并保存可编辑场景；退出码表示保存结果。
func _initialize() -> void:
	# root 为生成场景根节点，每个子节点 owner 都指向此根以便打包。
	var terrain_root: Node2D = Node2D.new()
	terrain_root.name = "Terrain"
	terrain_root.editor_description = "固定首关地形；草地/地下双 TileMapLayer 可直接绘制。"
	# tile_set 包含草地顶面、土层和地下石材三种 atlas。
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	# source_index 与下方固定纹理顺序一一对应。
	for source_index: int in range(3):
		# source 使用已有 128px 纹理，运行时映射为 64px 逻辑格。
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		# texture_path 指向既有素材，地下使用同一基础加蓝灰调制。
		var texture_path: String = (
			"res://assets/art/environment/grassland/nature/tiles/tile_02.png"
			if source_index == 0
			else "res://assets/art/environment/grassland/nature/tiles/tile_05.png"
		)
		# image 将地形离线缩放到逻辑格，原始高清素材仍保留。
		if source_index == 2:
			texture_path = "res://assets/art/environment/common/tiles/stone_center.png"
		# 从已导入纹理获取源图像，供离线适配尺寸。
		var image: Image = (load(texture_path) as Texture2D).get_image()
		image.resize(64, 64, Image.INTERPOLATE_LANCZOS)
		# tile_path 为可导入的运行时适配纹理。
		var tile_path: String = "res://assets/art/environment/common/terrain_%d.png" % source_index
		image.save_png(tile_path)
		source.texture = ImageTexture.create_from_image(image)
		source.texture_region_size = Vector2i(64, 64)
		source.create_tile(Vector2i.ZERO)
		# tile_data 保存碰撞多边形；顶面完整，视觉与物理一致。
		var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
		tile_set.add_source(source, source_index)
		tile_data.set_collision_polygons_count(0, 1)
		tile_data.set_collision_polygon_points(
			0,
			0,
			PackedVector2Array(
				[Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)]
			)
		)
	# grass 为草地层，dungeon 为地下蓝灰层。
	var grass: TileMapLayer = TileMapLayer.new()
	grass.name = "GrasslandGround"
	grass.editor_description = "草地实体地形：坑宽最大 192，台阶高度不超过 128。"
	grass.tile_set = tile_set
	terrain_root.add_child(grass)
	grass.owner = terrain_root
	# 地下城地形层，独立保存主题和编辑属性。
	var dungeon: TileMapLayer = TileMapLayer.new()
	dungeon.name = "DungeonGround"
	dungeon.editor_description = "地下城实体地形；Boss 房和遭遇战场地连续无坑。"
	dungeon.tile_set = tile_set
	dungeon.modulate = Color("a4bbcd")
	terrain_root.add_child(dungeon)
	dungeon.owner = terrain_root
	# pits 为固定短坑起点格坐标；每坑三格即 192 世界单位。
	var pits: Array[int] = [82, 132, 184, 224, 371, 442, 491, 524]
	# x/y 分别是水平格与地面下方填充格索引。
	for x: int in range(680):
		# hole 表示此列是否位于设计坑范围。
		var hole: bool = false
		# 逐一判断当前列是否落入固定短坑。
		for pit: int in pits:
			if x >= pit and x < pit + 3:
				hole = true
		if hole:
			continue
		# 填充地表及其下方的四行实体格。
		for y: int in range(9, 13):
			# layer 按地下入口边界切换主题。
			var layer: TileMapLayer = grass if x < 340 else dungeon
			layer.set_cell(Vector2i(x, y), 2 if x >= 340 else (0 if y == 9 else 1), Vector2i.ZERO)
	# start 为主线台阶组起点格，每组留出宽敞跑跳落点。
	for start: int in [24, 64, 93, 119, 152, 196, 236, 267, 288, 348, 400, 427, 468, 504, 580, 608]:
		# layer 根据起点选择主题地形层。
		var layer: TileMapLayer = grass if start < 340 else dungeon
		# offset 为组内横向格，前后一级、中间两级台阶。
		for offset: int in range(8):
			layer.set_cell(Vector2i(start + offset, 8), 0 if start < 340 else 2, Vector2i.ZERO)
			if offset >= 2 and offset <= 5:
				layer.set_cell(Vector2i(start + offset, 7), 0 if start < 340 else 2, Vector2i.ZERO)
	# branch_start 为两条可选上层支路，连续地面仍可在下方通行。
	for branch_start: int in [100, 405]:
		# layer 为支路当前主题。
		var layer: TileMapLayer = grass if branch_start < 340 else dungeon
		# step 为通向上层的三层台阶，每层高 128。
		for step: int in range(3):
			# 每一级支路台阶使用三格宽落脚面。
			for x: int in range(3):
				layer.set_cell(
					Vector2i(branch_start + step * 3 + x, 7 - step * 2),
					0 if branch_start < 340 else 1,
					Vector2i.ZERO
				)
		# 铺设支路上层的连续可行走平台。
		for x: int in range(10, 21):
			layer.set_cell(
				Vector2i(branch_start + x, 5), 0 if branch_start < 340 else 1, Vector2i.ZERO
			)
	# wall_y 为关卡两端封边，防止玩家走出有效世界。
	for wall_y: int in range(0, 10):
		grass.set_cell(Vector2i(-1, wall_y), 1, Vector2i.ZERO)
		dungeon.set_cell(Vector2i(680, wall_y), 1, Vector2i.ZERO)
	# packed 为可在编辑器逐格调整的最终场景。
	var packed: PackedScene = PackedScene.new()
	packed.pack(terrain_root)
	# result 为 ResourceSaver 返回码，保存失败返回非零。
	var result: Error = ResourceSaver.save(packed, "res://scenes/levels/terrain.tscn")
	terrain_root.free()
	quit(0 if result == OK else 1)
