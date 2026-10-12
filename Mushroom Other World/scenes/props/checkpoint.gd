extends Area2D
## 顺序检查点触发器；生命和快照提交由关卡帧末仲裁。

## 玩家进入时报告序号和安全出生点。
signal reached(index: int, spawn: Vector2)
## CP0～CP5 的序号。
@export var index: int = 0
## 当前是否已成为有效检查点。
var active: bool = false
## 动画累计秒数。
var _time: float = 0.0


## 连接玩家进入，场景配置掩码只检测玩家实体。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	active = index <= GameSession.checkpoint_index


## delta 为物理秒数，用于检查点光环轻微动画。
func _physics_process(delta: float) -> void:
	_time += delta
	active = index <= GameSession.checkpoint_index
	queue_redraw()


## body 为进入的角色；重复检查点不会发出提交请求。
func _on_body_entered(body: Node2D) -> void:
	if body is Player and index > GameSession.checkpoint_index:
		reached.emit(index, global_position)


## 手绘检查点旗帜；点亮时保留独立光环与编号。
func _draw() -> void:
	PaintedArt.decoration(self,"flag",Vector2(18,0),142,
		Color.WHITE if active else Color("b8aea0"))
	if active:
		draw_arc(Vector2(0,-65),49+sin(_time*2)*3,PI,TAU,32,
			Color(0.92,1,0.69,0.40),3,true)
	draw_string(preload("res://assets/fonts/noto_sans_sc_bold.otf"),
		Vector2(-19,-152),"CP%d" % index,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff0b7"))
