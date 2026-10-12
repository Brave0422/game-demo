# 验证记录入口

当前游戏实现的实际结果见 [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md)。以下保留的是实施前的**素材与空工程历史检查**，其中“0 个脚本”“未运行玩法”不描述当前版本。

日期：2026-10-11；Windows；Godot `4.7.2.stable.steam.ed1daf0bf`（现有 Steam 标准版）。

| 检查 | 结果 |
| --- | --- |
| 1255 个清单路径、许可路径、唯一 ID、SHA-256 | 通过 |
| 921 张 PNG 文件解码 | 通过 |
| 332 个 OGG 参数解析、全长解码 | 通过；不等同于试听或循环检查 |
| 2 款中文字体加载 | 通过 |
| 草地、巨型蘑菇、地下城、UI、敌人联系表查看 | 已检查完整或抽样预览；需要后续统一美术 |
| Godot 无界面编辑器扫描、素材导入 | 通过，退出码 0，无 ERROR/WARNING |
| Godot 空主场景运行 3 帧并退出 | 通过，退出码 0，无 ERROR/WARNING |
| 游戏 GDScript 文件 | 0 个 |
| 主场景 | 1 个空 Node2D，无脚本与子节点 |
| 玩法、窗口视觉体验、音频试听、导出 | 未执行，不属于本轮空工程验证 |

证据：[素材检查 JSON](asset_validation.json)、[工程检查 JSON](project_validation.json)、本地 `godot_import.log` / `godot_startup.log`。

初次导入发现两个工程准备问题并已处理：素材 CSV 被自动识别为翻译表，已设置 Keep 导入并移除生成的翻译文件；Steam 引擎自包含缓存目录在项目权限范围外，验证改为复制现有引擎至忽略目录 `.tools/godot/`，将测试进程 APPDATA/LOCALAPPDATA 指向 `.tools/app_data/`。未改动用户系统环境变量或原安装目录。早期日志 `godot_import_initial.log` 仅供排错，不代表最终结果。

官方便携版下载入口曾返回 HTTP 403；随后找到已安装的同版本引擎并完成验证，因此没有留下引擎版本阻塞。

复现：

```powershell
# Godot 检查默认使用本次本地验证副本；其他机器指定现有 Godot：
$env:GODOT_BIN = 'C:/path/to/godot.exe'
python tools/validate_project.py

# 素材检查需 Pillow 与 ffmpeg/ffprobe：
python tools/assets/validate_assets.py
```

空工程本身没有 Python 或 ffmpeg 运行依赖。文件内容未通过调整状态字段伪装为最终游戏验收；`manifest.csv` 中的 `downloaded` 为刻意保留的当前阶段。
