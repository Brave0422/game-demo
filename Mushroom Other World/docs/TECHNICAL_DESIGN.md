# 技术实现方案

> 2026-10-11 实施更新：已建立可运行游戏模块，实际完成度见 [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)，测试证据见 [validation/IMPLEMENTATION_REPORT.md](validation/IMPLEMENTATION_REPORT.md)。目录、命名、逻辑与用户要求的逐变量/方法/关键节点中文注释，统一执行 [CODING_STANDARDS.md](CODING_STANDARDS.md)。

版本：v0.3，2026-10-11。本文规定目标技术方案，不能代替实际测试记录；当前实现差异在 IMPLEMENTATION_STATUS 中单独列出。玩法与数值以 [PRD.md](PRD.md) 为准。

## 1. 技术栈与运行边界

采用 Godot 4.7.2 标准版、带类型 GDScript、Compatibility 渲染器，Windows x86_64 离线单机。2026-10-11 核对的 [Godot Windows 官方页](https://godotengine.org/download/windows/) 提供该版本；实施时记录实际引擎版本，并使用完全匹配的导出模板。无 C#/.NET、Web 前端、后端服务、数据库或运行时联网依赖；AI 联网只用于开发阶段获取素材。

1280×720 逻辑视口，60 Hz 物理，使用 `canvas_items` 拉伸与保持宽高比的设置，非 16:9 留边。高清素材线性过滤，关闭像素吸附；UI 用锚点与 Container 布局。所有游戏时长和冷却基于物理 `delta`，不得靠渲染帧数计时。

## 2. 模块与场景职责

| 模块 / 场景 | 技术与节点 | 负责内容与对外接口 |
| --- | --- | --- |
| GameSession（Autoload） | GDScript、会话状态枚举 | 角色选择、计时、死亡/手动重试次数、当前快照；`start_run`、`retry_checkpoint`、`finish_run`、`clear_run` |
| SaveService（Autoload） | ConfigFile、`user://settings.cfg` / `records.cfg` | 音量/显示/震动、通关标记与最佳挑战总用时；配置校验，缺失或损坏恢复默认 |
| AudioManager（Autoload） | AudioStreamPlayer、音频总线 | BGM 状态与过渡，UI 音效；世界音效用 AudioStreamPlayer2D，UI 音效不做空间衰减 |
| Player | CharacterBody2D + CollisionShape2D | 共用加速、跳跃缓存、离地宽限、移动平台跟随；输入来自 InputMap |
| PlayerVisual | Sprite2D 分层 + AnimationPlayer，必要时 Skeleton2D | 朝向、跑跳/射击叠加、蓄力、受伤；Marker2D 给出脚底和枪口，视觉不决定伤害 |
| WeaponController | GDScript 策略 + WeaponData Resource | 冷却、瞄准、能量、活动弹体上限、发射请求；成功生成后才扣能量 |
| Health / Hurtbox / Hitbox | 普通组件 + Area2D | 生命、伤害候选、无敌、攻击窗口；`health_changed`、`damage_applied`、`died` 信号 |
| Projectile | Node2D/Area2D + 物理查询 | 弹道、扫掠碰撞、命中去重、穿透、生命周期；不直接访问 UI 或全局修改敌人 HP |
| Enemy | 地面 CharacterBody2D，蝙蝠 Node2D + Area2D | 共用生命与冻结；各类型独立状态转移/攻击策略，由 EnemyData 配置参数 |
| Boss | Node2D + 独立装甲/核心 Area2D + 状态机 | 预警、招式、核心窗口、阶段切换；向 GameSession 提交死亡事件 |
| Level | Node2D + 多个 TileMapLayer + Parallax2D | 静态地形、装饰、背景、镜头区域、稳定对象注册表与出生点 |
| Breakable / Pickup | StaticBody2D + 受击 Area2D / 拾取 Area2D | 顶砖、攻击破坏、一次性掉落，按角色映射资源 |
| MovingPlatform | AnimatableBody2D，物理步驱动 | 端点间往返、搭乘、障碍检测和暂停；不以非物理 Tween 直接瞬移碰撞体 |
| Switch / Gate | Area2D / StaticBody2D | 玩家攻击激活、开门动画、碰撞开关、快照恢复；Boss 门和遭遇战门另由各自控制器管理 |
| EncounterController | GDScript + EncounterData | 有限批次、稳定动态 ID、安全生成点、死亡计数、开门、重试复位 |
| Checkpoint / LevelState | Area2D + 数据快照 | 帧末保存世界状态，重新加载后按 ID 应用状态，不存节点引用 |
| CameraRig | Camera2D + 区域配置 | 前视偏移、平滑、区域边界、Boss 锁屏、小幅震动开关 |
| HUD / Menus | CanvasLayer、Control、Container、Theme | 显示角色状态、焦点导航、菜单输入接管、中文字体；仅通过信号/只读数据刷新 |

静态网格选用 [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)，每个节点表示一层。砖块、箱子、开关和门使用独立 PackedScene，方便稳定 ID、保存状态与即时移除碰撞。首版不做运行时地形生成与导航网格寻路，地面怪用前方墙/地面探针折返，蝙蝠用受限路径与锁定点俯冲。

## 3. 数据契约

静态设计数据使用自定义 Resource / `.tres`，运行时状态放独立实例，不能修改共享 `.tres` 导致重开仍保留上次 HP 或能量。

| 数据 | 最小字段 |
| --- | --- |
| CharacterData | `id, max_hp, speed, acceleration, gravity, jump_speed, visual_scene, default_weapon_id, weapon_slots` |
| WeaponData | `id, projectile_scene, damage, cooldown, speed, energy_cost, capacity, max_active, pierce_count, target_damage_cap`，特殊弹道独立配置 |
| EnemyData | `id, max_hp, movement_speed, detection_range, telegraph_time, attack_time, recovery_time, contact_damage, scene` |
| LevelData | `id, scene, section_ids, checkpoint_ids, encounter_ids, character_drop_map, next_level_id` |
| EncounterData | `id, arena_bounds, gate_ids, waves, spawn_points, backup_spawn_points`，每批具体敌种与序号 |
| DamageEvent | `source_id, target_id, attack_id, amount, damage_kind, hit_position, incoming_direction, physics_tick` |
| CheckpointSnapshot | `schema_version, character_id, level_id, checkpoint_id, spawn_position, equipped_weapon, unlocked_weapons, energies, broken_ids, dead_enemy_ids, collected_ids, pending_pickups, switch_states, gate_states, completed_encounters, committed_content_time, committed_branch_time` |

稳定 ID 例：`level01/s03/crate_a_01`、`level01/e02/wave02/enemy01`、`level01/s03/crate_a_01/drop00`。关卡加载验证重复 ID、未定义武器、缺失出生点/目标门/素材路径；错误日志写出具体对象。`next_level_id` 首版为空。

掉落记录含 ID、类型、数量、位置、安全落点。存储配置是设计值，快照是某次游玩的状态；两者分开。会话快照不写磁盘，保存机制不暗示支持退出后续关。

## 4. 碰撞、伤害与物理顺序

以下数字为 Godot 编辑器中的层编号，不是直接传入 API 的位掩码整数；实际位值为 `1 << (编号 - 1)`。

| 层 | 用途 | 主要检测关系 |
| --- | --- | --- |
| 1 | 实体世界：地形、门、平台、可破坏物实体 | 玩家/地面怪移动碰撞；所有弹体查询阻挡 |
| 2 | 玩家移动身体 | 拾取/检查点/入场触发器检测；不与怪物身体互相阻挡 |
| 3 | 玩家 Hurtbox | 敌方攻击检测，不承担实体碰撞 |
| 4 | 敌人/Boss Hurtbox 与装甲区 | 玩家攻击查询；装甲/核心标签决定能否受伤 |
| 5 | 玩家攻击 | 主动查询 1/4/7，忽略玩家和拾取物 |
| 6 | 敌方攻击/荆棘接触区 | 查询 3，移动弹还查 1；不打怪物、不破坏箱子 |
| 7 | 可攻击机关与破坏物受击区 | 玩家攻击查此层；按规则触发而非一律扣血 |
| 8 | 拾取/检查点/区域触发器 | 查询 2，互相不触发 |
| 9 | 死亡判定区 | 查询 2，忽略普通伤害无敌 |

怪物移动身体可设为层 0、掩码 1，仅和地形碰撞；独立 Hurtbox 在层 4 接收攻击。仅荆棘滚兽常开敌方接触 Hitbox，其他近战区必须受攻击状态控制。装甲和可破坏物实体/受击区可能同时被命中，按同一个对象 ID 去重：先由对象解析护甲/交互，再决定弹体回收；不得先遇实体墙就跳过可破坏物的受击逻辑。

高速弹每个物理步从旧位置到新位置做线段/形状扫掠，宽弹使用形状扫掠；按距离处理命中，先遇墙后面的目标不可受伤。使用 [Godot 物理空间查询](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) 的物理步访问方式；薄墙测试覆盖激光高速和斜向射击。穿透逐个记录命中目标，不反复打同一实例；护甲阻挡优先于穿透计数。扫掠与 Area 信号走同一命中入口，避免双重结算。

同帧处理顺序：收集事件 → 按对象/攻击去重 → 处理物体耐久和护甲 → 聚合目标伤害 → 判定 Boss 胜利或玩家死亡 → 非终局时处理 Boss 阶段切换 → 非终局时提交检查点 → 发出 UI/音频信号与延迟删除节点。Boss 与玩家同帧归零优先胜利；CP 与致死同帧则死亡，不利用 CP 补血撤销死亡。

玩家本帧多个有效伤害取最大一个；敌人按各武器去重规则接受多次命中。`attack_id` 区分一发散弹的整组、切刃去程/返程及火环单次施放，以执行 PRD 的 Boss 伤害上限。玩家无敌期间忽略新伤害；荆棘持续重叠必须按物理步检查，不能只靠首次 `area_entered`。

顶砖使用玩家上一物理步的上升速度和头部/底面碰撞法线判定，不用 `move_and_slide` 后已归零的速度误判；侧面和下降触碰无效。先原子设置 `broken`/`collected` 标记，再延迟移除碰撞和节点，避免同帧多弹复制掉落。

## 5. 状态机、输入与暂停

普通怪共用 `inactive / patrol_or_idle / telegraph / attack / recovery / frozen / dead` 状态框架，各自配置允许路径；滚兽没有攻击循环，其滚动与持续刺壳是独立行为。被冻结时保存必要视觉但取消旧攻击，解冻宽限后回待机/巡逻。Boss 使用 `intro / telegraph / attack / exposed / transition / phase_change / defeated`；状态转换只能通过单一入口，退出时关闭旧攻击区域/计时器，取消旧动画回调。动画配合逻辑状态，不让每帧贴图索引承担核心判定。

InputMap 定义 `move_left/right/up/down, shoot, jump, cycle_weapon, weapon_1..4, pause, ui_accept, ui_cancel`。UI 获得焦点后消费按键；进入关卡时要求释放上一轮确认键再接受射击。失去窗口焦点自动暂停，恢复焦点不自动开火。两方向同时输入为 0。趴下站起用目标站立体积查询头顶，失败则保持趴姿。

按 [Godot 暂停机制](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html) 通过 SceneTree 暂停世界，菜单允许在暂停时处理。世界状态机、平台、物理、动画、冷却、冻结、蓄力、计时和世界声音全部冻结，菜单音效可播放；音乐可继续播放但暂停期间不推进战斗音乐状态。世界 Tween/Timer 的处理模式须随世界暂停，不能使用无条件继续运行的计时器。

暂停期间松开 J 则取消蓄力，恢复不补发；若保持按住，恢复后从暂停前蓄力值继续。重新开始/返回菜单清掉输入锁存与旧连接，不累积多份信号回调。

## 6. 检查点与计时恢复

1. CP 首次激活时，帧末确认未死亡/通关，补满 HP、提交当前段内容/支路计时，按稳定 ID 捕获快照。重复触发不修改。
2. 重试时先停用输入与世界结算，清理当前关卡节点/弹体和所有挂起攻击，保留挑战总用时及累计次数，丢弃失败段内容/支路计时。
3. 加载原关卡和静态对象，应用破坏/死亡/拾取集合、开关与门、已完成遭遇战；未完成遭遇战恢复未触发，平台及活怪回到配置初始状态。
4. 重建未拾取掉落，应用角色装备/能量，满血放入快照安全点并给予 1.5 秒保护；初始化 UI、镜头和环境音乐。
5. 若 CP5 重试，Boss 为全血第一阶段、门开放、音乐为门前环境曲；重新进入才切 Boss 曲。完成后释放输入与物理。

GameSession 维护 `committed_content_time + current_segment_time`，支路有对应独立子计时；通关的主线内容用时为两者之和减支路时间。每次 CP 提交只执行一次，失败段回滚到快照，挑战总用时不回滚。区段 S1–S8 的统计另按区域记录，便于找出过长/过短内容，不将屏幕数乘固定秒数当测量值。

## 7. 资源、音频与工程目录

素材按 [ASSETS.md](ASSETS.md) 搜索、下载、验证和入库，PNG/分层图、必要时矢量源栅格化；透明贴图检查边缘，动画检查锚点。音乐 OGG，短音效 WAV/OGG，字体保留许可证。音乐至少草地/地下城/Boss 三套可循环曲与通关短曲，死亡和菜单反馈另配短音效。

AudioManager 以两个音乐播放器执行约 0.6 秒交叉淡入淡出；同种高频射击音效并发上限默认 4，超出替换最早声音，避免叠音失真。生命归零、重试、暂停、Boss 入场均验证音乐状态；所有音量设置立即生效并保存。

实际工程目录（详细约定见 `project_structure.md`，代码审查规则见 `CODING_STANDARDS.md`）：

```text
scenes/{main,menus,players,enemies,bosses,levels,props,effects,ui}
core/
components/
resources/{characters,weapons,enemies,levels,encounters,themes}
assets/{art,audio,fonts,licenses}
assets/manifest.csv
source_assets/{downloads,unpacked,source_pages}
tools/assets/
tests/
builds/
docs/{PRD.md,TECHNICAL_DESIGN.md,QA_CHECKLIST.md,ASSETS.md,...}
```

## 8. 验证与导出

不强制第三方测试框架；用可由 Godot `--headless` 运行的 GDScript 断言脚本检查能量、去重、快照、计时和状态转换，失败退出非零。涉及物理步和场景加载的测试用引擎测试场景；画风、声音、可躲避性和手感必须实际运行观察。具体步骤见 [QA_CHECKLIST.md](QA_CHECKLIST.md)。

Windows x86_64 导出并在无 Godot 编辑器的环境离线启动，记录引擎、系统、CPU/GPU、分辨率、FPS 及错误日志。压力基线为同屏 5 怪与 80 弹体、目标约 60 FPS；先用分析器找瓶颈，仅在实测有必要时引入弹体对象池，不能为预想性能增加复杂架构。正式工程不包含调试作弊入口与缺失资源路径。
