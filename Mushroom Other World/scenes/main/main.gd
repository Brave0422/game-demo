extends Node
## 应用入口仅负责菜单、场景生命周期和暂停；世界规则位于各自场景。

## 完整首关预制场景。
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/mushroom_world.tscn")
## HUD 专属脚本。
const HUD_SCRIPT: Script = preload("res://scenes/ui/hud.gd")
## 主菜单环境绘制脚本。
const BACKDROP_SCRIPT: Script = preload("res://scenes/menus/menu_backdrop.gd")
## 当前关卡引用，菜单期间为空。
var level: MushroomWorld
## 当前 HUD 控件。
var hud: Control
## 菜单页面根节点，每次切换只保留一棵 UI 树。
var _page: Control
## 当前菜单状态。
var _screen: String = "main"
## 用户当前选中的角色。
var _selected: String = "bill"
## 暂停期间是否释放过射击，用于取消旧蓄力而不补发。
var _released_shoot_during_pause: bool = false
## 暂停开始时是否保持射击键，区分菜单确认与持续蓄力。
var _paused_with_shoot: bool = false
## 中文 UI 主题。
var _theme: Theme
## UI 根节点，允许暂停时继续处理。
@onready var interface: Control = $Interface/Root


## 建立 UI 主题并进入主菜单，输入映射由 project.godot 保存。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_build_theme()
	interface.theme = _theme
	_show_main()


## event 为应用输入；Esc 由主入口处理，防止穿透 UI 到关卡。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if _screen == "playing":
			_pause()
		elif _screen == "pause":
			_resume()
		elif _screen in ["select", "credits", "settings"] and not is_instance_valid(level):
			_show_main()
		get_viewport().set_input_as_handled()


## event 为未经 UI 消费的原始输入；暂停期间松 J 立即取消蓄力。
func _input(event: InputEvent) -> void:
	if get_tree().paused and is_instance_valid(level) and event.is_action_released("shoot"):
		_released_shoot_during_pause = true
		level.player.weapons.cancel_charge()


## what 为系统通知；失焦自动暂停，恢复焦点不自动开火。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _screen == "playing":
		_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


## 先终止音频再退出；短暂回收时间避免直接关闭音频线程留下活动解码资源。
func _request_quit() -> void:
	if _screen == "exiting":
		return
	_screen = "exiting"
	get_tree().paused = true
	AudioManager.stop_all()
	await get_tree().create_timer(0.15, true).timeout
	get_tree().quit()


## 为中文字体、按钮和滑条创建统一样式。
func _build_theme() -> void:
	_theme = Theme.new()
	_theme.default_font = preload("res://assets/fonts/noto_sans_sc_regular.otf")
	_theme.default_font_size = 20
	# state 为按钮可交互状态，各状态都有清楚焦点反馈。
	for state: String in ["normal", "hover", "pressed", "focus"]:
		# style 为按钮底色、圆角与内边距。
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("f2d8a0") if state in ["hover", "focus"] else Color("e7c995")
		if state == "pressed":
			style.bg_color = Color("c3a679")
		style.border_color = Color("fff1c7")
		style.set_border_width_all(3 if state == "focus" else 0)
		style.set_corner_radius_all(12)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		_theme.set_stylebox(state, "Button", style)
	_theme.set_color("font_color", "Button", Color("233f48"))
	_theme.set_color("font_hover_color", "Button", Color("233f48"))
	_theme.set_color("font_focus_color", "Button", Color("233f48"))


## 删除旧页面；world_visible 指示是否以运行中的关卡为背景。
func _new_page(world_visible: bool = false) -> void:
	if is_instance_valid(_page):
		interface.remove_child(_page)
		_page.queue_free()
	_page = Control.new()
	_page.name = "MenuPage"
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(_page)
	if world_visible:
		# dim 为暂停/死亡遮罩，保留世界画面帮助理解当前地点。
		var dim: ColorRect = ColorRect.new()
		dim.name = "WorldDimmer"
		dim.color = Color(0.04, 0.1, 0.15, 0.77)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_page.add_child(dim)
	else:
		# backdrop 为菜单环境画，不参与输入事件。
		var backdrop: Control = Control.new()
		backdrop.name = "ForestBackdrop"
		backdrop.set_script(BACKDROP_SCRIPT)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page.add_child(backdrop)


## x/y/width 指定页面内容布局；VBoxContainer 自动管理文本和按钮间距。
func _column(x: float, y: float, width: float) -> VBoxContainer:
	# column 是该页面唯一主内容容器。
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "ContentColumn"
	column.position = Vector2(x, y)
	column.size.x = width
	column.add_theme_constant_override("separation", 15)
	_page.add_child(column)
	return column


## parent/text/font_size/color 定义文本内容与层级，返回可进一步配置的 Label。
func _label(
	parent: Control, text: String, font_size: int = 20, color: Color = Color("f6eacc")
) -> Label:
	# label 为自动适应容器宽度的中文标签。
	var label: Label = Label.new()
	label.name = "TextLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## parent/text/action 为按钮容器、标题与唯一点击回调。
func _button(parent: Control, text: String, action: Callable) -> Button:
	# button 自带键盘焦点与 Enter/J 确认，不用自绘假按钮。
	var button: Button = Button.new()
	button.name = "ActionButton"
	button.text = text
	button.custom_minimum_size.y = 51
	button.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui", Vector2.ZERO, true)
			action.call()
	)
	parent.add_child(button)
	return button


## 主菜单入口：新游戏、设置与署名，不提供虚假的跨会话继续按钮。
func _show_main() -> void:
	_dispose_level()
	GameSession.clear_run()
	_screen = "main"
	_new_page()
	AudioManager.change_music("grassland")
	# column 为左侧主菜单内容。
	var column: VBoxContainer = _column(84, 74, 440)
	_label(column, "A LITTLE SPORE. A BIG ADVENTURE.", 15, Color("a8ded0"))
	_label(column, "蘑菇异界", 67)
	_label(column, "双 雄 闯 关", 29, Color("f2c989"))
	_label(column, "穿越蘑菇原，唤醒地下的秘密。\n选择你的英雄，向孢子大王发起挑战。", 19)
	_label(column, "", 8)
	_button(column, "开始冒险     →", _show_selection).grab_focus()
	_button(column, "声音与显示", func() -> void: _show_settings(false))
	_button(column, "操作 / 素材署名", _show_credits)
	_button(column, "退出游戏", _request_quit)
	_label(column, "单人 · 键盘     /     GODOT 4.7.2", 14, Color("aad0c4"))


## 角色选择页明确两套武器差异，选择后才开始新会话。
func _show_selection() -> void:
	_screen = "select"
	_new_page()
	# column 为选择页顶部及下方操作区。
	var column: VBoxContainer = _column(84, 62, 760)
	_label(column, "选择同行的英雄", 42)
	_label(column, "同一段旅程，两种战斗方式。", 20, Color("b6dace"))
	_label(column, "比尔 · 雷泽   /   BILL RIZER", 28, Color("f7cea0"))
	_label(column, "红头巾突击兵 · 八方向射击 / 地面趴下\nM 机枪 · S 散弹 · L 激光 · F 火球\n武器无限弹药，拾取后替换当前枪。", 20)
	_button(column, "选择比尔，开始冒险", func() -> void: _start("bill")).grab_focus()
	_label(column, "经典洛克人   /   MEGA MAN", 28, Color("a6e2ef"))
	_label(column, "蓝色手炮英雄 · 跑跳射击 / 按住 J 蓄力，松手释放\n回旋切刃 · 冰冻波 · 火焰风暴\nQ 或 1–4 换武器，特殊武器各有独立能量。", 20)
	_button(column, "选择洛克人，开始冒险", func() -> void: _start("mega_man"))
	_button(column, "返回", _show_main)


## character 为选择角色；新游戏清空会话后加载完整关卡。
func _start(character: String) -> void:
	_selected = character
	GameSession.start_run(character)
	_load_level()


## 加载/重试共用入口；先移除旧场景，阻止跨局信号和弹体残留。
func _load_level() -> void:
	_dispose_level()
	_screen = "playing"
	if is_instance_valid(_page):
		_page.queue_free()
		_page = null
	level = LEVEL_SCENE.instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.player_died.connect(_show_death)
	level.cleared.connect(_show_result)
	hud = Control.new()
	hud.name = "HUD"
	hud.set_script(HUD_SCRIPT)
	hud.level = level
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(hud)
	level.hint_requested.connect(hud.show_hint)


## 暂停世界并开放 UI；失焦与 Esc 走同一入口。
func _pause() -> void:
	if not is_instance_valid(level) or level.ended:
		return
	if not get_tree().paused:
		_released_shoot_during_pause = false
		_paused_with_shoot = Input.is_action_pressed("shoot")
	_screen = "pause"
	get_tree().paused = true
	_new_page(true)
	# column 为暂停操作菜单。
	var column: VBoxContainer = _column(424, 95, 432)
	_label(column, "歇一会儿", 42)
	_label(column, "当前检查点 CP%d · 进度仅在本次会话保留" % GameSession.checkpoint_index, 17)
	_button(column, "继续冒险", _resume).grab_focus()
	_button(column, "从检查点重试", func() -> void: _retry(true))
	_button(column, "重新开始本关", func() -> void: _start(_selected))
	_button(column, "声音与显示", func() -> void: _show_settings(true))
	_button(column, "返回主菜单（丢弃本次进度）", _show_main)


## 恢复时若射击键在暂停期间松开，只取消蓄力不补发。
func _resume() -> void:
	if not Input.is_action_pressed("shoot"):
		level.player.weapons.cancel_charge()
	elif _released_shoot_during_pause or not _paused_with_shoot:
		level.player.weapons.cancel_charge()
		level.player.input_locked = true
	get_tree().paused = false
	_screen = "playing"
	_page.queue_free()
	_page = null


## manual 表示手动重试，死亡重试不会重复增加死亡计数。
func _retry(manual: bool) -> void:
	GameSession.retry_checkpoint(manual)
	_load_level()


## 死亡菜单只有在关卡仲裁结束后展示，避免与胜利菜单同帧竞争。
func _show_death() -> void:
	_screen = "death"
	get_tree().paused = true
	_new_page(true)
	# column 为失败信息与重试按钮。
	var column: VBoxContainer = _column(420, 190, 440)
	_label(column, "再试一次", 48)
	_label(column, "从 CP%d 重新出发。\n生命恢复，装备与世界回到检查点状态。" % GameSession.checkpoint_index, 19)
	_button(column, "从检查点重试", func() -> void: _retry(false)).grab_focus()
	_button(column, "返回主菜单（丢弃本次进度）", _show_main)


## 显示真实会话统计，不把挑战总用时当作主线验收时长。
func _show_result() -> void:
	_screen = "result"
	get_tree().paused = true
	_new_page(true)
	# column 为结算页数据和下一步操作。
	var column: VBoxContainer = _column(396, 100, 490)
	_label(column, "蘑菇原重获宁静", 40)
	_label(column, "冒险完成 · " + level.player.data.display_name, 23, Color("a6dfd4"))
	_label(
		column,
		(
			"主线内容用时     %s\n支路额外用时     %s\n挑战总用时         %s\n死亡 %d 次     /     手动重试 %d 次"
			% [
				GameSession.format_time(GameSession.content_time()),
				GameSession.format_time(GameSession.committed_branch + GameSession.segment_branch),
				GameSession.format_time(GameSession.total_time),
				GameSession.deaths,
				GameSession.retries
			]
		),
		21
	)
	_button(column, "用当前角色再玩一次", func() -> void: _start(_selected)).grab_focus()
	_button(
		column,
		"换一位英雄",
		func() -> void:
			_dispose_level()
			_show_selection()
	)
	_button(column, "返回主菜单", _show_main)


## in_game 决定返回暂停页还是主菜单；更改立即保存。
func _show_settings(in_game: bool) -> void:
	_screen = "settings"
	_new_page(in_game)
	# column 为设置表单，用容器管理各滑条。
	var column: VBoxContainer = _column(370, 80, 540)
	_label(column, "声音与显示", 40)
	# bus 是音频总线名称，标签采用对应中文名。
	for bus: String in ["Master", "Music", "SFX"]:
		_label(column, {"Master": "主音量", "Music": "音乐音量", "SFX": "音效音量"}[bus], 20)
		# slider 是 0～1 音量输入，键盘方向键可调整。
		var slider: HSlider = HSlider.new()
		slider.name = "VolumeSlider"
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = SaveService.settings[bus]
		slider.custom_minimum_size.y = 32
		slider.value_changed.connect(
			func(value: float) -> void: SaveService.set_setting(bus, value)
		)
		column.add_child(slider)
	# fullscreen 控件只影响显示，不改变逻辑视口。
	var fullscreen: CheckButton = CheckButton.new()
	fullscreen.name = "FullscreenToggle"
	fullscreen.text = "全屏显示"
	fullscreen.button_pressed = SaveService.settings["fullscreen"]
	fullscreen.toggled.connect(
		func(value: bool) -> void: SaveService.set_setting("fullscreen", value)
	)
	column.add_child(fullscreen)
	# shake 为小幅镜头震动偏好。
	var shake: CheckButton = CheckButton.new()
	shake.name = "CameraShakeToggle"
	shake.text = "受伤镜头反馈"
	shake.button_pressed = SaveService.settings["shake"]
	shake.toggled.connect(func(value: bool) -> void: SaveService.set_setting("shake", value))
	column.add_child(shake)
	_button(column, "返回", _pause if in_game else _show_main).grab_focus()


## 展示操作与来源摘要，完整逐文件许可位于项目 manifest 与 CREDITS。
func _show_credits() -> void:
	_screen = "credits"
	_new_page()
	# column 为帮助页正文与返回按钮。
	var column: VBoxContainer = _column(84, 64, 960)
	_label(column, "冒险手册", 43)
	_label(
		column,
		(
			"A / D 或 ← / → 移动     K 跳跃     J 射击\n比尔：W / S 瞄准，站立按 S 趴下。\n"
			+ "洛克人：按住 J 蓄力，松手释放；Q / 1–4 换武器。\n"
			+ "Esc 暂停。检查点补满生命；掉坑死亡，重试次数不限。\n"
			+ "只有刺壳滚兽持续触碰伤害。其他怪物观察预警再躲避。"
		),
		21
	)
	_label(column, "素材与制作", 27, Color("f4d398"))
	_label(
		column,
		(
			"环境 / UI / 音效：Kenney、GameArt2D（CC0）\n"
			+ "蘑菇 / 蝙蝠：OpenGameArt 作者，详见 CREDITS.md\n"
			+ "音乐：SpiderDave、nihilocrat、nene（CC0）\n字体：Noto Sans CJK（SIL OFL 1.1）\n"
			+ "新增角色 / 怪物：本项目可编辑矢量绘制，经典形象为同人改编。\n"
			+ "完整来源及许可：assets/manifest.csv、assets/licenses/。"
		),
		18
	)
	_button(column, "返回", _show_main).grab_focus()


## 解除暂停、清理旧 HUD/关卡/声音；不触碰用户磁盘设置。
func _dispose_level() -> void:
	get_tree().paused = false
	AudioManager.clear_world_sounds()
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
		level = null
	if is_instance_valid(hud):
		hud.queue_free()
		hud = null
