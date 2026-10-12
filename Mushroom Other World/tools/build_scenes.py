"""离线生成可编辑 .tscn/.tres 初稿；游戏运行时不执行地图生成。"""
from pathlib import Path
import json

# 项目根目录，所有生成输出固定在此目录内。
ROOT = Path(__file__).resolve().parents[1]


def write(path: str, content: str) -> None:
    """path 为相对输出路径，content 为 UTF-8 文本。"""
    # target 为已限制在工程内的输出位置。
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content.strip() + "\n", encoding="utf-8", newline="\n")


def resource(folder: str, name: str, type_name: str, values: str) -> None:
    """生成静态资源；参数含义由关联 Resource 导出属性的中文注释定义。"""
    write(f"resources/{folder}/{name}.tres", f'''[gd_resource type="Resource" script_class="{type_name}" load_steps=2 format=3]
[ext_resource type="Script" path="res://resources/{folder}/{type_name_to_file(type_name)}.gd" id="1"]
[resource]
script = ExtResource("1")
{values}
''')


def type_name_to_file(type_name: str) -> str:
    """把资源类名转换为脚本 snake_case 文件名。"""
    # names 是明确的资源脚本映射，避免自动拆词歧义。
    names = {"CharacterData": "character_data", "WeaponData": "weapon_data", "EnemyData": "enemy_data", "LevelData": "level_data", "EncounterData": "encounter_data"}
    return names[type_name]


def simple_scene(path: str, name: str, node_type: str, script: str, properties: str = "", extra: str = "", shapes: str = "") -> None:
    """生成独立场景骨架，关键节点职责保存到 editor_description。"""
    write(path, f'''[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://{script}" id="1"]
{shapes}
[node name="{name}" type="{node_type}"]
editor_description = "独立功能场景；行为与依赖见同目录脚本的中文注释。"
script = ExtResource("1")
{properties}
{extra}''')


def shape(name: str, width: int, height: int) -> str:
    """生成矩形碰撞资源，name 为局部资源 ID。"""
    return f'[sub_resource type="RectangleShape2D" id="{name}"]\nsize = Vector2({width}, {height})\n'


def collision(name: str, parent: str, resource_id: str, y: int, description: str) -> str:
    """生成带职责说明的碰撞节点；y 为相对父节点的垂直偏移。"""
    return f'''[node name="{name}" type="CollisionShape2D" parent="{parent}"]
editor_description = "{description}"
position = Vector2(0, {y})
shape = SubResource("{resource_id}")
'''


def generate_resources() -> None:
    """将 PRD 默认数值转换为独立可审查资源，不包含运行状态。"""
    resource("characters", "bill", "CharacterData", 'id = "bill"\ndisplay_name = "比尔 · 雷泽"')
    resource("characters", "mega_man", "CharacterData", 'id = "mega_man"\ndisplay_name = "经典洛克人"')
    # weapons 每行依次为 ID、名称、弹道、伤害、间隔、速度、耗能、穿透、活动上限、Boss 总额。
    weapons = [
        ("contra_default", "普通枪", "straight", 1, .18, 900, 0, 1, 0, 0),
        ("contra_m", "M 机枪", "straight", 1, .10, 900, 0, 1, 0, 0),
        ("contra_s", "S 散弹", "spread", 1, .32, 900, 0, 1, 0, 2),
        ("contra_l", "L 激光", "laser", 3, .45, 1200, 0, 3, 0, 0),
        ("contra_f", "F 火球", "wave", 3, .40, 650, 0, 1, 0, 0),
        ("mega_buster", "基础炮", "straight", 1, .18, 900, 0, 1, 3, 0),
        ("mega_cutter", "回旋切刃", "cutter", 2, .55, 500, 2, 1, 1, 0),
        ("mega_ice", "冰冻波", "ice", 0, .45, 650, 2, 1, 0, 0),
        ("mega_fire", "火焰风暴", "fire", 3, .50, 700, 3, 1, 0, 4),
    ]
    # row 为一份只读武器配置，字段与上方注释顺序一致。
    for row in weapons:
        # values 为序列化字段，颜色只影响显示。
        values = f'id = "{row[0]}"\ndisplay_name = "{row[1]}"\nkind = "{row[2]}"\ndamage = {row[3]}\ncooldown = {row[4]}\nspeed = {row[5]}.0\nenergy_cost = {row[6]}\npierce_count = {row[7]}\nmax_active = {row[8]}\ntarget_damage_cap = {row[9]}'
        if row[2] == "ice":
            values += '\ntint = Color(0.56, 0.9, 1, 1)'
        resource("weapons", row[0], "WeaponData", values)
    # enemies 每行是 ID、名称、HP、速度、检测距离、预警、攻击、恢复、接触伤害。
    enemies = [
        ("patrol", "巡逻蘑菇", 3, 85, 110, .45, .2, .8, 0),
        ("spitter", "喷吐蘑菇", 5, 0, 540, .55, .1, 1.75, 0),
        ("bat", "飞行蝙蝠", 3, 100, 360, .5, .8, .6, 0),
        ("roller", "荆棘滚兽", 4, 120, 0, 0, 0, .5, 1),
        ("beetle", "盾壳甲虫", 6, 55, 180, .6, .2, 1.4, 0),
    ]
    # row 为本次生成的敌人静态参数。
    for row in enemies:
        resource("enemies", row[0], "EnemyData", f'id = "{row[0]}"\ndisplay_name = "{row[1]}"\nmax_hp = {row[2]}\nmovement_speed = {row[3]}.0\ndetection_range = {row[4]}.0\ntelegraph_time = {row[5]}\nattack_time = {row[6]}\nrecovery_time = {row[7]}\ncontact_damage = {row[8]}')
    resource("levels", "mushroom_world", "LevelData", "")
    resource("encounters", "e1", "EncounterData", 'id = "e1"')
    resource("encounters", "e2", "EncounterData", 'id = "e2"\nfirst_wave = PackedStringArray("bat", "bat", "spitter")\nsecond_wave = PackedStringArray("roller", "beetle", "spitter")')


def generate_components() -> None:
    """生成独立的玩家、武器、敌人、道具和机关 PackedScene。"""
    write("scenes/effects/projectile.tscn", '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scenes/effects/projectile.gd" id="1"]
[node name="Projectile" type="Node2D"]
editor_description = "弹体：物理步扫掠，不依赖 Area 信号重复结算。"
script = ExtResource("1")
z_index = 8
''')
    write("scenes/players/player.tscn", f'''[gd_scene load_steps=9 format=3]
[ext_resource type="Script" path="res://scenes/players/player.gd" id="1"]
[ext_resource type="Script" path="res://components/health.gd" id="2"]
[ext_resource type="Script" path="res://scenes/players/weapon_controller.gd" id="3"]
[ext_resource type="Script" path="res://scenes/players/player_visual.gd" id="4"]
[ext_resource type="Resource" path="res://resources/characters/bill.tres" id="5"]
{shape("body", 42, 88)}
{shape("hurt", 42, 88)}
[node name="Player" type="CharacterBody2D"]
editor_description = "脚底锚点角色；仅与世界实体碰撞，不与怪物互相推挤。"
collision_layer = 2
collision_mask = 1
floor_snap_length = 8.0
platform_on_leave = 2
z_index = 5
script = ExtResource("1")
data = ExtResource("5")
{collision("BodyShape", ".", "body", -44, "移动实体；站立/趴下时保持脚底不变。")}
[node name="Hurtbox" type="Area2D" parent="."]
editor_description = "独立玩家受击区，敌方攻击只查询本层。"
collision_layer = 4
collision_mask = 0
monitoring = false
{collision("Shape", "Hurtbox", "hurt", -44, "跟随当前姿态的伤害体积。")}
[node name="Health" type="Node" parent="."]
editor_description = "聚合同帧伤害、无敌、生命与死亡信号。"
script = ExtResource("2")
[node name="WeaponController" type="Node" parent="."]
editor_description = "发射事务、库存、能量与弹体上限。"
script = ExtResource("3")
[node name="Muzzle" type="Marker2D" parent="."]
editor_description = "实际发射锚点；视觉枪口以相同瞄准方向绘制。"
position = Vector2(36, -66)
[node name="PlayerVisual" type="Node2D" parent="."]
editor_description = "独立分层矢量角色与动作，不修改物理碰撞。"
script = ExtResource("4")
''')
    simple_scene("scenes/enemies/enemy.tscn", "Enemy", "CharacterBody2D", "scenes/enemies/enemy.gd", 'collision_layer = 0\ncollision_mask = 1\nfloor_snap_length = 8.0\nz_index = 4', collision("BodyShape", ".", "body", -30, "怪物移动体，只与世界实体碰撞。") + '''[node name="Hurtbox" type="Area2D" parent="."]
editor_description = "敌方受击区，交给实体解析护甲/冻结。"
collision_layer = 8
collision_mask = 0
monitoring = false
''' + collision("Shape", "Hurtbox", "hurt", -38, "非实体受击形状。"), shape("body", 54, 60) + shape("hurt", 80, 76))
    simple_scene("scenes/bosses/spore_king.tscn", "SporeKing", "Node2D", "scenes/bosses/spore_king.gd", 'z_index = 4', '''[node name="Hurtbox" type="Area2D" parent="."]
editor_description = "腹部核心；状态机统一判定菌甲关闭和核心暴露。"
position = Vector2(0, -70)
collision_layer = 8
collision_mask = 0
monitoring = false
''' + collision("Shape", "Hurtbox", "core", 0, "低位核心允许两角色平地基础弹命中。"), shape("core", 194, 124))
    simple_scene("scenes/props/breakable.tscn", "Breakable", "StaticBody2D", "scenes/props/breakable.gd", 'collision_layer = 1\ncollision_mask = 0\nz_index = 3', collision("BodyShape", ".", "body", 0, "顶砖/墙阻挡实体，与玩家头顶法线交互。") + '''[node name="Hurtbox" type="Area2D" parent="."]
editor_description = "可攻击交互层，实体与受击区按同一对象去重。"
collision_layer = 64
collision_mask = 0
monitoring = false
''' + collision("Shape", "Hurtbox", "body", 0, "攻击交互体积。"), shape("body", 64, 64))
    simple_scene("scenes/props/pickup.tscn", "Pickup", "Area2D", "scenes/props/pickup.gd", 'collision_layer = 128\ncollision_mask = 2\nz_index = 6', collision("Shape", ".", "body", 0, "玩家接触拾取；无需求时道具保持。"), shape("body", 44, 44))
    simple_scene("scenes/props/checkpoint.tscn", "Checkpoint", "Area2D", "scenes/props/checkpoint.gd", 'collision_layer = 128\ncollision_mask = 2\nz_index = 2', collision("Shape", ".", "body", -65, "安全站立区域检查点触发器。"), shape("body", 90, 150))
    simple_scene("scenes/props/gate.tscn", "Gate", "StaticBody2D", "scenes/props/gate.gd", 'collision_layer = 1\ncollision_mask = 0\nz_index = 3', collision("BodyShape", ".", "body", -128, "门关闭时阻挡，控制器开启后禁用。"), shape("body", 32, 256))
    simple_scene("scenes/props/attack_switch.tscn", "AttackSwitch", "Node2D", "scenes/props/attack_switch.gd", 'z_index = 3', '''[node name="Hurtbox" type="Area2D" parent="."]
editor_description = "只接受玩家攻击，零伤害冰刃同样触发。"
collision_layer = 64
collision_mask = 0
monitoring = false
''' + collision("Shape", "Hurtbox", "body", 0, "可攻击按钮体积。"), shape("body", 56, 56))
    simple_scene("scenes/props/moving_platform.tscn", "MovingPlatform", "AnimatableBody2D", "scenes/props/moving_platform.gd", 'collision_layer = 1\ncollision_mask = 1\nz_index = 3', collision("BodyShape", ".", "body", 11, "176 宽实体站立面，物理步驱动。"), shape("body", 176, 22))
    write("scenes/levels/encounter_controller.tscn", '''[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scenes/levels/encounter_controller.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/props/gate.tscn" id="2"]
[ext_resource type="Resource" path="res://resources/encounters/e1.tres" id="3"]
[node name="EncounterController" type="Node2D"]
editor_description = "两批三怪有限遭遇战，实际死亡才推进。"
script = ExtResource("1")
data = ExtResource("3")
[node name="Entrance" parent="." instance=ExtResource("2")]
editor_description = "玩家完全入场后关闭的入口门。"
opened = true
height = 576.0
[node name="Exit" parent="." instance=ExtResource("2")]
editor_description = "第二批全部死亡后开启的出口门。"
position = Vector2(1280, 0)
opened = true
height = 576.0
''')


def generate_level() -> None:
    """生成固定首关对象布局；地形由单独 Godot 工具烘焙为 TileMapLayer。"""
    # refs 为独立场景和静态数据引用。
    refs = {"level_script": ("Script", "scenes/levels/mushroom_world.gd"), "backdrop": ("Script", "scenes/levels/world_backdrop.gd"), "data": ("Resource", "resources/levels/mushroom_world.tres"), "terrain": ("PackedScene", "scenes/levels/terrain.tscn")}
    # key/path 对应可复用功能场景的引用映射。
    for key, path in {"player": "players/player", "enemy": "enemies/enemy", "boss": "bosses/spore_king", "breakable": "props/breakable", "pickup": "props/pickup", "checkpoint": "props/checkpoint", "gate": "props/gate", "switch": "props/attack_switch", "platform": "props/moving_platform", "encounter": "levels/encounter_controller"}.items():
        refs[key] = ("PackedScene", f"scenes/{path}.tscn")
    # kind 是敌人种类资源名。
    for kind in ["patrol", "spitter", "bat", "roller", "beetle"]:
        refs[kind] = ("Resource", f"resources/enemies/{kind}.tres")
    refs["e2"] = ("Resource", "resources/encounters/e2.tres")
    # lines 为当前编辑器场景文本，所有节点名 PascalCase。
    lines = ['[gd_scene format=3]']
    # key/value 是资源唯一 ID 及其类型和路径。
    for key, value in refs.items():
        lines.append(f'[ext_resource type="{value[0]}" path="res://{value[1]}" id="{key}"]')
    lines += ['[node name="MushroomWorld" type="Node2D"]', 'editor_description = "固定设计首关，34 个屏幕单元。静态布局可在 Godot 编辑器直接修改。"', 'script = ExtResource("level_script")', 'data = ExtResource("data")', '[node name="Backdrop" type="Node2D" parent="."]', 'editor_description = "三层视差环境，不承担碰撞。"', 'z_index = -10', 'script = ExtResource("backdrop")', '[node name="Terrain" parent="." instance=ExtResource("terrain")]', 'editor_description = "烘焙的草地/地下 TileMapLayer，可直接编辑单元。"']

    def node(name: str, parent: str, ref: str, x: float, y: float, properties: str = "") -> None:
        """追加带说明的功能场景实例；坐标为设计值。"""
        lines.extend([f'[node name="{name}" parent="{parent}" instance=ExtResource("{ref}")]', f'editor_description = "{name}：{ref} 实例，稳定 ID 和参数见下方属性。"', f'position = Vector2({x}, {y})', properties])

    def container(name: str, description: str) -> None:
        """建立功能分类容器，description 记录节点职责。"""
        lines.extend([f'[node name="{name}" type="Node2D" parent="."]', f'editor_description = "{description}"'])

    container("Actors", "角色、普通敌人、Boss；弹体运行时也由本层持有。")
    node("Player", "Actors", "player", 180, 576)
    node("SporeKing", "Actors", "boss", 43150, 576)
    # sections 为每段静态敌人；E1/E2 的十二只由遭遇战按固定资源生成。
    sections = [
        [(2700, "patrol"), (3270, "patrol")],
        [(4350, "patrol"), (4750, "spitter"), (5250, "spitter"), (5760, "patrol"), (6330, "spitter"), (6900, "patrol"), (7540, "spitter"), (8230, "spitter"), (8910, "patrol"), (9600, "spitter")],
        [(10700, "roller"), (11250, "patrol"), (11800, "roller"), (12400, "spitter"), (13000, "roller"), (13620, "roller"), (14200, "patrol"), (14950, "roller"), (15350, "spitter"), (15800, "roller")],
        [(17200, "beetle"), (17900, "beetle"), (18500, "beetle"), (19100, "beetle")],
        [(22850, "bat"), (23400, "bat"), (24000, "patrol"), (24600, "bat"), (25200, "bat"), (25800, "spitter"), (26400, "bat"), (27300, "patrol"), (27850, "bat"), (28500, "bat")],
        [(30200, "patrol"), (31200, "bat"), (32200, "roller"), (33600, "beetle")],
    ]
    # section_index/enemies 是区段序号和该区段静态怪物列表。
    for section_index, enemies in enumerate(sections):
        # enemy_index/(x, kind) 是固定实例序号、位置和类型。
        for enemy_index, (x, kind) in enumerate(enemies):
            # pit 为固定坑起点，避免敌人初始配置落在坑内。
            for pit in [82, 132, 184, 224, 371, 442, 491, 524]:
                if pit * 64 - 40 <= x < (pit + 3) * 64 + 40:
                    x = (pit + 4) * 64
            # floor_y 按固定台阶确定出生脚底，避免角色嵌入地形。
            floor_y = 576
            # step_start 为主线台阶起点格。
            for step_start in [24, 64, 93, 119, 152, 196, 236, 267, 288, 348, 400, 427, 468, 504, 580, 608]:
                if step_start * 64 <= x < (step_start + 8) * 64:
                    floor_y = 448 if (step_start + 2) * 64 <= x < (step_start + 6) * 64 else 512
            node(f"EnemyS{section_index + 1}N{enemy_index + 1}", "Actors", "enemy", x, floor_y - 196 if kind == "bat" else floor_y, f'data = ExtResource("{kind}")\nstable_id = "s{section_index + 1}/enemy{enemy_index + 1}"\npatrol_radius = 140.0')
    container("Breakables", "顶砖、武器箱和裂纹障碍；实体与掉落稳定 ID 分离。")
    # objects 是 x、y、破坏类型、掉落槽的固定配置。
    objects = [(580, 420, "brick", "small"), (770, 544, "crate", "A"), (1060, 420, "cracked", "small"), (6840, 288, "crate", "D"), (22080, 544, "crate", "B"), (29650, 544, "crate", "C"), (39700, 544, "crate", "A"), (40200, 544, "crate", "B"), (40700, 544, "crate", "C"), (5600, 420, "brick", "small"), (13120, 420, "brick", "small"), (24400, 420, "cracked", "small"), (31800, 420, "brick", "small")]
    # index/entry 是唯一物体序号及其固定参数。
    for index, entry in enumerate(objects):
        node(f"Object{index:02d}", "Breakables", "breakable", entry[0], entry[1], f'stable_id = "props/object{index:02d}"\nkind = "{entry[2]}"\ndrop = "{entry[3]}"')
    container("Pickups", "预置补给；恢复快照时统一替换成快照记录。")
    # items 是固定道具位置和类型，计入 PRD 补给预算。
    items = [(8620, 540, "small"), (14800, 540, "small"), (27800, 540, "small"), (21200, 540, "large"), (32800, 540, "large"), (38900, 540, "large"), (41600, 540, "large"), (26200, 540, "energy"), (33400, 540, "energy"), (39300, 540, "energy"), (41200, 540, "energy"), (7160, 280, "small"), (26900, 280, "energy")]
    # index/(x,y,kind) 是道具唯一序号及位置、内容。
    for index, (x, y, kind) in enumerate(items):
        node(f"Supply{index:02d}", "Pickups", "pickup", x, y, f'stable_id = "supply/{index}"\nkind = "{kind}"')
    container("Checkpoints", "CP0 自动建立；CP1～CP5 单向提交，Boss 门前 CP5。")
    # index/x 是检查点序号和安全位置。
    for index, x in enumerate([180, 3720, 16400, 21600, 29200, 42000]):
        node(f"CP{index}", "Checkpoints", "checkpoint", x, 576, f'index = {index}')
    container("Gates", "两处机关门和 Boss 入口门；开关关联稳定 ID。")
    node("GateOne", "Gates", "gate", 24960, 576, 'stable_id = "gate/one"\nheight = 576.0')
    node("GateTwo", "Gates", "gate", 34240, 576, 'stable_id = "gate/two"\nheight = 576.0')
    node("BossEntrance", "Gates", "gate", 42260, 576, 'stable_id = "gate/boss"\nopened = true\nheight = 576.0')
    container("Switches", "普通弹和冰刃均可触发，连线表示所连接的门。")
    node("SwitchOne", "Switches", "switch", 24640, 480, 'stable_id = "switch/one"\ngate_id = "gate/one"\ngate_offset = Vector2(320, 0)')
    node("SwitchTwo", "Switches", "switch", 33920, 480, 'stable_id = "switch/two"\ngate_id = "gate/two"\ngate_offset = Vector2(320, 0)')
    container("Platforms", "四组实体平台：两水平、两竖直，站立宽度 176。")
    # index/(x,y,dx,dy) 为平台序号、起点和终点偏移。
    for index, (x, y, dx, dy) in enumerate([(11400, 450, 224, 0), (14400, 440, 192, 0), (30600, 448, 0, -192), (33100, 448, 0, -224)]):
        node(f"Platform{index + 1}", "Platforms", "platform", x, y, f'travel = Vector2({dx}, {dy})')
    container("Encounters", "两处无坑封闭战斗场，每场两批三只。")
    node("EncounterOne", "Encounters", "encounter", 19520, 576)
    node("EncounterTwo", "Encounters", "encounter", 35328, 576, 'data = ExtResource("e2")')
    lines += ['[node name="CameraRig" type="Camera2D" parent="."]', 'editor_description = "前视 160 的独立镜头，Boss 房内锁屏。"', 'position = Vector2(640, 360)', 'position_smoothing_enabled = true', 'position_smoothing_speed = 7.0', 'limit_left = 0', 'limit_top = 0', 'limit_right = 43520', 'limit_bottom = 720']
    write("scenes/levels/mushroom_world.tscn", "\n\n".join(lines))


def generate_project() -> None:
    """写入入口与 InputMap，使编辑器能够审查和修改所有键位。"""
    write("scenes/main/main.tscn", '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scenes/main/main.gd" id="1"]
[node name="Main" type="Node"]
editor_description = "应用入口：菜单、暂停、关卡生命周期。"
script = ExtResource("1")
[node name="Interface" type="CanvasLayer" parent="."]
editor_description = "屏幕空间 UI；主菜单和 HUD 不受世界镜头移动影响。"
layer = 10
[node name="Root" type="Control" parent="Interface"]
editor_description = "容器式中文 UI 根节点，暂停期间继续处理。"
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
''')
    # base 为工程设置文本，输入段由下方固定映射追加。
    base = '''; Godot 4.7.2 标准版；输入与碰撞层可在编辑器审查。
config_version=5
[application]
config/name="蘑菇异界：双雄闯关"
config/description="非像素卡通横版动作冒险；单人键盘完整首关。"
run/main_scene="res://scenes/main/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[autoload]
SaveService="*res://core/save_service.gd"
GameSession="*res://core/game_session.gd"
AudioManager="*res://core/audio_manager.gd"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
[physics]
common/physics_ticks_per_second=60
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=1
environment/defaults/default_clear_color=Color(0.09,0.16,0.2,1)
[layer_names]
2d_physics/layer_1="World"
2d_physics/layer_2="PlayerBody"
2d_physics/layer_3="PlayerHurtbox"
2d_physics/layer_4="EnemyHurtbox"
2d_physics/layer_5="PlayerAttack"
2d_physics/layer_6="EnemyAttack"
2d_physics/layer_7="InteractableHurtbox"
2d_physics/layer_8="Triggers"
2d_physics/layer_9="DeathZone"
[input]
'''
    # actions 为动作到物理键码的固定映射（箭头键采用 Godot Key 常量数值）。
    actions = {"move_left": [65, 4194321], "move_right": [68, 4194323], "move_up": [87, 4194322], "move_down": [83, 4194324], "shoot": [74], "jump": [75], "cycle_weapon": [81], "weapon_1": [49], "weapon_2": [50], "weapon_3": [51], "weapon_4": [52], "pause": [4194305], "ui_accept": [4194309, 74, 32]}
    # action/keys 是动作名与其物理键列表。
    for action, keys in actions.items():
        # events 为该动作序列化后的键事件。
        events = ', '.join(f'Object(InputEventKey,"physical_keycode":{key})' for key in keys)
        base += f'{action}={{\n"deadzone":0.2,\n"events":[{events}]\n}}\n'
    write("project.godot", base)


if __name__ == "__main__":
    generate_resources()
    generate_components()
    generate_level()
    generate_project()
    print("Editable scenes and resources generated.")
