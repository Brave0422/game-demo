# v0.4 手绘美术验证记录

日期：2026-10-12。以下结果来自本轮真实 Godot 4.7.2 执行；旧整关自动输入结果不算本轮重新通关。

| 检查 | 本轮结果 | 证据 |
| --- | --- | --- |
| 资源导入与脚本解析 | 退出 0，无引擎错误或警告 | `implementation_import_console.log` |
| 实际项目启动 | 退出 0，无错误或警告 | `implementation_startup_console.log` |
| 玩法集成 | 55 项通过，0 失败 | `gameplay_results.json` |
| 真实物理与路线检查 | 23 项通过，0 失败 | `physics_results.json` |
| 两角色基础武器 Boss 战 | 比尔与洛克人均获胜，Boss HP 为 0 | `boss_combat_results.json` |
| Compatibility 画面 | 菜单、选择、两角色待机/跑步/跳跃、地下、Boss、暂停共 11 张真实截图 | `visual_check_console.log`、对应 PNG |
| 透明资源 | 64 张切片均包含 0 与 255 alpha；总计 67 张运行纹理，源图另存 | `assets/art/painted_v1/manifest.csv` |
| Windows 导出 | 退出 0，无错误或警告 | `windows_export_console.log` |
| 独立 EXE 启动 | 退出 0，无错误或警告 | `export_startup_console.log` |
| 导出 PCK 资源与场景 | 明确从 PCK 加载 67 张新纹理，两角色均启动；各场景 40 个静态敌人、暂停/恢复/返回菜单通过 | `export_smoke_console.log` |

查看实际图片后，已修复菜单渐变条纹、独立草地块的圆角缝隙、地形材质过密和旧蓝色机关门与手绘场景不协调的问题。人物跑跳使用独立图，显示倍率和脚底画布固定。截图未经后期编辑。

发行包：`builds/mushroom_other_world_windows_v0.4_painted.zip`，87,960,357 字节（约 83.9 MiB，旧美术清理后重新打包）。新 exe 与 pck 位于 `builds/windows_painted_v0.4/`，旧 v0.3 包保留。实际发行哈希和检查范围见 `release_painted_v0.4_validation.json`。

本轮没有宣称在新机器离线完整通关，也不把自动输入当作真人首次体验。动画连续性、个别八方向枪口姿势和镜像远景构图仍可精修；美术目标已从代码几何图形混搭切换到参考图统一的手绘资源。
