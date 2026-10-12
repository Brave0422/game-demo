class_name Breakable
extends StaticBody2D
## 三类破坏规则共用原子入口：砖仅顶破、箱仅攻击、裂纹二者皆可。

## 破坏通知关卡保存状态与生成唯一掉落。
signal broken(stable_id: String, drop: String, position: Vector2)
## 稳定实例 ID。
@export var stable_id: String = ""
## brick、crate、cracked 三种交互类型。
@export_enum("brick", "crate", "cracked") var kind: String = "crate"
## 空字符串无掉落；A～D 为武器槽；small/large/energy 为补给。
@export var drop: String = "A"
## 实例耐久。
var hp: int = 3
## 原子破坏标记，延迟删除前阻止重复发奖。
var is_broken: bool = false
## 已下载木箱贴图。
var _crate_texture: Texture2D = preload(
	"res://assets/art/environment/grassland/nature/object/crate.png"
)


## 按交互种类初始化耐久。
func _ready() -> void:
	add_to_group("breakables")
	hp = 3 if kind == "crate" else 2
	queue_redraw()


## 只由玩家上升时的底面碰撞调用，箱子拒绝顶撞。
func hit_from_below() -> void:
	if kind != "crate":
		_break()


## projectile 为玩家弹体；冰刃对可破坏物仍扣 1 耐久。
func receive_projectile(projectile: Projectile) -> String:
	if is_broken:
		return "hit"
	if kind == "brick":
		AudioManager.play_sfx("armor", global_position)
		return "blocked"
	hp -= 1 if projectile.kind == "ice" else projectile.damage
	if hp <= 0:
		_break()
	return "blocked"


## 标记、发信号、关碰撞、删节点的顺序保证同帧多弹只掉一次。
func _break() -> void:
	if is_broken:
		return
	is_broken = true
	broken.emit(stable_id, drop, global_position)
	$BodyShape.set_deferred("disabled", true)
	AudioManager.play_sfx("break", global_position)
	queue_free()


## 箱上文字表示可获得内容，砖和裂纹有不同纹理。
func _draw() -> void:
	if kind == "crate":
		draw_texture_rect(_crate_texture, Rect2(-32, -32, 64, 64), false)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-9, 9),
			drop,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			25,
			Color("fff4c3")
		)
	else:
		draw_rect(Rect2(-32, -32, 64, 64), Color("a07c68") if kind == "brick" else Color("a9bdc0"))
		draw_rect(Rect2(-32, -32, 64, 64), Color("43585d"), false, 4)
		if kind == "brick":
			draw_line(Vector2(-30, 0), Vector2(30, 0), Color("675253"), 4)
			draw_line(Vector2(0, -30), Vector2(0, 0), Color("675253"), 4)
		else:
			draw_polyline(
				PackedVector2Array(
					[Vector2(8, -30), Vector2(-8, -10), Vector2(6, 0), Vector2(-12, 28)]
				),
				Color("43585d"),
				5,
				true
			)
