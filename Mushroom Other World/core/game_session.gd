extends Node
## 会话与成功段计时；快照仅在内存保存，世界由 Level 按稳定 ID 恢复。

## 检查点提交后通知 HUD。
signal checkpoint_changed(index: int)
## 当前选择角色。
var character_id: String = "bill"
## 当前最高检查点序号，-1 表示尚未建立起点。
var checkpoint_index: int = -1
## 不含 Node 引用的深拷贝快照。
var snapshot: Dictionary = {}
## 已提交成功段秒数。
var committed_time: float = 0.0
## 当前未提交段秒数。
var segment_time: float = 0.0
## 已提交支路额外秒数。
var committed_branch: float = 0.0
## 当前段支路秒数。
var segment_branch: float = 0.0
## 包含所有失败尝试的可操作时间。
var total_time: float = 0.0
## 实际死亡次数。
var deaths: int = 0
## 手动重试次数，与死亡分开。
var retries: int = 0
## S1～S8 当前成功尝试时间。
var section_times: Array[float] = []
## 当前段提交时的分段统计，用于失败回滚。
var _committed_sections: Array[float] = []


## id 为选择角色；清空上一局所有状态。
func start_run(id: String) -> void:
	character_id = id
	checkpoint_index = -1
	snapshot = {}
	committed_time = 0.0
	segment_time = 0.0
	committed_branch = 0.0
	segment_branch = 0.0
	total_time = 0.0
	deaths = 0
	retries = 0
	section_times.assign([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	_committed_sections = section_times.duplicate()


## delta 为物理秒数，section 为当前区段，branch 表示是否在可选支路。
func tick(delta: float, section: int, branch: bool) -> void:
	total_time += delta
	segment_time += delta
	section_times[section] += delta
	if branch:
		segment_branch += delta


## index 必须比已有序号大；state 为帧末生成的世界及装备数据。
func commit_checkpoint(index: int, state: Dictionary) -> bool:
	if index <= checkpoint_index:
		return false
	checkpoint_index = index
	committed_time += segment_time
	committed_branch += segment_branch
	segment_time = 0.0
	segment_branch = 0.0
	_committed_sections = section_times.duplicate()
	snapshot = state.duplicate(true)
	snapshot["schema_version"] = 1
	snapshot["character_id"] = character_id
	snapshot["level_id"] = "mushroom_world"
	snapshot["checkpoint_id"] = "CP%d" % index
	snapshot["committed_content_time"] = committed_time
	snapshot["committed_branch_time"] = committed_branch
	checkpoint_changed.emit(index)
	return true


## manual 表示手动重试；保留总挑战时间，回滚失败段。
func retry_checkpoint(manual: bool) -> void:
	if manual:
		retries += 1
	segment_time = 0.0
	segment_branch = 0.0
	section_times = _committed_sections.duplicate()


## 返回不含支路的成功主线用时，单位秒。
func content_time() -> float:
	return committed_time + segment_time - committed_branch - segment_branch


## 秒数格式化为菜单和结算共用的分秒文本。
func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## 离开会话时清空检查点与尝试统计；磁盘只保留设置和成绩。
func clear_run() -> void:
	start_run(character_id)
