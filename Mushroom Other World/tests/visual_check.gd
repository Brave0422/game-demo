extends Node
## 实际 Compatibility 渲染截图；截图只来自运行中的 Godot Viewport。


## 依次呈现菜单、两名角色、地下城、Boss 与暂停页并截图。
func _ready() -> void:
	# main 为真实应用入口，测试通过原有菜单方法驱动。
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await _capture("menu")
	main._show_selection()
	await _capture("selection")
	main._start("bill")
	await _capture("grassland_bill")
	main.level.player.global_position = Vector2(22400, 576)
	main.level.camera.reset_smoothing()
	await _capture("dungeon_bill")
	main._start("mega_man")
	await _capture("grassland_mega_man")
	main.level.player.global_position = Vector2(42400, 576)
	await _capture("boss")
	main._pause()
	await _capture("pause")
	main._show_main()
	await get_tree().process_frame
	main.queue_free()
	AudioManager.stop_all()
	await get_tree().create_timer(0.15, true).timeout
	get_tree().quit()


## name 为证据文件名；等待真实绘制完成后读取视口。
func _capture(name: String) -> void:
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	# image 为真实渲染帧，未经图像编辑。
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://docs/validation/%s.png" % name)
	print("CAPTURE: ", name)
