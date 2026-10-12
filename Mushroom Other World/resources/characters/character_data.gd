class_name CharacterData
extends Resource
## 角色静态参数；实例生命、武器能量不写回本资源。

## 角色标识：bill 或 mega_man。
@export var id: String = "bill"
## 中文角色名称。
@export var display_name: String = "比尔 · 雷泽"
## 最大生命点数。
@export var max_hp: int = 8
## 最大水平速度，单位/秒。
@export var speed: float = 320.0
## 地面水平加速度，单位/秒²。
@export var acceleration: float = 2400.0
## 空中水平加速度，单位/秒²。
@export var air_acceleration: float = 1800.0
## 无输入时减速度，单位/秒²。
@export var deceleration: float = 2800.0
## 重力加速度，单位/秒²。
@export var gravity: float = 1800.0
## 起跳速度，向上为负。
@export var jump_speed: float = -820.0
