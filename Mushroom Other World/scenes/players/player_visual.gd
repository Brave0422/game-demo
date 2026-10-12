extends Node2D
## 原创可编辑矢量分层角色：独立双腿、身体、头与武器，动画不移动物理锚点。

## 描边颜色，统一两角色视觉语言。
const OUTLINE: Color = Color("243442")
## 父节点注入的玩家，只读动作状态。
var player: Player


## 绘制分层卡通动作；跑步、腾空、趴下、死亡、蓄力与枪口方向分别处理。
func _draw() -> void:
	if not is_instance_valid(player):
		return
	# bill 为角色外观分支，不参与武器逻辑。
	var bill: bool = player.data.id == "bill"
	# step 为跑动摆腿角度，空中改为收腿姿势。
	var step: float = sin(player.animation_time * 16.0) * minf(absf(player.velocity.x) / 320.0, 1.0)
	# body_color 为服装主色，皮肤与装甲有独立层。
	var body_color: Color = Color("41746a") if bill else Color("279ae5")
	# skin 是比尔肤色和洛克人的面部颜色。
	var skin: Color = Color("f2c99c")
	# flash 为无敌闪烁透明度，逻辑无敌不会由视觉决定。
	var flash: float = (
		0.4
		if player.health.invulnerability > 0.0 and int(player.animation_time * 16.0) % 2 == 0
		else 1.0
	)
	modulate.a = flash
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(player.facing, 1.0))
	if player.health.current <= 0:
		draw_set_transform(Vector2(0, -22), PI * 0.5, Vector2(player.facing, 1.0))
	if player.crouched:
		draw_set_transform(Vector2(-18, -3), -0.9, Vector2(player.facing, 0.65))
	# leg_index 标识前后两条腿，各自围绕髋关节摆动。
	for leg_index: int in [-1, 1]:
		# foot 为当前腿脚底，空中向后折叠。
		var foot: Vector2 = Vector2(leg_index * 12 + step * leg_index * 13, -9)
		if not player.is_on_floor():
			foot += Vector2(leg_index * 10, -8 if leg_index < 0 else -2)
		draw_line(Vector2(leg_index * 9, -40), foot, OUTLINE, 19, true)
		draw_line(Vector2(leg_index * 9, -40), foot, body_color.darkened(0.18), 13, true)
		_pill(
			Rect2(foot + Vector2(-10, -8), Vector2(28, 17)),
			Color("294b51") if bill else Color("166fc5")
		)
	_pill(Rect2(-23, -72, 44, 39), body_color)
	if bill:
		draw_line(Vector2(-15, -66), Vector2(11, -38), Color("b4c796"), 6, true)
		draw_line(Vector2(-18, -38), Vector2(20, -38), Color("263e43"), 7, true)
	# head_center 保持相对于身体稳定，跑步不影响枪口。
	var head_center: Vector2 = Vector2(0, -87)
	draw_circle(head_center, 25, OUTLINE)
	draw_circle(head_center, 21, skin)
	if bill:
		draw_arc(head_center, 21, PI, TAU - 0.2, 24, Color("503832"), 13, true)
		draw_line(Vector2(-22, -96), Vector2(21, -96), Color("e9604c"), 9, true)
		draw_colored_polygon(
			PackedVector2Array(
				[Vector2(-20, -96), Vector2(-41, -86), Vector2(-31, -79), Vector2(-15, -91)]
			),
			Color("e9604c")
		)
	else:
		draw_arc(head_center, 22, PI - 0.2, TAU + 0.2, 28, body_color, 14, true)
		_pill(Rect2(-25, -96, 13, 22), Color("176bbc"))
		draw_line(Vector2(-4, -108), Vector2(7, -102), Color("94e5f5"), 8, true)
	draw_circle(Vector2(11, -88), 3, OUTLINE)
	draw_line(Vector2(7, -77), Vector2(15, -78), OUTLINE, 2, true)
	# aim 把世界瞄准转换到面向右的局部层，保证枪与弹道对齐。
	var aim: Vector2 = player.aim_direction() * Vector2(player.facing, 1)
	draw_set_transform(
		Vector2(9 * player.facing, -24 if player.crouched else -65),
		aim.angle() * player.facing,
		Vector2(player.facing, 1)
	)
	_pill(Rect2(-9, -9, 34, 19), skin if bill else Color("8addf6"))
	_pill(Rect2(14, -12, 33, 24), Color("3b555b") if bill else Color("1372be"))
	_pill(Rect2(36, -7, 13, 14), Color("142e42"))
	if bill:
		draw_line(Vector2(22, -12), Vector2(38, -12), Color("a4bfba"), 4, true)
	if player.weapons.charge >= 0.4:
		draw_arc(
			Vector2(42, 0),
			19 if player.weapons.charge < 1.1 else 28,
			0,
			TAU,
			32,
			Color("b6fbff"),
			4,
			true
		)
	draw_set_transform(Vector2.ZERO)


## rect 为局部圆角矩形，color 为填色；统一深描边与柔和外形。
func _pill(rect: Rect2, color: Color) -> void:
	# style 为轻量即时矢量画笔，使用 Godot 抗锯齿圆角。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = OUTLINE
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	draw_style_box(style, rect)
