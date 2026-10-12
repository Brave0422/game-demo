extends Control
## 只读 HUD：生命、武器、能量、区段、检查点、Boss 与短提示。

## 中文常规字体。
const FONT: Font = preload("res://assets/fonts/noto_sans_sc_regular.otf")
## 中文粗体字体。
const BOLD: Font = preload("res://assets/fonts/noto_sans_sc_bold.otf")
## 主场景注入的关卡，只读取状态不执行伤害。
var level: MushroomWorld
## 当前短提示内容。
var message: String = "A / D 移动   K 跳跃   J 射击 · 向上顶砖，射击开箱"
## 提示剩余显示秒数。
var message_time: float = 10.0


## delta 为界面帧时间；暂停世界时提示计时同样冻结。
func _process(delta: float) -> void:
	if not get_tree().paused:
		message_time = maxf(0.0, message_time - delta)
	queue_redraw()


## text 为关卡事件提示，统一显示四秒。
func show_hint(text: String) -> void:
	message = text
	message_time = 4.0


## 紧凑 HUD：手绘生命图标与暖金边框，把主要空间留给关卡。
func _draw() -> void:
	if not is_instance_valid(level):
		return
	# player 为只读的角色状态。
	var player: Player = level.player
	_panel(Rect2(24,20,346,97),Color(0.11,0.13,0.14,0.88))
	_text(Vector2(42,47),player.data.display_name,20,Color("fff1d4"),true)
	# hp_index 是八格生命序号，空格使用透明图标保留数量提示。
	for hp_index: int in range(player.health.maximum):
		PaintedArt.draw(self,"heart",Rect2(188+hp_index*20,31,16,16),
			Color.WHITE if hp_index<player.health.current else Color(0.45,0.45,0.45,0.5))
	_text(Vector2(42,76),"装备  "+player.weapons.catalog[player.weapons.equipped].display_name,
		17,Color("f8dba0"))
	_text(Vector2(42,100),"J 射击  ·  K 跳跃",12,Color("bac6bd"))
	if player.data.id=="mega_man":
		_panel(Rect2(24,125,346,38),Color(0.11,0.13,0.14,0.85))
		# slot_index 为四个武器栏，能量直接使用当前武器数值。
		for slot_index: int in range(4):
			# id 为固定武器槽标识。
			var id: String = WeaponController.MEGA_SLOTS[slot_index]
			_text(Vector2(38+slot_index*80,150),
				"%d %s" % [slot_index+1,
				["炮","刃","冰","火"][slot_index] if player.weapons.unlocked.has(id) else "·"],
				16,Color("ffe4a2") if id==player.weapons.equipped else Color("a3b2b3"))
		if player.weapons.equipped!="mega_buster":
			_text(Vector2(280,100),"%d / 28" % player.weapons.energies[player.weapons.equipped],
				13,Color("a5e6f1"))
	_panel(Rect2(950,20,306,74),Color(0.11,0.13,0.14,0.85))
	_text(Vector2(968,47),"%02d / 08  %s" %
		[level.section+1,level.data.section_names[level.section]],17,Color("ffe6bd"),true)
	_text(Vector2(968,77),"CP%d  ·  %s  ·  Esc 暂停" %
		[GameSession.checkpoint_index,GameSession.format_time(GameSession.total_time)],
		14,Color("bac6bd"))
	# progress 为真实水平进度。
	var progress: float = clampf(player.global_position.x/level.data.width,0,1)
	draw_rect(Rect2(24,697,1232,3),Color(0.15,0.19,0.2,0.5))
	draw_rect(Rect2(24,697,1232*progress,3),Color("e8d19b"))
	if level.boss_active:
		_panel(Rect2(422,20,452,87),Color(0.15,0.10,0.16,0.91))
		_text(Vector2(440,46),"孢子大王  ·  阶段 %d" % level.boss.phase,18,Color("ffe1a9"),true)
		draw_rect(Rect2(440,58,414,13),Color("4b3441"))
		draw_rect(Rect2(440,58,414.0*level.boss.hp/level.boss.max_hp,13),Color("efa36b"))
		_text(Vector2(440,94),"核心已打开！" if level.boss.state=="exposed"
			else "观察预警 · 等待核心暴露",13,Color("c6e6dc"))
	if message_time>0:
		_panel(Rect2(280,628,720,40),Color(0.11,0.13,0.14,0.88))
		_text(Vector2(300,654),message,16,Color("fff0d2"))


## rect 为面板范围，color 为底色；暖金边缘呼应手绘场景。
func _panel(rect: Rect2, color: Color) -> void:
	# style 为圆角、细边框与柔和阴影。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.86,0.70,0.40,0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0,0,0,0.20)
	style.shadow_size = 4
	draw_style_box(style,rect)


## position/text/size/color/bold 分别指定基线、内容、字号、颜色及字重。
func _text(position: Vector2, text: String, size: int, color: Color, bold: bool = false) -> void:
	draw_string(BOLD if bold else FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
