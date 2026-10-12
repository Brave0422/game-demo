class_name WeaponController
extends Node
## 两角色武器库存、输入节奏和发射事务；弹体由所属关卡持有。

## 装备或能量变化通知 UI。
signal changed
## 短提示交给 HUD 展示。
signal hint_requested(message: String)
## 弹体独立场景。
const PROJECTILE: PackedScene = preload("res://scenes/effects/projectile.tscn")
## 比尔按箱槽 A～D 映射。
const BILL_DROPS: Array[String] = ["contra_s", "contra_l", "contra_f", "contra_m"]
## 洛克人四槽固定顺序。
const MEGA_SLOTS: Array[String] = ["mega_buster", "mega_cutter", "mega_ice", "mega_fire"]
## 父节点注入的玩家，不通过绝对路径查找。
var player: Player
## 当前武器 ID。
var equipped: String = "contra_default"
## 独立已解锁武器列表。
var unlocked: Array[String] = []
## 特殊武器 ID 到剩余能量的映射。
var energies: Dictionary = {}
## ID 到只读 WeaponData 的缓存。
var catalog: Dictionary = {}
## 剩余发射冷却秒数。
var cooldown: float = 0.0
## 基础炮本次持续蓄力秒数。
var charge: float = 0.0
## 本次射击键是否正在蓄力。
var charging: bool = false
## 发射批次递增计数，用于散弹及火环伤害上限。
var _attack_sequence: int = 0


## actor 注入玩家；按角色初始化独立库存。
func setup(actor: Player) -> void:
	player = actor
	# id 对应一份独立可编辑的静态武器资源。
	for id: String in [
		"contra_default",
		"contra_m",
		"contra_s",
		"contra_l",
		"contra_f",
		"mega_buster",
		"mega_cutter",
		"mega_ice",
		"mega_fire"
	]:
		catalog[id] = load("res://resources/weapons/%s.tres" % id)
	equipped = "contra_default" if player.data.id == "bill" else "mega_buster"
	unlocked.assign([equipped])
	changed.emit()


## delta 为物理秒数；玩家只有在场内输入解锁时调用。
func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if player.data.id == "mega_man":
		if Input.is_action_just_pressed("cycle_weapon"):
			select_weapon(unlocked[(unlocked.find(equipped) + 1) % unlocked.size()])
		# slot_index 为数字键固定槽位，未解锁的选择请求会被拒绝。
		for slot_index: int in range(4):
			if Input.is_action_just_pressed("weapon_%d" % (slot_index + 1)):
				select_weapon(MEGA_SLOTS[slot_index])
	if equipped == "mega_buster":
		if Input.is_action_just_pressed("shoot"):
			fire(0)
			charging = true
			charge = 0.0
		if charging and Input.is_action_pressed("shoot"):
			charge += delta
		if charging and Input.is_action_just_released("shoot"):
			if charge >= 0.4:
				fire(2 if charge >= 1.1 else 1)
			cancel_charge()
	elif Input.is_action_pressed("shoot"):
		fire(0)


## level 是蓄力等级 0/1/2；返回是否成功生成，失败不扣能量。
func fire(level: int = 0) -> bool:
	if cooldown > 0.0 and level == 0:
		return false
	# spec 是共享只读参数，蓄力修正只传给弹体实例。
	var spec: WeaponData = catalog[equipped]
	# active_count 只统计本玩家、相同弹槽的存活弹体。
	var active_count: int = 0
	# projectile 是场景树中仍占用槽位的弹体。
	for projectile: Node in get_tree().get_nodes_in_group("player_projectiles"):
		if projectile.shooter == player and projectile.weapon_id == equipped:
			if equipped != "mega_buster" or (projectile.charge_level > 0) == (level > 0):
				active_count += 1
	# limit 是基础炮普通与蓄力分别计算后的活动上限。
	var limit: int = spec.max_active
	if equipped == "mega_buster":
		limit = 1 if level > 0 else 3
	if limit > 0 and active_count >= limit:
		hint_requested.emit("弹体尚未回收")
		return false
	if spec.energy_cost > int(energies.get(equipped, 0)):
		select_weapon("mega_buster")
		hint_requested.emit("能量不足，已切回基础炮")
		return false
	_attack_sequence += 1
	# attack_id 为本次攻击组，五颗散弹和火球/火环共享。
	var attack_id: String = "%s/%d" % [player.get_instance_id(), _attack_sequence]
	# angles 为当前武器本次发射的偏转角度。
	var angles: PackedFloat32Array = PackedFloat32Array(
		[-20.0, -10.0, 0.0, 10.0, 20.0] if spec.kind == "spread" else [0.0]
	)
	# angle 是归一化瞄准向量的旋转角，斜向不改变速度。
	for angle: float in angles:
		_spawn(spec, player.aim_direction().rotated(deg_to_rad(angle)), level, attack_id)
	if spec.kind == "fire":
		# ring 为独立火环弹体；与火球共用 Boss 伤害总额。
		var ring: Projectile = PROJECTILE.instantiate()
		ring.configure(spec, player, Vector2.RIGHT, 0, attack_id)
		ring.kind = "ring"
		ring.damage = 1
		player.get_parent().add_child(ring)
		ring.global_position = player.global_position + Vector2(0, -48)
	if spec.energy_cost > 0:
		energies[equipped] = int(energies[equipped]) - spec.energy_cost
	cooldown = spec.cooldown
	AudioManager.play_sfx("shoot", player.global_position)
	changed.emit()
	return true


## spec 为静态参数，direction 为单位方向，level 为蓄力级别，attack_id 为去重组。
func _spawn(spec: WeaponData, direction: Vector2, level: int, attack_id: String) -> void:
	# projectile 在关卡层持有，避免随角色视觉翻转而改变坐标。
	var projectile: Projectile = PROJECTILE.instantiate()
	projectile.configure(spec, player, direction, level, attack_id)
	player.get_parent().add_child(projectile)
	projectile.global_position = player.muzzle.global_position
	# muzzle_query 检查肩部到枪口，防止贴墙时枪口伸到墙后而越墙生成子弹。
	var muzzle_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		player.global_position + Vector2(0, -24 if player.crouched else -65),
		player.muzzle.global_position,
		1
	)
	muzzle_query.hit_from_inside = true
	# obstruction 为枪管路径中最近实体，发射点收回到其外侧。
	var obstruction: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(
		muzzle_query
	)
	if not obstruction.is_empty():
		projectile.global_position = obstruction["position"] - direction * 2.0
	projectile.start_position = projectile.global_position


## id 为目标武器；切换取消蓄力但不删除已发弹体。
func select_weapon(id: String) -> void:
	if not unlocked.has(id):
		return
	equipped = id
	cancel_charge()
	changed.emit()


## slot 为箱槽 A/B/C/D；返回显示用武器名称。
func collect_weapon(slot: String) -> String:
	# index 是箱槽到角色专属资源的索引。
	var index: int = maxi(0, "ABCD".find(slot))
	# id 根据角色映射，D 对洛克人重复回旋切刃。
	var id: String = (
		BILL_DROPS[index]
		if player.data.id == "bill"
		else MEGA_SLOTS[1 if index == 3 else index + 1]
	)
	if player.data.id == "bill":
		unlocked.assign([id])
		equipped = id
	elif unlocked.has(id):
		energies[id] = mini(28, int(energies[id]) + 14)
	else:
		unlocked.append(id)
		energies[id] = 28
		equipped = id
	cancel_charge()
	changed.emit()
	return catalog[id].display_name


## 回复能量 8 点；无可回复目标返回 false，拾取物保留。
func collect_energy() -> bool:
	# target 是当前未满武器，或槽位顺序下最低能量武器。
	var target: String = equipped if energies.has(equipped) and int(energies[equipped]) < 28 else ""
	if target.is_empty():
		# id 按固定槽位遍历，相同能量时保留靠前槽。
		for id: String in MEGA_SLOTS:
			if energies.has(id) and int(energies[id]) < 28:
				if target.is_empty() or int(energies[id]) < int(energies[target]):
					target = id
	if target.is_empty():
		return false
	energies[target] = mini(28, int(energies[target]) + 8)
	changed.emit()
	return true


## 取消蓄力，不触发松手补发。
func cancel_charge() -> void:
	charging = false
	charge = 0.0


## 返回不含节点引用的独立装备数据。
func capture() -> Dictionary:
	return {
		"equipped": equipped, "unlocked": unlocked.duplicate(), "energies": energies.duplicate()
	}


## state 为检查点保存的装备数据；恢复不会修改共享资源。
func restore(state: Dictionary) -> void:
	equipped = state["equipped"]
	unlocked.assign(state["unlocked"])
	energies = state["energies"].duplicate()
	cooldown = 0.0
	cancel_charge()
	changed.emit()
