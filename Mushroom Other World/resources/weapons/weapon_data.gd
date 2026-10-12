class_name WeaponData
extends Resource
## 武器设计参数；弹道使用 kind 分派，库存由 WeaponController 独立维护。

## 唯一武器标识。
@export var id: String = "contra_default"
## HUD 中文名称。
@export var display_name: String = "普通枪"
## 弹道类型：straight、spread、laser、wave、cutter、ice、fire。
@export var kind: String = "straight"
## 每颗射弹基础伤害。
@export var damage: int = 1
## 成功发射的最短间隔，秒。
@export var cooldown: float = 0.18
## 弹体速度，单位/秒。
@export var speed: float = 900.0
## 每次成功发射消耗的独立能量。
@export var energy_cost: int = 0
## 特殊武器最大能量。
@export var capacity: int = 28
## 最多穿透不同普通目标数量。
@export var pierce_count: int = 1
## 场上最大同类弹体数，0 为不限制。
@export var max_active: int = 0
## 同次攻击对 Boss 的伤害上限，0 为不限制。
@export var target_damage_cap: int = 0
## 弹体视觉和 HUD 颜色。
@export var tint: Color = Color("ffd577")
