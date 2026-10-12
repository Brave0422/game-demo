"""Validate retained audio/fonts and current painted textures after legacy art cleanup."""
import concurrent.futures
import csv
import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / 'docs/validation'
REPORT.mkdir(parents=True, exist_ok=True)
ROWS = list(csv.DictReader((ROOT / 'assets/manifest.csv').open(encoding='utf-8-sig')))

def validate(row):
    path = ROOT / row['project_path']
    assert path.is_file() and path.stat().st_size > 0, str(path)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256'], str(path)
    assert (ROOT / row['license_file']).is_file(), row['license_file']
    assert all(re.fullmatch(r'[a-z0-9_.]+', part) for part in Path(row['project_path']).parts), str(path)
    result = {'path': row['project_path'], 'bytes': path.stat().st_size}
    if path.suffix == '.png':
        with Image.open(path) as im:
            result.update(width=im.width, height=im.height, mode=im.mode)
            im.verify()
    elif path.suffix == '.ogg':
        probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries',
            'format=duration:stream=codec_name,sample_rate,channels', '-of', 'json', str(path)],
            check=True, capture_output=True, text=True)
        result.update(json.loads(probe.stdout))
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'null', '-'],
                       check=True, capture_output=True)
    elif path.suffix == '.otf':
        font = ImageFont.truetype(str(path), 28)
        assert font.getbbox('蘑菇异界：双雄闯关')[2] > 0
    return result

def sheet(name, paths, columns=6, size=160):
    paths = list(paths)
    im = Image.new('RGB', (columns * size, ((len(paths) + columns - 1) // columns) * (size + 30)), '#e7e5df')
    draw = ImageDraw.Draw(im)
    for i, path in enumerate(paths):
        thumb = Image.open(path).convert('RGBA')
        thumb.thumbnail((size - 12, size - 12))
        x, y = (i % columns) * size, (i // columns) * (size + 30)
        im.paste(thumb, (x + (size - thumb.width) // 2, y + (size - thumb.height) // 2), thumb)
        draw.text((x + 3, y + size), path.stem[:24], fill='#20252a')
    im.save(REPORT / (name + '.jpg'), quality=90)

if __name__ == '__main__':
    assert len({row['asset_id'] for row in ROWS}) == len(ROWS)
    assert len({row['project_path'] for row in ROWS}) == len(ROWS)
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(validate, ROWS))
    (REPORT / 'asset_validation.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    # 当前手绘资源单独登记来源，不沿用第三方 CC0 的许可字段。
    with (ROOT / 'assets/art/painted_v1/manifest.csv').open(encoding='utf-8', newline='') as stream:
        painted = list(csv.DictReader(stream))
    for row in painted:
        path = ROOT / row['project_path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256'], str(path)
        with Image.open(path) as image:
            assert image.size == (int(row['width']), int(row['height']))
            image.verify()
    print(json.dumps({'assets': len(ROWS), 'formats': dict(Counter(Path(r['project_path']).suffix for r in ROWS)),
        'audio_checks': 'Full decode; NOT subjective listening or seamless-loop validation',
        'painted_textures': len(painted), 'project': 'Current assets verified'}, indent=2))
