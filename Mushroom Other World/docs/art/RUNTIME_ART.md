# 运行时美术来源与边界

当前版本 **v0.4 手绘美术试玩版（2026-10-12）**。主要画面已使用内置 image_gen 以 `art-direction-v1.png` 为统一参考生成并实际接入，详见 [v0.4 手绘美术记录](PAINTED_ART_V1.md)。完整提示词见 [painted-v1-prompts.json](painted-v1-prompts.json)，源图与透明切片在 `assets/art/painted_v1/`。

下方是 v0.3 的历史实现记录，不代表当前主要运行画面。

## v0.3 历史记录

新增画面使用可编辑的 Godot 矢量绘制代码，与已经下载的非像素 PNG 组合。未调用 ImageGen 制作新位图，也未把历史概念图裁切成精灵，因此本次没有新的位图生成提示词。

| 内容 | 可编辑源 | 制作方式 |
| --- | --- | --- |
| 比尔、经典洛克人 | `scenes/players/player_visual.gd` | 双腿、身体、头部、手臂、枪械独立绘制；步态、腾空、趴下、瞄准、无敌、蓄力、死亡分别处理 |
| 喷吐蘑菇、荆棘滚兽、盾壳甲虫 | `scenes/enemies/enemy.gd` | 各自轮廓与动作；喇叭嘴、尖刺滚动、盾片开启、攻击弧线及冰壳 |
| 孢子大王 | `scenes/bosses/spore_king.gd` | 分层菌盖、四肢、腹部核心，扑砸落点、嘴部预警、阶段颜色与倒下姿势 |
| 菜单与场景装饰蘑菇 | `components/mushroom_decoration.gd` | 原生圆角矢量与斑点，无低分辨率放大 |
| 地形适配 PNG | `tools/build_terrain.gd` | 从 GameArt2D/Kenney CC0 素材离线缩放至逻辑格，源图保留 |
| 蘑菇走动/攻击/受伤/死亡 | 已下载 Segel 动画帧 | 加载已有序列，在游戏中裁取固定透明边界，不修改原始文件 |
| 蝙蝠 | 已下载 bevouliin 两帧 | 帧切换与紫色调制，俯冲轨迹另绘 |

经典角色是同人改编，识别元素参考魂斗罗 Bill Rizer 和经典 Mega Man；相关角色权益属于各权利方。这部分代码原生图形**不是** Kenney/GameArt2D/Segel 授权的 CC0 资产。第三方文件继续适用原有许可证，详见 CREDITS.md 和 manifest。

本次已检查真实游戏截图中的中文排版、画面可读性、地形/角色尺寸和 Boss 镜头。现有矢量角色与下载素材之间的手绘纹理一致性、完整动作表现仍属于美术精修和人工验收工作；不将“非像素”自动等同于达到参考作品的全部美术质量。
