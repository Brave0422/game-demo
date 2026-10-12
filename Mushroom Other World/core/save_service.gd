extends Node
## 只持久化设置与角色成绩，不保存检查点会话。

## 配置持久化文件路径。
const SETTINGS_PATH: String = "user://settings.cfg"
## 成绩持久化文件路径。
const RECORDS_PATH: String = "user://records.cfg"
## 设置默认值与当前值，音量范围 0～1。
var settings: Dictionary = {
	"Master": 0.8, "Music": 0.45, "SFX": 0.7, "fullscreen": false, "shake": true
}


## 启动读取并校验设置；损坏、缺失或错误类型回到默认值。
func _ready() -> void:
	# 配置解析器只在本次读取中使用。
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		# key 对应每个已知设置；未知键不会污染运行参数。
		for key: String in settings:
			# value 是未经信任的磁盘值，需验证类型。
			var value: Variant = config.get_value("settings", key, settings[key])
			if typeof(value) == typeof(settings[key]):
				settings[key] = clampf(value, 0.0, 1.0) if value is float else value
	apply_settings()


## 将已校验设置应用到音频总线和窗口模式。
func apply_settings() -> void:
	# bus 为与项目 AudioBusLayout 一致的总线名。
	for bus: String in ["Master", "Music", "SFX"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(settings[bus]))
	DisplayServer.window_set_mode(
		(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if settings["fullscreen"]
			else DisplayServer.WINDOW_MODE_WINDOWED
		)
	)


## key 为设置名，value 为新值；立即应用并保存。
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	# config 按白名单保存，不含任何会话快照。
	var config: ConfigFile = ConfigFile.new()
	# setting_key 为待保存设置的名称。
	for setting_key: String in settings:
		config.set_value("settings", setting_key, settings[setting_key])
	config.save(SETTINGS_PATH)


## character_id 为通关角色，seconds 为包含失败尝试的挑战总时间。
func record_clear(character_id: String, seconds: float) -> void:
	# records 保存每角色最好成绩；损坏文件会被新成绩修复。
	var records: ConfigFile = ConfigFile.new()
	records.load(RECORDS_PATH)
	# previous 为旧成绩，错误类型回退到本次成绩。
	var previous: Variant = records.get_value(character_id, "best_seconds", seconds)
	if not (previous is float or previous is int):
		previous = seconds
	records.set_value(character_id, "cleared", true)
	records.set_value(character_id, "best_seconds", minf(float(previous), seconds))
	records.save(RECORDS_PATH)
