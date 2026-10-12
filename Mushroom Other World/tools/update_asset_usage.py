"""把实际接入素材与下载候选分开登记；不把可解码冒充已主观试听。"""
import csv
import hashlib
import json
import re
from pathlib import Path

# 工程根目录与逐文件资产清单路径。
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/manifest.csv"
# used 收集游戏运行时脚本/资源/场景中明确引用的资产路径。
used = set()
# folder 是会被游戏加载的源码和场景目录，不扫描测试或工具。
for folder in ["core", "components", "scenes", "resources"]:
    # path 是文本资源路径，二进制 .uid/.png 不参与此扫描。
    for path in (ROOT / folder).rglob("*"):
        if path.suffix in [".gd", ".tscn", ".tres"]:
            used.update(re.findall(r'res://(assets/[^"\s]+\.(?:png|ogg|otf))', path.read_text(encoding="utf-8")))
# frame 为动态动作路径加载的蘑菇序列，不能仅靠字面路径扫描漏记。
for frame in (ROOT / "assets/art/enemies/mushroom").rglob("*.png"):
    used.add(frame.relative_to(ROOT).as_posix())
# stream 为 csv 读取句柄，rows 保存全部历史来源行。
with MANIFEST.open(encoding="utf-8-sig", newline="") as stream:
    reader = csv.DictReader(stream)
    fields = reader.fieldnames
    rows = list(reader)
# row 是已有第三方资产，不改变来源和原始文件 SHA-256。
for row in rows:
    if row["project_path"] in used:
        row["status"] = "integrated"
        row["verification_note"] = "Integrated in v0.3 runtime; engine import/render/load checked. Audio subjective listening and seamless looping acceptance pending." if row["project_path"].endswith(".ogg") else "Integrated in v0.3 runtime; imported and rendered in Godot. Final art cohesion review pending."
    elif row["status"] == "integrated" and not row["asset_id"].startswith("runtime_terrain_"):
        row["status"] = "downloaded"
        row["verification_note"] = "Retained source candidate; not referenced by current runtime."
# existing 防止重复运行时重复追加生成贴图。
existing = {row["project_path"] for row in rows}
# index 为地形适配图片的固定类型。
for index in range(3):
    # path 为离线生成的地形适配 PNG。
    path = ROOT / f"assets/art/environment/common/terrain_{index}.png"
    # relative 是引擎内相对路径。
    relative = path.relative_to(ROOT).as_posix()
    if relative in existing or not path.exists():
        continue
    # source 是该适配图的明确原图，不把生成图错误归因于别的作者。
    source = "assets/art/environment/common/tiles/stone_center.png" if index == 2 else f"assets/art/environment/grassland/nature/tiles/tile_{'02' if index == 0 else '05'}.png"
    # original 找到已核验的源文件来源行，保留许可和署名。
    original = next(row for row in rows if row["project_path"] == source)
    # adapted 是新增资产行，来源继承但注明离线缩放。
    adapted = dict(original)
    adapted.update(asset_id=f"runtime_terrain_{index}", project_path=relative, purpose="64-unit TileMapLayer terrain", original_filename=Path(source).name, modifications="Offline Lanczos resize to 64x64; embedded into editable terrain.tscn", status="integrated", verification_note="Generated and imported; actual world rendered in Godot", source_path=source, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    rows.append(adapted)
# stream 为原清单写回句柄，字段与原版本一致。
temporary = MANIFEST.with_suffix(".csv.tmp")
with temporary.open("w", encoding="utf-8", newline="") as stream:
    writer = csv.DictWriter(stream, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)
temporary.replace(MANIFEST)
# report 是本次接入与保留候选的数量，代码原生视觉另见 RUNTIME_ART.md。
report = {"manifest_entries": len(rows), "integrated_entries": sum(row["status"] == "integrated" for row in rows), "runtime_drawings": "docs/art/RUNTIME_ART.md", "audio_subjective_review": "pending"}
(ROOT / "docs/validation/runtime_asset_usage.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False))
