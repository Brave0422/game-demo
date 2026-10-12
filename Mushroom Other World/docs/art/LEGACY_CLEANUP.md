# 旧美术清理

2026-10-12，用户明确同意删除不再需要的旧美术文件。

已删除旧 `assets/art/` 下的环境、敌人、道具、UI 和占位目录；对应 PNG/SVG 图形素材的下载压缩包与解包目录；旧素材预览图；v0.3 绘图脚本备份；未使用的 `MushroomDecoration` 组件及对应 UID；这些图片的孤立导入缓存。

删除前已移除木箱脚本未使用的旧贴图 preload，并将地形生成工具改为使用当前 `painted_v1` 资源。现有地图格子与碰撞保持不变，没有重新生成关卡。

当前手绘资源、9 张生成源图、原美术参考图、完整提示词、音频、字体和许可证保留。旧独立试玩包作为历史版本保留，本轮只清理旧美术源文件。

历史第三方图形来源记录存于 `removed_legacy_assets.csv`，当前音频和字体继续存于 `assets/manifest.csv`，当前手绘资源清单存于 `assets/art/painted_v1/manifest.csv`。完整删除路径与字节统计见 `legacy_cleanup_plan.json`，执行结果见 `legacy_cleanup_result.json`。
