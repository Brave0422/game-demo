extends SceneTree
## 从导出包外部调用的冒烟测试；运行资源只能从 exe 同目录的 PCK 加载。


## 延迟到导出项目的全局服务就绪后开始，测试代码本身不打包给玩家。
func _initialize() -> void:
	_run.call_deferred()


## 实际打开菜单并依次启动两角色，检查动态加载资源、暂停和返回菜单。
func _run() -> void:
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
