extends Node
## 双播放器交叉淡入淡出与有界音效池；世界音效暂停，菜单音乐可继续。

## 各环境已下载音乐路径。
const MUSIC: Dictionary = {
	"grassland": "res://assets/audio/music/grassland/a_new_day.ogg",
	"dungeon": "res://assets/audio/music/dungeon/mysterious_orchestral_theme.ogg",
	"boss": "res://assets/audio/music/boss/boss_battle_02_part_01.ogg",
	"victory": "res://assets/audio/jingles/pizzicato_jingles/jingles_pizzi00.ogg",
}
## 音效事件到已有文件路径映射。
var sfx_paths: Dictionary = {}
## 两个音乐播放器用于交叉淡化。
var _music_players: Array[AudioStreamPlayer] = []
## 当前音乐播放器下标。
var _active: int = 0
## 当前环境 ID，防止重复重启同曲。
var _music_id: String = ""
## 当前淡化动画句柄，快速切场时取消旧动画。
var _fade: Tween
## 同类事件最多四个声音，避免连射叠音失真。
var _voices: Dictionary = {}
## Headless 无声测试没有实际音频设备，不启动解码线程；有窗口运行完整播放链。
var _audio_available: bool = DisplayServer.get_name() != "headless"


## 创建两个非空间音乐节点，音频总线与设置服务保持一致。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# index 标识两条交叉淡化轨道。
	for index: int in range(2):
		# music_player 只负责 BGM，不受场景树暂停影响。
		var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
		music_player.name = "MusicTrack%d" % index
		music_player.bus = "Music"
		add_child(music_player)
		_music_players.append(music_player)
	sfx_paths = {
		"shoot": "res://assets/audio/sfx/weapons/laser1.ogg",
		"jump": "res://assets/audio/sfx/ui/rollover1.ogg",
		"hit": "res://assets/audio/sfx/impacts/impact_soft_light_000.ogg",
		"hurt": "res://assets/audio/sfx/impacts/impact_soft_heavy_000.ogg",
		"break": "res://assets/audio/sfx/impacts/impact_wood_medium_000.ogg",
		"armor": "res://assets/audio/sfx/ui/click4.ogg",
		"warning": "res://assets/audio/sfx/ui/rollover3.ogg",
		"spore": "res://assets/audio/sfx/weapons/laser5.ogg",
		"pickup": "res://assets/audio/sfx/ui/switch15.ogg",
		"checkpoint": "res://assets/audio/sfx/ui/switch25.ogg",
		"death": "res://assets/audio/jingles/pizzicato_jingles/jingles_pizzi02.ogg",
		"ui": "res://assets/audio/sfx/ui/click1.ogg",
	}
	# event_id 为白名单事件；缺少命名时使用已经核验存在的短音，保留映射可审查。
	for event_id: String in sfx_paths:
		if not ResourceLoader.exists(sfx_paths[event_id]):
			sfx_paths[event_id] = "res://assets/audio/sfx/ui/click2.ogg"


## id 为环境标识；两路音乐在 0.6 秒内交叉淡化。
func change_music(id: String) -> void:
	if id == _music_id or not MUSIC.has(id):
		return
	_music_id = id
	if not _audio_available:
		return
	if _fade:
		_fade.kill()
	# old 是待淡出的轨道索引。
	var old: int = _active
	_active = 1 - _active
	# stream 是本次播放独立副本，仅副本设置循环。
	var stream: AudioStreamOggVorbis = load(MUSIC[id]).duplicate()
	stream.loop = id != "victory"
	_music_players[_active].stream = stream
	_music_players[_active].volume_db = -50.0
	_music_players[_active].play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(_music_players[old], "volume_db", -50.0, 0.6)
	_fade.tween_property(_music_players[_active], "volume_db", -4.0, 0.6)
	_fade.chain().tween_callback(_music_players[old].stop)


## event_id 为声音类型，position 为世界坐标；ui=true 使用不衰减的菜单声音。
func play_sfx(event_id: String, position: Vector2 = Vector2.ZERO, ui: bool = false) -> void:
	if not sfx_paths.has(event_id) or not _audio_available:
		return
	if not _voices.has(event_id):
		_voices[event_id] = []
	# voices 过滤已结束对象，最多保留四个同类声音。
	var voices: Array = _voices[event_id].filter(
		func(reference: WeakRef) -> bool:
			return reference.get_ref() != null and not reference.get_ref().is_queued_for_deletion()
	)
	if voices.size() >= 4:
		# oldest 为即将替换的最老声音，先释放播放流再删节点。
		var oldest: Node = voices.pop_front().get_ref()
		oldest.stop()
		oldest.stream = null
		oldest.queue_free()
	# voice 根据使用场景选择空间播放器，节点生命周期短且自动清理。
	var voice: Node = AudioStreamPlayer.new() if ui else AudioStreamPlayer2D.new()
	voice.name = "SoundEffect"
	voice.stream = load(sfx_paths[event_id])
	voice.bus = "UI" if ui else "SFX"
	voice.volume_db = -16.0 if event_id == "shoot" else -7.0
	voice.process_mode = Node.PROCESS_MODE_ALWAYS if ui else Node.PROCESS_MODE_PAUSABLE
	if not ui:
		voice.position = position
		voice.max_distance = 1000.0
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
	voices.append(weakref(voice))
	_voices[event_id] = voices


## 离开关卡或重试时终止旧世界音效，避免声音随 Autoload 残留。
func clear_world_sounds() -> void:
	# voices 是每种事件对应的有限声音实例集合。
	for voices: Array in _voices.values():
		# voice 可能已自动释放，必须先验证。
		for reference: WeakRef in voices:
			if reference.get_ref() != null:
				reference.get_ref().stop()
				reference.get_ref().stream = null
				reference.get_ref().queue_free()
	_voices.clear()


## 主动停止所有播放与淡化，应用退出前调用以给音频线程留出回收时间。
func stop_all() -> void:
	if _fade:
		_fade.kill()
	_music_id = ""
	clear_world_sounds()
	# music_player 为两条环境轨道，停止后清除共享资源引用。
	for music_player: AudioStreamPlayer in _music_players:
		music_player.stop()
		music_player.stream = null


## 非正常场景树退出时也进行幂等清理；正常关闭会先调用 stop_all。
func _exit_tree() -> void:
	stop_all()
