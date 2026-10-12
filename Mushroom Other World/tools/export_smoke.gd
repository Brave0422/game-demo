extends SceneTree
## 从导出包外部调用的冒烟测试；运行资源只能从 exe 同目录的 PCK 加载。


## 延迟到导出项目的全局服务就绪后开始，测试代码本身不打包给玩家。
func _initialize() -> void:
	_run.call_deferred()


## 实际打开菜单并依次启动两角色，检查动态加载资源、暂停和返回菜单。
func _run() -> void:
	# asset 为手绘资源；从 PCK 显式加载，避免无窗口模式不绘制而漏检动态纹理。
	for asset: String in ["forest","cave","ground_strip","grass_top","earth",
		"stone_top","stone","brick","crate","cracked","platform","tree",
		"flowers","red_mushrooms","purple_mushrooms","capsule_s","capsule_l",
		"capsule_f","heart","ammo","flag","ice","cutter","fire"]:
		if not PaintedArt.texture(asset):
			push_error("导出包缺少手绘资源: "+asset)
			quit(1)
			return
	# character 为动作资源前缀，逐帧确认导出包内容。
	for character: String in ["bill","mega"]:
		# frame 为完整角色帧序号。
		for frame: int in range(12):
			assert(PaintedArt.texture("%s_%02d" % [character,frame]))
	# enemy 为五怪资源前缀。
	for enemy: String in ["patrol","spitter","bat","roller","beetle"]:
		# frame 为三种机制状态资源。
		for frame: int in range(3):
			assert(PaintedArt.texture("%s_%d" % [enemy,frame]))
	# frame 为 Boss 四种动作图。
	for frame: int in range(4):
		assert(PaintedArt.texture("boss_%d" % frame))
	print("EXPORT PAINTED ASSETS PASS: 67 textures")
	# main 是导出包中的真实应用入口，非编辑器目录下的松散场景。
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# character 对应两份角色资源，均通过正式菜单入口开始新会话。
	for character: String in ["bill", "mega_man"]:
		main._start(character)
		await create_timer(0.2).timeout
		if main.level.player.data.id != character:
			push_error("导出包角色初始化错误")
			quit(1)
			return
		if get_nodes_in_group("enemies").size() != 40:
			push_error("导出包固定怪物未完整加载")
			quit(1)
			return
		main._pause()
		await process_frame
		main._resume()
		main._show_main()
		await process_frame
		print("EXPORT SMOKE PASS: ", character)
	main.queue_free()
	await process_frame
	quit(0)
