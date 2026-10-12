class_name EncounterData
extends Resource
## 有限遭遇战静态配置；每场两批三只，不做无限刷新。

## 稳定遭遇战 ID。
@export var id: String = "e1"
## 第一批敌种。
@export var first_wave: PackedStringArray = ["patrol", "patrol", "spitter"]
## 第二批敌种。
@export var second_wave: PackedStringArray = ["patrol", "beetle", "beetle"]
## 场地宽度，生成点与两端门都相对于场景根节点。
@export var width: float = 1280.0
