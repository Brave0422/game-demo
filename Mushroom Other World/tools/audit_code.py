"""检查游戏源码中文注释、文件命名、换行以及关键场景节点说明。"""
import json
import re
from pathlib import Path

# 所有检查限制在当前项目，忽略原始素材和第三方开发依赖。
ROOT = Path(__file__).resolve().parents[1]
# 运行时和本次测试/地形构建 GDScript 的扫描目录。
FOLDERS = ["core", "components", "resources", "scenes", "tests", "tools"]
# 声明表达式包括普通、导出、就绪变量，以及函数/信号/循环变量。
DECLARATION = re.compile(r"(?:(?:@\w+(?:\([^\n]*\))?)\s+)*(?:var\s|const\s|func\s|for\s|signal\s)")
# 失败列表保存精确文件与行号。
failures = []
# 脚本总数和被检查的声明总数。
script_count = 0
declaration_count = 0

# folder 是实际扫描的项目功能目录。
for folder in FOLDERS:
    # path 是当前 GDScript 文件。
    for path in (ROOT / folder).rglob("*.gd"):
        script_count += 1
        # relative 用于输出可读且可定位的工程内路径。
        relative = path.relative_to(ROOT).as_posix()
        # raw 保留原始字节，以检测 BOM 和 CRLF。
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf") or b"\r\n" in raw:
            failures.append(f"{relative}: 需要 UTF-8 无 BOM / LF")
        if not re.fullmatch(r"[a-z][a-z0-9_]*\.gd", path.name):
            failures.append(f"{relative}: 文件名不是 snake_case")
        # lines 用于检查每个声明前紧邻的中文职责说明。
        lines = raw.decode("utf-8").splitlines()
        # index/line 是当前行索引与原始内容。
        for index, line in enumerate(lines):
            if not DECLARATION.match(line.strip()):
                continue
            declaration_count += 1
            # previous 是该声明的注释说明，允许成员与方法使用 ## 文档注释。
            previous = lines[index - 1].strip() if index else ""
            if not previous.startswith("#") or not re.search(r"[\u4e00-\u9fff]", previous):
                failures.append(f"{relative}:{index + 1}: 声明前缺少中文说明: {line.strip()}")

# node_count 是拥有编辑器说明的关键场景节点数。
node_count = 0
# path 遍历正式场景文件，测试场景不参与关键节点覆盖统计。
for path in (ROOT / "scenes").rglob("*.tscn"):
    # blocks 将每个节点与它的属性分开，避免把别的节点说明误算进来。
    blocks = re.split(r"(?=\[node )", path.read_text(encoding="utf-8"))[1:]
    # block 是一个节点的文本配置。
    for block in blocks:
        if 'editor_description = "' not in block:
            failures.append(f"{path.relative_to(ROOT)}: 节点缺少 editor_description: {block.splitlines()[0]}")
        else:
            node_count += 1

# report 是机械覆盖检查，不代替注释语义和设计质量审查。
report = {"scripts": script_count, "documented_declarations": declaration_count, "documented_scene_nodes": node_count, "failures": failures, "note": "检查注释存在性；中文内容与职责是否准确仍需审查"}
(ROOT / "docs/validation/code_audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(1 if failures else 0)
