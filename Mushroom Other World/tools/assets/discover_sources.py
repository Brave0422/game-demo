"""Development-only source discovery; never loaded by Godot."""
import concurrent.futures
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAGES = {
    **{name: 'https://kenney.nl/assets/' + name for name in (
        'platformer-art-deluxe', 'platformer-pack-medieval', 'ui-pack-adventure',
        'digital-audio', 'impact-sounds', 'ui-audio', 'music-jingles')},
    'nature': 'https://www.gameart2d.com/free-platformer-game-tileset.html',
    'nature-license': 'https://www.gameart2d.com/license.html',
    'grassland': 'https://opengameart.org/content/a-new-day',
    'dungeon': 'https://opengameart.org/content/mysterious-orchestral-theme',
    'boss': 'https://opengameart.org/content/boss-battle-2-symphonic-metal%20',
    'bat': 'https://opengameart.org/content/villain-game-character-flappy-bat-monster-flying',
    'mushroom': 'https://opengameart.org/content/little-monster-mushroom',
    'godot': 'https://godotengine.org/download/windows/',
}

def fetch(item):
    name, url = item
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=45) as response:
            body = response.read()
        directory = ROOT / 'source_assets' / 'source_pages'
        directory.mkdir(parents=True, exist_ok=True)
        (directory / (name.replace('-', '_') + '.html')).write_bytes(body)
        links = re.findall(r'(?:href|src)=["\']([^"\']+)["\']', body.decode('utf-8', errors='replace'))
        selected = [x for x in links if any(k in x.lower() for k in ('.zip', '.ogg', '.wav', 'download', 'license', 'creativecommons', 'dropbox'))]
        return {'id': name, 'page': url, 'links': selected}
    except Exception as exc:
        return {'id': name, 'page': url, 'error': str(exc)}

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(fetch, PAGES.items()))
    (ROOT / 'source_assets' / 'discovery.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    print(json.dumps(results, indent=2))
