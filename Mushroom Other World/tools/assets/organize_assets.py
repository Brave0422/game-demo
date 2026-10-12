"""Copy reviewed categories into Godot; retain original archives separately."""
import csv
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UNPACKED = ROOT / 'source_assets/unpacked'
SOURCES = {r['id']: r for r in json.loads((ROOT / 'source_assets/discovery.json').read_text(encoding='utf-8'))}
ROWS = []
FIELDS = ['asset_id', 'purpose', 'project_path', 'original_filename', 'author', 'source_url',
          'license', 'license_file', 'acquired_date', 'modifications', 'status', 'verification_note',
          'source_path', 'sha256']

def snake(name):
    name = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name)
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')

def add(source, destination, pack, purpose, author='Kenney', modifications='Renamed to snake_case; content unchanged'):
    target = ROOT / 'assets' / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    if any(row['project_path'] == target.relative_to(ROOT).as_posix() for row in ROWS):
        raise ValueError('Duplicate destination: ' + str(target))
    if source.suffix.lower() == '.wav' and target.suffix == '.ogg':
        if not target.exists():
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(source),
                            '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
        modifications = 'WAV to Ogg Vorbis quality 6; neutral part name; no trim or normalization'
    else:
        if target.exists():
            if target.read_bytes() != source.read_bytes():
                raise ValueError('Asset has local edits; refusing overwrite: ' + str(target))
        else:
            shutil.copyfile(source, target)
    is_font = pack == 'noto'
    source_url = 'https://github.com/notofonts/noto-cjk/tree/main/Sans' if is_font else SOURCES[pack]['page']
    license_file = 'assets/licenses/noto_sans_cjk_ofl.txt' if is_font else f'assets/licenses/{snake(pack)}.txt'
    note = 'File acquired; no gameplay integration.'
    if target.suffix == '.ogg':
        note += ' Auditory review, loudness matching and loop audition pending.'
    elif target.suffix == '.png':
        note += ' Non-pixel source category; final style adaptation/animation review pending.'
    original_name = {'grassland': '49_0.ogg', 'dungeon': 'mystery.ogg'}.get(pack, source.name)
    if is_font:
        original_name = 'NotoSansCJKsc-' + ('Bold' if 'bold' in source.name else 'Regular') + '.otf'
    ROWS.append(dict(zip(FIELDS, [snake(destination.replace('/', '_').rsplit('.', 1)[0]), purpose,
        target.relative_to(ROOT).as_posix(), original_name, author, source_url,
        'OFL-1.1' if is_font else 'CC0-1.0', license_file, '2026-10-11', modifications,
        'downloaded', note, source.relative_to(ROOT).as_posix(), hashlib.sha256(target.read_bytes()).hexdigest()])))

def copy_group(pack, subdir, dest, purpose, author='Kenney', suffix='.png', exclude=()):
    for source in sorted((UNPACKED / snake(pack) / subdir).rglob('*' + suffix)):
        if any(x in source.name.lower() for x in exclude):
            continue
        relative = source.relative_to(UNPACKED / snake(pack) / subdir)
        name = '/'.join(snake(part) for part in relative.parts[:-1])
        filename = snake(source.stem)
        if filename[0].isdigit():
            filename = 'tile_' + filename.zfill(2)
        add(source, '/'.join(x for x in (dest, name, filename + suffix) if x), pack, purpose, author)

def main():
    license_dir = ROOT / 'assets/licenses'
    license_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'source_assets/downloads/cc0_1_0.txt', license_dir / 'cc0_1_0.txt')
    shutil.copyfile(ROOT / 'source_assets/downloads/noto_sans_cjk_license.txt', license_dir / 'noto_sans_cjk_ofl.txt')
    for pack, data in SOURCES.items():
        if pack in ('godot', 'nature-license'):
            continue
        original = list((UNPACKED / snake(pack)).glob('*icense.txt'))
        text = original[0].read_text(encoding='utf-8-sig') if original else 'License declared by the author on the source page: CC0 1.0 Universal.\nFull legal text: cc0_1_0.txt\n'
        text += '\nSource: ' + data['page'] + '\nAcquired: 2026-10-11\nSource page snapshot: source_assets/source_pages/' + snake(pack) + '.html\n'
        if pack == 'nature':
            text += 'Freebies license: https://www.gameart2d.com/license.html\nSnapshot: source_assets/source_pages/nature_license.html\n'
        (license_dir / (snake(pack) + '.txt')).write_text(text, encoding='utf-8')

    copy_group('nature', 'png', 'art/environment/grassland/nature', '草地地形、背景与植被', 'pzUH / GameArt2D')
    copy_group('platformer-art-deluxe', 'Mushroom expansion/PNG', 'art/environment/grassland/mushrooms', '巨型蘑菇平台基础', exclude=('spritesheet',))
    copy_group('platformer-art-deluxe', 'Mushroom expansion/Backgrounds', 'art/environment/grassland/backgrounds', '蘑菇区域背景基础')
    copy_group('platformer-art-deluxe', 'Base pack/Tiles', 'art/environment/common/tiles', '平台、砖块、箱子地形基础')
    copy_group('platformer-art-deluxe', 'Base pack/Items', 'art/props/kenney', '机关、装饰与道具基础；非全部采纳为玩法')
    copy_group('platformer-art-deluxe', 'Base pack/HUD', 'art/ui/hud', '生命与道具 UI 基础', exclude=('spritesheet',))
    copy_group('platformer-pack-medieval', 'PNG', 'art/environment/dungeon/medieval', '侧视石墙、门、城堡构件基础')
    copy_group('ui-pack-adventure', 'PNG', 'art/ui/adventure', '非像素菜单面板与控件')
    copy_group('mushroom', 'Mushroom', 'art/enemies/mushroom', '巡逻蘑菇动画基础；动作尚待对齐 PRD', 'Segel / Segel2D')
    copy_group('bat', '', 'art/enemies/bat', '蝙蝠飞行动画基础；待调色与补动作', 'bevouliin.com')
    for pack, dest, purpose in (
        ('digital-audio', 'audio/sfx/weapons', '射击、能量与预警音效候选'),
        ('impact-sounds', 'audio/sfx/impacts', '木、石、金属、脚步与机关音效候选'),
        ('ui-audio', 'audio/sfx/ui', '菜单、拾取、检查点音效候选'),
        ('music-jingles', 'audio/jingles', '通关与失败短曲候选')):
        copy_group(pack, 'Audio', dest, purpose, suffix='.ogg')
    for pack, author, title in (('grassland', 'SpiderDave', 'a_new_day'), ('dungeon', 'nihilocrat', 'mysterious_orchestral_theme')):
        add(ROOT / f'source_assets/downloads/{pack}.ogg', f'audio/music/{pack}/{title}.ogg', pack, pack + ' BGM candidate', author)
    for index, source in enumerate(sorted((UNPACKED / 'boss').glob('*.wav')), 1):
        add(source, f'audio/music/boss/boss_battle_02_part_{index:02}.ogg', 'boss', 'Boss BGM candidate; original intro/loop names reversed per author; role unconfirmed by listening', 'nene')
    for weight in ('regular', 'bold'):
        add(ROOT / f'source_assets/downloads/noto_sans_sc_{weight}.otf', f'fonts/noto_sans_sc_{weight}.otf', 'noto', '简体中文界面字体', 'Noto / Adobe / Google')
    with (ROOT / 'assets/manifest.csv').open('w', newline='', encoding='utf-8-sig') as output:
        writer = csv.DictWriter(output, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(ROWS)
    directories = ['scenes/menus', 'scenes/players/bill', 'scenes/players/mega_man',
        'scenes/enemies', 'scenes/bosses', 'scenes/levels/level_01', 'scenes/props', 'scenes/ui',
        'scenes/effects', 'core', 'components', 'resources/characters', 'resources/weapons',
        'resources/enemies', 'resources/levels', 'resources/encounters', 'resources/themes',
        'assets/art/characters/bill', 'assets/art/characters/mega_man', 'assets/art/bosses',
        'assets/art/effects', 'tests', 'builds']
    for directory in directories:
        path = ROOT / directory
        path.mkdir(parents=True, exist_ok=True)
        (path / '.gitkeep').touch()
    print(f'Organized {len(ROWS)} assets; manifest written.')

if __name__ == '__main__':
    main()
