extends Node2D
## 手绘人物动作播放器：共同画布、缩放与脚底锚点，视觉不会改变碰撞。

## 父节点注入的玩家，只读角色、瞄准与战斗状态。
var player: Player


## 按人物物理状态选择独立动作图，跑步循环包含四种腿部姿势。
func _draw() -> void:
	if not is_instance_valid(player):
		return
	# bill 为两套外观的选择，不改变武器配置。
	var bill: bool = player.data.id == "bill"
	# frame 为透明动作帧下标。
	var frame: int = 0
	# aim 为相对于角色面向的瞄准方向。
	var aim: Vector2 = player.aim_direction() * Vector2(player.facing,1)
	if player.health.current <= 0:
		frame = 11
	elif player.crouched:
		frame = 8
	elif player._knockback > 0:
		frame = 10
	elif bill and aim.y < -0.4:
		frame = 6 if absf(aim.x) < 0.2 else 7
	elif bill and aim.y > 0.4:
		frame = 9
	elif not player.is_on_floor():
		frame = 5
	elif absf(player.velocity.x) > 25:
		frame = 1 + int(player.animation_time*10) % 4
	# 无敌透明闪烁沿用真实无敌时间，不依赖图片状态。
	modulate.a = 0.45 if (player.health.invulnerability > 0 and
		int(player.animation_time*16)%2 == 0) else 1.0
	draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
	PaintedArt.draw(self,"%s_%02d" % ["bill" if bill else "mega",frame],
		Rect2(-64,-136,160,144))
	if player.weapons.charge >= 0.4:
		draw_circle(Vector2(57,-65),18 if player.weapons.charge<1.1 else 25,
			Color(0.3,0.9,1,0.22))
		draw_arc(Vector2(57,-65),13 if player.weapons.charge<1.1 else 20,
			player.animation_time*5,player.animation_time*5+TAU,32,Color("b5faff"),3,true)
	draw_set_transform(Vector2.ZERO)
