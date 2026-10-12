# Godot 工程组织约定

当前范围：v0.3 可运行开发试玩版。新增规范以 [CODING_STANDARDS.md](CODING_STANDARDS.md) 为准：目录、命名和逻辑遵循 Godot 官方惯例；所有变量、方法、关键节点具备中文注释。`tools/` 只在开发时运行，正式游戏不执行构建工具。

## 依据与版本

使用 Godot 4.7.2 标准版、Compatibility 渲染器。实际验证版本为 `4.7.2.stable.steam.ed1daf0bf`。

Godot 官方没有唯一强制目录模板。本项目遵循官方的[按功能组织、资源就近放置建议](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)与 [GDScript 风格规范](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)，针对本作选择以下布局。

```text
project.godot                    # Godot 入口配置
default_bus_layout.tres          # Master / Music / SFX / UI 静态总线
scenes/
  main/{main.tscn,main.gd}       # 应用生命周期、菜单切换、暂停
  menus/                        # 菜单背景与 UI 表现
  players/                      # 共用 Player、武器控制器、分层视觉
  enemies/
  bosses/
  levels/                       # mushroom_world、terrain、遭遇战、视差
  props/
  effects/
  ui/
core/                           # GameSession、SaveService、AudioManager
components/                     # 共用 Health 组件和装饰绘制
resources/                      # 带类型 Resource 脚本与只读设计配置
  {characters,weapons,enemies,levels,encounters,themes}/
assets/
  art/{environment,characters,enemies,bosses,props,effects,ui}/
  audio/{music,sfx,jingles}/
  fonts/
  licenses/                     # 许可文本，不参与导入
  manifest.csv                  # 逐文件来源清单，Keep 导入模式
source_assets/                   # 原包、解压目录、页面快照，不参与导入
docs/                           # 需求、规范、素材报告、验证记录，不参与导入
tools/                          # 开发工具，不参与导入
tests/                          # 逻辑、物理、Boss、全流程与渲染验证
builds/windows/                 # .exe + .pck + 运行说明与许可
```

## 命名与代码约定

- 新增目录、资源、场景与 GDScript 文件使用小写 `snake_case`，例如 `player_controller.gd`、`mushroom_patrol.tscn`。既有大写需求文档和原始下载包保留原名以便追溯。
- 场景根节点、节点名、类型与 `class_name` 使用 `PascalCase`；变量、函数、参数、信号使用 `snake_case`；常量与枚举成员使用 `CONSTANT_CASE`；私有成员使用 `_` 前缀。
- 场景专属脚本与 `.tscn` 同目录；共享组件放 `components/`；全局服务放 `core/`。避免独立 `scripts/` 树与场景重复镜像。
- 使用带类型 GDScript、Tab 缩进、UTF-8、LF。文件内按官方顺序组织工具/类声明、信号、枚举、常量、导出属性、普通属性、就绪属性、生命周期与其他方法。
- 节点组合优先；父节点注入依赖，子节点通过信号报告；场景自行管理本地节点。必要时才增加 Autoload，不建立无用途的全局管理器。
- 静态设计数据用 Resource，运行时状态使用独立实例；UI 不直接修改伤害或世界状态；具体职责与规则见技术方案与实现状态。
- 成员、局部变量、方法、重要分支附中文说明。关键场景节点用 `editor_description`，动态创建节点在创建处说明职责。
- 引擎内路径使用 `res://`，用户持久化使用 `user://`；在 Godot 文件系统面板移动已引用资源，保留 `.uid` 与 `.import` 文件。
- `.godot/`、本地 `.tools/` 和导出产物不提交；原始素材 ZIP、许可证、清单与导入设置保留。`.gitkeep` 保留空目录。

## 项目配置与编辑

1280×720 逻辑视口、`canvas_items` 拉伸、`keep` 宽高比、60 Hz 物理、线性纹理过滤，关闭 2D 像素吸附。F5 运行中文菜单。打开 `scenes/levels/mushroom_world.tscn` 审查节点；打开 `terrain.tscn` 直接调整 TileMapLayer。

`assets/manifest.csv.import` 使用 `importer="keep"`，避免 Godot 将素材登记表误当成本地化翻译表。`tools/build_scenes.py` 和 `tools/build_terrain.gd` 是初稿重建工具，会覆盖生成的场景；手工调关卡后不要无意重跑。正式游戏使用已保存的固定场景。

原始包包含 SVG/AI 等源文件与完整额外素材，统一放在 `source_assets/`；引擎侧只收录相关 PNG、OGG、OTF。素材收录不等于采纳包内金币、炸弹、梯子等玩法。
