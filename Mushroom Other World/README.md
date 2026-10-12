# 蘑菇异界：双雄闯关

Godot 非像素手绘卡通 2D 横版动作冒险。当前版本 **v0.4 手绘美术试玩版（2026-10-12）**。以原美术参考图重新生成并接入森林、地下、两角色动作、五怪、Boss、地形、道具与菜单，保留已有首关玩法。实际画面见 [草地实机截图](docs/validation/grassland_bill.png) 和 [Boss 实机截图](docs/validation/boss.png)。动画连续性与个别瞄准姿势仍可继续精修，真人首次体验时长与音频主观试听仍需验收。

使用 Godot **4.7.2 标准版**导入根目录 `project.godot`，按 **F5** 进入中文主菜单。项目采用 Compatibility、1280×720、线性过滤、60 Hz 物理。新压缩包为 [`mushroom_other_world_windows_v0.4_painted.zip`](builds/mushroom_other_world_windows_v0.4_painted.zip)。Windows 试玩目录位于 [`builds/windows_painted_v0.4/`](builds/windows_painted_v0.4/)；双击 `mushroom_other_world.exe`，同目录的 `.pck` 必须保留，无需安装 Godot。旧 v0.3 导出留在 `builds/windows/`。

操作：**A/D 或方向键移动，K 跳跃，J 射击，Esc 暂停**。比尔 W/S 瞄准，地面单按 S 趴下；洛克人按住 J 蓄力、松手释放，Q 或 1–4 切换武器。砖块只能从下顶破，箱子只能射击打破，裂纹两者皆可。仅荆棘滚兽持续接触伤害。CP0–CP5 保存本次会话进度；返回菜单或关闭应用不保留检查点。

新增要求已写入 [工程与代码审查规范](docs/CODING_STANDARDS.md)：按 Godot 官方惯例组织场景、文件命名及代码逻辑；变量、方法、关键节点均有中文注释。`.tscn` 使用 `editor_description` 保存节点说明。正式资源数值与场景脚本就近组织，不建立镜像 `scripts/` 目录。

当前实现包含：九种武器配置、五种普通怪机制、三类破坏物、四组移动平台、两处攻击开关、两场两批三怪遭遇战、检查点快照、双时间统计、两阶段孢子大王、菜单/暂停/设置/结算和音频。场景入口为 `scenes/levels/mushroom_world.tscn`，地形保存在可直接编辑的 `terrain.tscn`，运行时不随机生成主线。

- [实现状态、参数修改位置及已知边界](docs/IMPLEMENTATION_STATUS.md)
- [实际测试结果和截图](docs/validation/IMPLEMENTATION_REPORT.md)
- [代码与节点注释规范](docs/CODING_STANDARDS.md)

- [工程目录、命名与后续代码规范](docs/project_structure.md)
- [本次素材收集结果、预览、音频候选与缺口](docs/asset_acquisition.md)
- [现有音频与字体的逐文件来源与许可清单](assets/manifest.csv)
- [当前手绘美术来源与哈希](assets/art/painted_v1/manifest.csv)
- [已清理旧图形素材的历史来源记录](docs/art/removed_legacy_assets.csv)
- [第三方素材署名](CREDITS.md)
- [检查结果](docs/validation/README.md)

当前美术为 **67 张手绘运行纹理**（64 张透明切片、2 张背景、1 张连续地表），生成源图与提示词保留。旧背景、图块、怪物、道具和 UI 图片及对应图形原包已按用户要求清理，历史来源清单保留在 `docs/art/removed_legacy_assets.csv`。原有 **332 个 OGG、2 款中文字体**与相关音频原包、许可证保留；音频主观试听仍需验收。

以下文档描述首版产品目标；功能实现和验收结果分别以实现状态与测试记录为准：

- [PRD：玩法、角色、武器、首关、Boss、技术与验收](docs/PRD.md)
- [技术方案：各模块使用的技术、数据、碰撞与状态恢复](docs/TECHNICAL_DESIGN.md)
- [验收清单：功能边界、两角色试玩与时长验证](docs/QA_CHECKLIST.md)
- [素材来源、许可与需要制作的动作清单](docs/ASSETS.md)
- [直接交给 AI 的实施提示词](docs/AI_IMPLEMENTATION_PROMPT.md)
- [美术方向与制作规格](docs/art/ART_DIRECTION.md)
- [已生成的画风示意图](docs/art/art-direction-v1.png)
- [示意图完整生成提示词](docs/art/art-direction-prompt.txt)
- [本轮文档审查、已确认决策与待实测事项](docs/REVIEW_NOTES.md)

首版范围为 PC 单人键盘、两名经典角色、一个蘑菇草地与地下城关卡、五种机制不同的普通怪、一个两阶段怪兽 Boss。新增荆棘滚兽和盾壳甲虫，仅荆棘滚兽有持续身体接触伤害。首关有效主线内容目标为 14–18 分钟，加入平台、开关与两场有限遭遇战，不靠死亡重跑凑时长。用户确认项与设计默认值在 PRD 中分别说明，默认数值可在试玩时调整。

PRD 是产品规则主文档，技术与验收文档是必要补充。`AI_IMPLEMENTATION_PROMPT.md` 保留为后续继续实施的模板；执行范围始终以当次用户请求为准，不把文档中的历史“本轮”描述误当成当前指令。

素材下载来源以 `docs/asset_acquisition.md` 和 `assets/manifest.csv` 为准。概念图仅作风格参考，未裁切成精灵。当前手绘资源、原图与完整生成提示词见 [v0.4 美术接入记录](docs/art/PAINTED_ART_V1.md)，切片可用 `tools/prepare_painted_art.gd` 复现；不把生成图或同人形象归入第三方 CC0 授权。

开发验证（在本目录执行）：`python tools/validate_project.py`。指定本机引擎可设置 `GODOT_BIN`；`--only visual` 保存真实运行截图，`--only boss` 执行基础武器 Boss 自动输入，`--only full` 执行整关自动输入，`--only export` 使用匹配的 4.7.2 模板导出。测试无声模式不启动音频解码线程，有窗口运行使用完整音频链。
