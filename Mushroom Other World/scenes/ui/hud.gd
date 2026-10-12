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


## 读取当前角色及关卡，绘制所有 HUD 元素。
func _draw() -> void:
	if not is_instance_valid(level):
		return
	# player 是只读角色数据来源。
	var player: Player = level.player
	_panel(Rect2(28, 24, 370, 122), Color(0.10, 0.20, 0.24, 0.92))
	_text(
		Vector2(48, 55),
		"BILL RIZER" if player.data.id == "bill" else "MEGA MAN",
		15,
		Color("96d9c9"),
		true
	)
	_text(Vector2(48, 85), player.data.display_name, 22, Color("fff0d3"), true)
	# hp_index 是生命格序号；空格仍保留轮廓。
	for hp_index: int in range(player.health.maximum):
		_panel(
			Rect2(198 + hp_index * 21, 54, 15, 24),
			Color("ffb28e") if hp_index < player.health.current else Color("40535c")
		)
	_text(
		Vector2(48, 125),
		"装备  " + player.weapons.catalog[player.weapons.equipped].display_name,
		19,
		Color("f9de98")
	)
	if player.data.id == "mega_man":
		_panel(Rect2(28, 154, 370, 54), Color(0.10, 0.20, 0.24, 0.92))
		# slot_index 是可见四个武器槽，未解锁显示点号。
		for slot_index: int in range(4):
			# id 为固定槽位的武器标识。
			var id: String = WeaponController.MEGA_SLOTS[slot_index]
			_text(
				Vector2(44 + slot_index * 86, 188),
				(
					"%d %s"
					% [
						slot_index + 1,
						["炮", "刃", "冰", "火"][slot_index] if player.weapons.unlocked.has(id) else "·"
					]
				),
				18,
				Color("ffe6a6") if id == player.weapons.equipped else Color("91adb7")
			)
		if player.weapons.equipped != "mega_buster":
			_text(
				Vector2(300, 125),
				"%d / 28" % player.weapons.energies[player.weapons.equipped],
				16,
				Color("9de9ed")
			)
	_panel(Rect2(920, 24, 332, 84), Color(0.10, 0.20, 0.24, 0.88))
	_text(
		Vector2(941, 56),
		"%02d / 08    %s" % [level.section + 1, level.data.section_names[level.section]],
		19,
		Color("f8e9c9"),
		true
	)
	_text(
		Vector2(941, 87),
		(
			"CP%d   ·   %s   ·   Esc 暂停"
			% [GameSession.checkpoint_index, GameSession.format_time(GameSession.total_time)]
		),
		16,
		Color("a6c7cb")
	)
	# progress 是角色当前水平进度，只作 HUD 路程提示。
	var progress: float = clampf(player.global_position.x / level.data.width, 0, 1)
	draw_rect(Rect2(28, 694, 1224, 4), Color(0.2, 0.35, 0.38, 0.45))
	draw_rect(Rect2(28, 694, 1224 * progress, 4), Color("b8e6c5"))
	if level.boss_active:
		_panel(Rect2(427, 24, 446, 94), Color(0.17, 0.16, 0.23, 0.94))
		_text(Vector2(451, 55), "孢子大王     PHASE %d" % level.boss.phase, 21, Color("ffe0b1"), true)
		draw_rect(Rect2(451, 71, 396, 16), Color("494b59"))
		draw_rect(Rect2(451, 71, 396.0 * level.boss.hp / level.boss.max_hp, 16), Color("efaa93"))
		_text(
			Vector2(455, 107),
			"核心已打开！" if level.boss.state == "exposed" else "观察预警 · 等待核心暴露",
			14,
			Color("b6ede5")
		)
	if message_time > 0:
		_panel(Rect2(280, 623, 720, 46), Color(0.10, 0.20, 0.24, 0.93))
		_text(Vector2(303, 654), message, 18, Color("fff0d2"))


## rect 为面板范围，color 为底色，统一圆角。
func _panel(rect: Rect2, color: Color) -> void:
	# style 是当前面板矢量样式。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	draw_style_box(style, rect)


## position/text/size/color/bold 分别指定基线、内容、字号、颜色及字重。
func _text(position: Vector2, text: String, size: int, color: Color, bold: bool = false) -> void:
	draw_string(BOLD if bold else FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
