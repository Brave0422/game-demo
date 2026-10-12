class_name Health
extends Node
## 统一玩家生命入口：同物理帧伤害取最大，延迟结算允许胜利优先。

## 有效受伤后通知角色击退与表现，origin 是来源世界位置。
signal damaged(amount: int, origin: Vector2)
## 生命归零通知所属角色。
signal died
## HUD 只监听生命变化，不直接写入生命。
signal changed(current: int, maximum: int)
## 最大生命值。
@export var maximum: int = 8
## 当前生命值。
var current: int = 8
## 剩余无敌秒数。
var invulnerability: float = 0.0
## 本帧最大待处理伤害。
var _pending_damage: int = 0
## 最大伤害的来源位置。
var _pending_origin: Vector2 = Vector2.ZERO
## 是否已安排帧末结算，防止重复。
var _scheduled: bool = false


## delta 为物理步秒数；暂停树后自动停止无敌计时。
func _physics_process(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)


## amount 为伤害，origin 为来源，fatal 忽略无敌用于掉坑。
func request_damage(amount: int, origin: Vector2, fatal: bool = false) -> void:
	if current <= 0 or (invulnerability > 0.0 and not fatal):
		return
	if fatal:
		amount = maximum
	if amount > _pending_damage:
		_pending_damage = amount
		_pending_origin = origin
	if not _scheduled:
		_scheduled = true
		_resolve.call_deferred()


## 原子结算本帧最大伤害，开始无敌；随后通知角色。
func _resolve() -> void:
	_scheduled = false
	if _pending_damage <= 0 or current <= 0:
		_pending_damage = 0
		return
	current = maxi(0, current - _pending_damage)
	invulnerability = 1.2
	damaged.emit(_pending_damage, _pending_origin)
	_pending_damage = 0
	changed.emit(current, maximum)
	if current == 0:
		died.emit()


## amount 为回复量；满血返回 false，拾取物应留在场内。
func heal(amount: int) -> bool:
	if current >= maximum or current <= 0:
		return false
	current = mini(maximum, current + amount)
	changed.emit(current, maximum)
	return true


## protection 为出生保护秒数；清除旧帧伤害并补满。
func reset(protection: float = 1.5) -> void:
	current = maximum
	invulnerability = protection
	_pending_damage = 0
	changed.emit(current, maximum)
