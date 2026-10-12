class_name Pickup
extends Area2D
## 固定补给与箱子掉落；不随机、不超时消失，满血/满能量保留。

## 成功拾取后通知关卡写入唯一 ID 集合。
signal collected(stable_id: String, message: String)
## 稳定对象标识，箱掉落使用来源 ID/drop00。
@export var stable_id: String = ""
## A/B/C/D、small、large、energy。
# 道具类型决定恢复生命、补充能量或角色专属武器映射。
@export var kind: String = "small"
## 所属关卡提供玩家引用。
var player: Player
## 掉坑时恢复的位置。
var safe_position: Vector2 = Vector2.ZERO
## 动画累计物理时间。
var _time: float = 0.0
## 防止同帧重复拾取。
var _collected: bool = false


## 保存安全位置并注册检查点可捕获组。
func _ready() -> void:
	add_to_group("pickups")
	safe_position = global_position


## delta 为物理秒数；持续重叠也会在回复出现需求后重新尝试拾取。
func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _collected or not is_instance_valid(player) or player.health.current <= 0:
		return
	if global_position.y > 900:
		global_position = safe_position
	if not overlaps_body(player):
		return
	# accepted 表示本次道具实际产生效果。
	var accepted: bool = false
	# message 为拾取后显示的中文反馈。
	var message: String = ""
	if kind in ["A", "B", "C", "D"]:
		message = player.weapons.collect_weapon(kind)
		accepted = true
	elif kind == "energy":
		accepted = (
			player.weapons.collect_energy()
			if player.data.id == "mega_man"
			else player.health.heal(2)
		)
		message = "能量恢复" if player.data.id == "mega_man" else "生命 +2"
	else:
		accepted = player.health.heal(4 if kind == "large" else 2)
		message = "生命恢复"
	if accepted:
		_collected = true
		collected.emit(stable_id, message)
		AudioManager.play_sfx("pickup", global_position)
		queue_free()


## 将尚未拾取的实例序列化；只包含值类型。
func capture() -> Dictionary:
	return {"id": stable_id, "kind": kind, "position": global_position, "safe": safe_position}


## 图标使用颜色与符号双重区分，武器显示当前角色映射后的字母/名称缩写。
func _draw() -> void:
	# bob 是仅视觉浮动，不改变拾取碰撞位置。
	var bob: Vector2 = Vector2(0, sin(_time * 3) * 4)
	# weapon 表示武器掉落而非回复。
	var weapon: bool = kind in ["A", "B", "C", "D"]
	# tint 为道具分类色。
	var tint: Color = (
		Color("ffdd83") if weapon else (Color("85daf4") if kind == "energy" else Color("ed8c89"))
	)
	draw_circle(bob, 25, Color("324e53"))
	draw_circle(bob, 21, tint)
	# caption 默认为回复符号，武器按角色映射显示。
	var caption: String = "+" if not weapon else kind
	if kind == "energy":
		caption = "E"
	if weapon and is_instance_valid(player):
		caption = (
			{"A": "S", "B": "L", "C": "F", "D": "M"}[kind]
			if player.data.id == "bill"
			else {"A": "刃", "B": "冰", "C": "火", "D": "刃"}[kind]
		)
	draw_string(
		preload("res://assets/fonts/noto_sans_sc_bold.otf"),
		bob + Vector2(-12, 10),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		25,
		Color("31434e")
	)
