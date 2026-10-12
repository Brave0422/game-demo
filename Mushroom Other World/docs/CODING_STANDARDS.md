# Godot 工程与代码审查规范

生效日期：2026-10-11。用户明确要求：项目目录、命名、代码逻辑遵循主流 Godot 项目惯例；每个变量、方法和关键节点均有中文注释，方便审查。本规范适用于新增和修改的游戏代码、场景、资源及开发工具。

## 官方依据

- [Godot 项目组织](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)：按功能组织、相关资源就近放置、排除非运行时目录。
- [Godot 场景组织](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)：自包含场景、节点组合、父节点注入依赖、信号向上报告。
- [GDScript 风格](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)：命名、Tab 缩进、类型、声明顺序。

Godot 不强制唯一目录树。本项目采用以下一致约定，不把团队选择或“逐变量中文注释”误称为引擎硬性规则。

## 目录与命名

`scenes/<功能>/` 就近放 `.tscn` 和场景专属 `.gd`；`components/` 放跨场景组件；`core/` 只放会话、存储、音频等全局服务；`resources/<种类>/` 放带类型 Resource 脚本和 `.tres` 配置；`assets/` 放运行时素材；`tests/` 放引擎测试；`tools/` 放离线工具；`docs/` 放文档；`builds/` 放导出产物。

文件、目录、变量、方法、参数和信号用 `snake_case`；节点、类型、`class_name` 用 `PascalCase`；常量和枚举成员用 `CONSTANT_CASE`；内部成员用 `_` 前缀。历史文档和原包名保留。采用 UTF-8 无 BOM、LF、Tab 缩进、显式类型，每行原则上不超过 100 字符。

## 逻辑组织

资源保存设计参数，独立实例保存运行时状态。碰撞、视觉和 UI 分离，禁止 UI 直接改怪物血量。公开方法定义明确输入与输出，通过信号报告事件。物理与战斗冷却使用物理步 delta；暂停服从 SceneTree。对象通过稳定 ID 保存状态，快照不得包含 Node 引用；先标记已处理，再延迟删除节点。避免无用途的 Autoload、循环依赖、巨型主场景脚本和运行时随机生成主线。

## 中文注释（用户额外要求）

1. 每个脚本以 `##` 说明职责。每个常量、成员、导出属性和信号前用中文说明含义、单位与用途；局部变量和循环变量也应在相邻注释中说明。
2. 每个方法前用 `##` 说明目的、参数意义、返回值及关键副作用；回调同样注释。参数可在方法注释中集中说明。
3. 关键分支解释业务原因，例如同帧伤害取最大、护甲先于穿透、检查点回滚；不以“执行代码”等无信息注释凑数。
4. `.tscn` 的根、碰撞、视觉、枪口、相机、控制器、UI 等关键节点使用 `editor_description` 写中文职责。动态创建节点在创建点说明用途，命名仍使用 PascalCase。
5. `.tres` 的数值含义在对应 Resource 的导出属性注释中定义；地图对象的稳定 ID、关联门、补给槽在场景中可审查。
6. 修改实现时同步修改注释，删除失效说明；公共行为变化同步 PRD/技术方案/验收记录。

## 提交与验收

保留 `.uid`、`.import`、原始素材许可与来源清单；排除 `.godot/`、`.tools/` 和导出产物。引擎内路径用 `res://`，设置/成绩用 `user://`。每次功能交付运行导入、脚本检查和相关引擎测试；记录真实结果，手感、画面、音频试听、首次体验时长不能用逻辑测试替代。
