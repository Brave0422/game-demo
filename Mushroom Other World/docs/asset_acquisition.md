# 素材收集交付记录

> 当前运行时接入情况见 [实现状态](IMPLEMENTATION_STATUS.md) 和 [运行时美术来源](art/RUNTIME_ART.md)。下文保留素材收集阶段的来源、候选与历史验证记录；“下载/可解码”不等于游戏验收。


日期：2026-10-11。范围为上网获取素材、搭建 Godot 空工程；未制作游戏逻辑或关卡。本记录更新 ASSETS.md 的历史候选状态，不代表完整游戏美术验收。

## 已保存的实际文件

共 1255 个引擎侧资源，约 42.7 MiB：921 张 PNG、332 个 OGG、2 款 OTF。原始 ZIP、字体及音乐保留在 `source_assets/downloads/`；解压副本在 `source_assets/unpacked/`；页面快照与直链、原包 SHA-256 分别在 `source_assets/source_pages/`、`discovery.json`、`downloads.json`。包内 AI/SVG/EPS 等源文件随 ZIP 保留。

| 来源 | 入库数量 | 用途与当前结论 |
| --- | ---: | --- |
| GameArt2D Nature | 32 PNG | 草地地形、背景、蘑菇植被、箱子；平滑非像素基础 |
| Kenney Platformer Art Deluxe | 317 PNG | 巨型蘑菇、地形、道具、HUD；保留相关子集 |
| Kenney Medieval | 268 PNG | 石墙、门、火把和木构件；侧视基础，需地下城调色 |
| Kenney UI Adventure | 256 PNG | 两套尺寸的 UI 控件；非 Pixel Adventure |
| Segel2D Mushroom | 46 PNG | Idle 12、Walk 10、Attack 8、Hurt 8、Dead 8；统一 300×300 画布 |
| bevouliin Bat | 2 PNG | 两帧 500×410 飞行形态，仍缺攻击/受伤等状态 |
| Kenney Digital Audio | 62 OGG | 射击、能量、提示音候选 |
| Kenney Impact Sounds | 130 OGG | 木、石、金属、受击及脚步音候选 |
| Kenney UI Audio | 51 OGG | 按钮、开关与菜单反馈候选 |
| Kenney Music Jingles | 85 OGG | 五组音色的结算短曲，通关/失败用途待试听选定 |
| SpiderDave / nihilocrat / nene | 4 OGG | 草地一首、地下城一首、Boss 两段 |
| Noto Sans CJK SC | 2 OTF | Regular / Bold，保留完整 OFL |

网页宣传数量与实包数量可能不同；上表按实际保留文件计数。UI 包含尺寸变体，音频包包含附加文件，数字不表示互不重复的设计数量。全部状态保持 `downloaded`；Godot 成功导入不等于游戏内接入与体验验收，所以没有标为 `integrated` 或 `verified`。

## 已检查的画面

已实际查看以下联系表、原始蘑菇/蝙蝠图以及项目概念图。下载素材是平滑卡通、侧视环境基础；多数仍偏平面矢量，与概念图的手绘纹理、暖色粗轮廓并不完全一致。后续需要统一重绘，不能直接混搭后宣称最终画风完成。

- [草地：完整 32 张预览](validation/grassland_contact_sheet.jpg)
- [巨型蘑菇：完整预览](validation/mushrooms_contact_sheet.jpg)
- [地下城构件：抽样预览](validation/dungeon_contact_sheet.jpg)
- [UI：抽样预览](validation/ui_contact_sheet.jpg)
- [蘑菇动作抽样与蝙蝠两帧](validation/enemies_contact_sheet.jpg)

原包中像素无关扩展、替代主角等未作为本作角色导入；金币/炸弹等通用道具虽在基础包中，入库不新增 PRD 玩法。没有下载 NES/SNES 角色图，未将概念图切片作为动画。

## 音乐与音效

| 用途 | 本地文件（相对工程根目录） | 解码时长 |
| --- | --- | ---: |
| 草地候选 | `assets/audio/music/grassland/a_new_day.ogg` | 88.615 秒 |
| 地下城候选 | `assets/audio/music/dungeon/mysterious_orchestral_theme.ogg` | 118.154 秒 |
| Boss 候选 A | `assets/audio/music/boss/boss_battle_02_part_01.ogg` | 39.724 秒 |
| Boss 候选 B | `assets/audio/music/boss/boss_battle_02_part_02.ogg` | 26.483 秒 |

Boss 原包的 `boss_battle_#2_metal_loop.wav` 对应 `part_01`，`boss_battle_#2_metal_opening.wav` 对应 `part_02`。作者声明两段文件名颠倒；这是作者提示，尚未通过实际试听确认。这里只转换为 Ogg Vorbis quality 6，使用中性编号，未剪辑、调响度或开启循环。

音频全部通过 ffprobe 参数读取与 ffmpeg 全长解码。当前工具链能做文件/解码检查，未获得可对本地音频内容进行主观听辨的能力，因此**没有宣称已试听**，也不把波形或文件名当成试听证据。循环点、接缝、音色匹配、连射刺耳程度与胜利/失败短曲的最终选择仍待音频制作阶段验证。

以下只是用于后续试听的定位索引，不是音效播放配置：

| PRD 反馈类别 | 已下载的候选位置 |
| --- | --- |
| 普通弹、激光 | `audio/sfx/weapons/laser*.ogg` |
| 蓄力、武器能量、拾取 | `audio/sfx/weapons/power_up*.ogg`、`phaser_up*.ogg` |
| 受击、Boss 落地 | `audio/sfx/impacts/impact_punch_*.ogg`、`impact_soft_*.ogg` |
| 顶砖、箱子、障碍破坏 | `audio/sfx/impacts/impact_mining_*.ogg`、`impact_wood_*.ogg` |
| 冻结、碎冰 | `audio/sfx/impacts/impact_glass_*.ogg` |
| 滚兽滚动、恢复危险 | `audio/sfx/impacts/footstep_concrete_*.ogg`、`audio/sfx/weapons/three_tone*.ogg`（待设计组合） |
| 盾壳格挡、开壳 | `audio/sfx/impacts/impact_metal_*.ogg`、`impact_plate_*.ogg` |
| 开关、门、平台启动 | `audio/sfx/ui/switch*.ogg`、`audio/sfx/impacts/impact_wood_*.ogg` |
| UI 确认、返回、检查点 | `audio/sfx/ui/click*.ogg`、`rollover*.ogg`、`audio/sfx/weapons/high_up.ogg` |
| 胜利、失败短曲 | `audio/jingles/{pizzicato_jingles,steel_jingles,sax_jingles,hit_jingles,8_bit_jingles}/` |

表内音频路径以 `assets/` 为基准。后续从候选库挑选具体文件并试听，不在本轮凭名称虚构完成度。

## 缺口与筛选结果

| 需求 | 当前结果 | 后续需要 |
| --- | --- | --- |
| Bill Rizer 与经典洛克人 | 搜索未找到已核实许可且符合非像素要求的完整成套动画；未采用原版像素图 | 统一分层同人绘制与全部动作 |
| 巡逻蘑菇 | 已取得 46 帧卡通基础 | 红帽、举帽预警、挥击与冻结的 PRD 适配 |
| 喷吐蘑菇、荆棘滚兽、盾壳甲虫 | 未找到可直接满足指定轮廓和状态的成套素材 | 独立设计，不能只换色复制 |
| 蝙蝠 | 已取得两帧飞行基础 | 紫色画风统一、俯冲预警、攻击、受伤、死亡、冻结 |
| 孢子大王 | 未取得满足三招与阶段变化的现成成套素材 | 专属分层与动画制作 |
| 背景与地下城 | 已取得环境基础 | 每主题三层 1920×1080 背景、荧光蘑菇、无缝与深度校验 |
| 武器图标、弹体特效、检查点、机关状态 | 基础道具/UI 已有 | S/L/F/M 和特殊武器专属图标、完整状态图 |
| 音频 | 实际文件齐备、解码通过 | 主观试听、循环与响度处理、明确各事件音效 |

检索过 `hand drawn non pixel mushroom monster bat beetle free game assets CC0 side view` 与 `Bill Rizer Mega Man non pixel game sprite free hand drawn` 等方向。像素蘑菇、像素甲虫、原版洛克人图和没有明确资源授权的同人讨论不入库；新增蘑菇与蝙蝠选用作者在 OpenGameArt 明确声明 CC0 的原始发布页，见 Credits。本轮按用户要求只获取网上已有素材，不生成或重绘缺口。

## 复现与维护

`tools/assets/discover_sources.py` 抓取作者页；`download_sources.py` 保存原包并安全解压；`organize_assets.py` 整理目录、命名、许可与清单；`validate_assets.py` 验证 SHA-256、PNG、音频、字体并生成预览。工具均不属于游戏逻辑，运行时不会联网。下载需开发机联网；验证需 Python、Pillow、ffmpeg/ffprobe，游戏打开只需 Godot。

来源与完整署名见 [CREDITS.md](../CREDITS.md)，逐文件清单见 [manifest.csv](../assets/manifest.csv)。
