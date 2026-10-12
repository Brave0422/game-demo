class_name EnemyData
extends Resource
## 五种普通敌人的静态参数，运行状态由 Enemy 实例维护。

## 敌人机制标识。
@export var id: String = "patrol"
## 中文名称。
@export var display_name: String = "巡逻蘑菇"
## 初始生命。
@export var max_hp: int = 3
## 巡逻速度，单位/秒。
@export var movement_speed: float = 85.0
## 开始预警所需的玩家距离。
@export var detection_range: float = 110.0
## 攻击预警持续秒数。
@export var telegraph_time: float = 0.45
## 攻击有效窗口秒数。
@export var attack_time: float = 0.2
## 攻击后恢复秒数。
@export var recovery_time: float = 0.8
## 常态身体接触伤害；只有滚兽为 1。
@export var contact_damage: int = 0
