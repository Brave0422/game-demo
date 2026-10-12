"""更新当前音频、字体与手绘素材记录；已删除的旧图形只保留历史清单。"""
import csv
import json
import re
from pathlib import Path

# 工程根目录与当前第三方音频、字体清单。
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/manifest.csv"
# used 收集当前实际源码引用，手绘动态加载另从其独立清单读取。
used = set()
# folder 为运行时源码与配置目录。
for folder in ["core", "components", "scenes", "resources"]:
    # path 为可扫描的文本资源。
    for path in (ROOT / folder).rglob("*"):
        if path.suffix in [".gd", ".tscn", ".tres"]:
            used.update(re.findall(r'res://(assets/[^"\s]+\.(?:png|ogg|otf))',
                path.read_text(encoding="utf-8")))
# stream 为当前清单，rows 保存音频与字体原始来源字段。
with MANIFEST.open(encoding="utf-8-sig", newline="") as stream:
    reader = csv.DictReader(stream)
    fields = reader.fieldnames
    rows = list(reader)
# row 的状态仅由当前引用决定，不重新添加已删除的旧图片。
for row in rows:
    integrated = row["project_path"] in used
    row["status"] = "integrated" if integrated else "downloaded"
    row["verification_note"] = (
        "Referenced by v0.4 runtime; audio subjective review remains pending."
        if integrated else "Retained audio/font candidate; not currently referenced.")
# temporary 为原字段完整保存的临时文件，成功后原子替换。
temporary = MANIFEST.with_suffix(".csv.tmp")
with temporary.open("w", encoding="utf-8", newline="") as stream:
    writer = csv.DictWriter(stream, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)
temporary.replace(MANIFEST)
# painted 为当前手绘动态资源，来源清单独立于第三方音频和字体。
with (ROOT / "assets/art/painted_v1/manifest.csv").open(encoding="utf-8", newline="") as stream:
    painted = list(csv.DictReader(stream))
# report 说明当前来源清单数量；历史删除记录不混入当前资产数。
report = {
    "manifest_entries": len(rows),
    "integrated_entries": sum(row["status"] == "integrated" for row in rows),
    "painted_texture_entries": len(painted),
    "painted_manifest": "assets/art/painted_v1/manifest.csv",
    "removed_art_manifest": "docs/art/removed_legacy_assets.csv",
    "runtime_drawings": "docs/art/RUNTIME_ART.md",
    "audio_subjective_review": "pending",
}
(ROOT / "docs/validation/runtime_asset_usage.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False))
