"""验证已导出的独立程序，并打包 Windows 试玩版与第三方许可。"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

# 工程根目录及既有导出目录，不创建外部系统依赖。
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "builds/windows_painted_v0.4"
# 日志集中保存到版本化验证目录，不混入玩家发行包。
REPORT = ROOT / "docs/validation"
# 仅向项目内的隔离用户目录写设置，避免影响正式玩家记录。
environment = dict(os.environ)
environment["APPDATA"] = str(ROOT / ".tools/app_data")
environment["LOCALAPPDATA"] = environment["APPDATA"]
# 两项分别验证发行程序启动，以及发行 PCK 内的动态角色/场景资源。
# 标准 4.7 导出模板关闭 --script 路径覆盖，资源专项用引擎加载同一 PCK。
checks = [
    ("export_startup", [str(OUTPUT / "mushroom_other_world.exe"), "--headless", "--quit-after", "120"]),
    ("export_smoke", [os.environ.get("GODOT_BIN", str(ROOT / ".tools/godot/godot.exe")), "--headless", "--main-pack", str(OUTPUT / "mushroom_other_world.pck"), "--script", str(ROOT / "tools/export_smoke.gd")]),
]
# results 只记录真实执行的各项退出码和错误。
results = []
# name/command 分别为检查名称及完整参数，工作目录不包含松散源码。
for name, command in checks:
    command += ["--log-file", str(REPORT / (name + ".log"))]
    # result 是该独立进程的实际退出状态。
    result = subprocess.run(command, cwd=OUTPUT, env=environment, capture_output=True, timeout=30)
    # console 是真实控制台文本，不用截图或文件存在代替运行。
    console = (result.stdout + result.stderr).decode("utf-8", errors="replace").replace("\r", "")
    (REPORT / (name + "_console.log")).write_text(console, encoding="utf-8")
    # issues 包含零退出码也不能忽略的引擎错误和警告。
    issues = [line for line in console.splitlines() if re.search(r"(?:SCRIPT ERROR|ERROR|WARNING):", line)]
    if result.returncode or issues or (name == "export_smoke" and console.count("EXPORT SMOKE PASS:") != 2):
        raise SystemExit(f"{name} failed ({result.returncode}): {issues}\n{console}")
    results.append({"check": name, "exit_code": result.returncode, "errors_or_warnings": issues})

# 玩家说明随 exe/pck 一同发放，不要求玩家安装编辑器或 Python。
readme = """蘑菇异界：双雄闯关 — v0.4 手绘美术试玩版

完整解压后双击 mushroom_other_world.exe。
mushroom_other_world.pck 必须放在 exe 同一目录。Windows x86_64，无需安装 Godot。

A/D 或左右方向键移动；K 跳跃；J 射击；Esc 暂停。
比尔：W/S 或上下方向键瞄准，地面单按下键趴下。
洛克人：按住 J 蓄力、松手释放；Q 或 1—4 切换已解锁武器。
砖块从下顶破；木箱射击；裂纹两者皆可。仅荆棘滚兽常态接触伤害。
CP0—CP5 自动保存本次游戏检查点；退出游戏或返回菜单清除本次进度。
设置和成绩保存到 Windows 用户应用数据目录中的 Godot/app_userdata/蘑菇异界：双雄闯关。

包含两角色、九种武器配置、五类怪物、草地/地下城完整首关及两阶段 Boss。
以原参考图生成并接入 9 张美术源图、64 张透明切片、2 张背景和连续地表。
角色、五怪、Boss、场景、道具、菜单和 HUD 已切换新美术。
动画细节仍可精修；14—18 分钟首次体验时长和音频主观试听尚未验收。
素材及许可见 CREDITS.md 和 licenses/。经典角色同人绘制不属于第三方 CC0 素材。
"""
(OUTPUT / "README.txt").write_text(readme, encoding="utf-8-sig")
shutil.copy2(ROOT / "CREDITS.md", OUTPUT / "CREDITS.md")
shutil.copytree(ROOT / "assets/licenses", OUTPUT / "licenses", dirs_exist_ok=True)

# archive 是完整玩家压缩包，固定文件白名单排除日志和本地设置。
archive = ROOT / "builds/mushroom_other_world_windows_v0.4_painted.zip"
# files 只包含程序、资源、玩家说明和来源许可证。
files = [OUTPUT / name for name in ["mushroom_other_world.exe", "mushroom_other_world.pck", "README.txt", "CREDITS.md"]]
files += sorted(path for path in (OUTPUT / "licenses").rglob("*") if path.is_file())
# bundle 为标准 ZIP，所有文件放在同一个顶层目录便于解压。
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    # path 是已限定白名单中的单个发行文件。
    for path in files:
        bundle.write(path, "mushroom_other_world/" + path.relative_to(OUTPUT).as_posix())
# checksums 是可复核产物哈希，不将源码测试运行结果冒充独立包运行结果。
checksums = {}
# path 遍历核心发行产物，读文件计算标准 SHA-256。
for path in [OUTPUT / "mushroom_other_world.exe", OUTPUT / "mushroom_other_world.pck", archive]:
    checksums[path.relative_to(ROOT).as_posix()] = {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
# report 保存本机独立包的实际验证范围，其他机器离线通关仍需人工执行。
report = {"checks": results, "characters_started_from_pck": ["bill", "mega_man"],
          "scope": "Exported EXE startup; engine separately loads exported PCK for 67 painted textures, two characters, 40 enemies, pause/resume/menu. Same Windows machine; not clean-machine full playthrough", "files": checksums}
(REPORT / "release_painted_v0.4_validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
