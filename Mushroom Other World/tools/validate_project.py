"""实际运行 Godot 导入、启动、测试与导出，保留可审查的执行日志。"""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(os.environ.get('GODOT_BIN', str(ROOT / '.tools/godot/godot.exe')))
REPORT = ROOT / 'docs/validation'
env = dict(os.environ)
app_data = ROOT / '.tools/app_data'
app_data.mkdir(parents=True, exist_ok=True)
(app_data / 'Godot/app_userdata/蘑菇异界：双雄闯关').mkdir(parents=True, exist_ok=True)
env['APPDATA'] = str(app_data)
env['LOCALAPPDATA'] = str(app_data)
# 开发者选项可缩小到单项检查；默认依次导入、测试、启动。
parser = argparse.ArgumentParser()
parser.add_argument('--only', choices=['import', 'startup', 'tests', 'physics', 'boss', 'full', 'visual', 'terrain', 'export'])
args = parser.parse_args()
# 每项检查由日志名称、引擎参数和是否无窗口组成。
checks = {
    'import': ('implementation_import', ['--editor', '--import'], True),
    'startup': ('implementation_startup', ['--quit-after', '120'], True),
    'tests': ('gameplay_tests', ['tests/gameplay_tests.tscn'], True),
    'physics': ('physics_tests', ['--fixed-fps', '60', 'tests/physics_tests.tscn'], True),
    'boss': ('boss_combat', ['--fixed-fps', '60', 'tests/boss_combat_test.tscn'], True),
    'full': ('full_run', ['--fixed-fps', '60', 'tests/full_run_test.tscn'], True),
    'visual': ('visual_check', ['tests/visual_check.tscn'], False),
    'terrain': ('terrain_build', ['--script', 'tools/build_terrain.gd'], True),
    'export': ('windows_export', ['--editor', '--export-release', 'Windows Desktop', 'builds/windows/mushroom_other_world.exe'], True),
}
# selected 为本次明确要求执行的最小检查集合。
selected = [args.only] if args.only else ['import', 'tests', 'physics', 'startup']
# results 只收集真实执行结果。
results = []
# key 为检查标识，name/arguments/headless 为对应执行参数。
for key in selected:
    name, arguments, headless = checks[key]
    command = [str(ENGINE), '--path', str(ROOT), *arguments, '--log-file', str(REPORT / (name + '.log'))]
    if headless:
        command.append('--headless')
    result = subprocess.run(command, capture_output=True, timeout=240, env=env)
    text = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    (REPORT / (name + '_console.log')).write_text(text.replace('\r', ''), encoding='utf-8')
    errors = [line for line in text.splitlines() if re.search(r'(?:SCRIPT ERROR|ERROR|WARNING):', line)]
    results.append({'check': name, 'exit_code': result.returncode, 'errors_or_warnings': errors})
    print(name, result.returncode, errors)
# 保留其他检查的最近真实执行结果，单项复查只替换同名条目。
report_path = REPORT / 'implementation_validation.json'
previous = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else []
merged = {entry['check']: entry for entry in previous}
merged.update({entry['check']: entry for entry in results})
report_path.write_text(json.dumps(list(merged.values()), ensure_ascii=False, indent=2), encoding='utf-8')
if any(r.get('exit_code', 0) or r.get('errors_or_warnings') for r in results):
    raise SystemExit(1)
