"""Download source assets. This is an offline game's development tool only."""
import concurrent.futures
import hashlib
import json
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def download(item):
    name, url, filename = item
    target = ROOT / 'source_assets' / 'downloads' / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        if not target.exists():
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=90) as response:
                content = response.read()
            if len(content) < 100:
                raise ValueError('Unexpectedly small download')
            target.write_bytes(content)
        if target.suffix == '.zip':
            with zipfile.ZipFile(target) as archive:
                if archive.testzip():
                    raise ValueError('Archive CRC failure')
                output = ROOT / 'source_assets' / 'unpacked' / name.replace('-', '_')
                output.mkdir(parents=True, exist_ok=True)
                for member in archive.infolist():
                    if not (output / member.filename).resolve().is_relative_to(output.resolve()):
                        raise ValueError('Unsafe archive path')
                archive.extractall(output)
        result = {'id': name, 'url': url, 'path': target.relative_to(ROOT).as_posix(),
                  'bytes': target.stat().st_size, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
        print(name + ': downloaded ' + str(result['bytes']) + ' bytes', flush=True)
        return result
    except Exception as exc:
        print(name + ': ERROR ' + str(exc), flush=True)
        return {'id': name, 'url': url, 'error': str(exc)}

if __name__ == '__main__':
    records = json.loads((ROOT / 'source_assets/discovery.json').read_text(encoding='utf-8'))
    jobs = []
    for record in records:
        if record['id'] in ('godot', 'nature-license'):
            continue
        links = [x for x in record.get('links', []) if x.endswith('.zip')]
        if not links:
            links = [x for x in record.get('links', []) if x.endswith('.ogg') and '/styles/' not in x]
        if links:
            url = urllib.parse.urljoin(record['page'], links[-1])
            filename = record['id'].replace('-', '_') + Path(urllib.parse.urlparse(url).path).suffix
            jobs.append((record['id'], url, filename))
    base = 'https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/'
    for weight in ('Regular', 'Bold'):
        jobs.append(('noto_sans_sc_' + weight.lower(), base + 'OTF/SimplifiedChinese/NotoSansCJKsc-' + weight + '.otf', 'noto_sans_sc_' + weight.lower() + '.otf'))
    jobs.append(('noto_license', base + 'LICENSE', 'noto_sans_cjk_license.txt'))
    jobs.append(('cc0', 'https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt', 'cc0_1_0.txt'))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(download, jobs))
    (ROOT / 'source_assets/downloads.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
