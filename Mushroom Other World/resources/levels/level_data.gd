class_name LevelData
extends Resource
## 首关静态标识及分段边界；地形与对象由编辑器可见的场景保存。

## 稳定关卡 ID。
@export var id: String = "mushroom_world"
## 关卡水平范围。
@export var width: float = 43520.0
## 八区段左边界，单位与世界坐标一致。
@export var section_starts: PackedFloat32Array = [0, 3840, 10240, 16640, 21760, 29440, 38400, 42240]
## 各区中文标题，与 section_starts 一一对应。
@export var section_names: PackedStringArray = [
	"初见蘑菇原", "草地错落平台", "荆棘溪谷", "林地前哨", "地下回廊", "孢子工坊", "门前整备", "孢子大王"
]
## 下一关标识；空字符串表示首版最终关。
@export var next_level_id: String = ""
