#!/usr/bin/env python3
"""Asset guard for the ZeParty mobile app. Run from `mobile app/` (CI, pre-commit, tool/build_release.sh).

Fails when:
  * two assets are byte-identical (keep one, reference it everywhere),
  * an asset is referenced by nothing (code literal, `${}` template, backend source, or tool/asset_allowlist.txt),
  * a single asset is larger than MAX_FILE_MB,
  * a still image is wider or taller than MAX_STILL_PX (downscale: nothing in the UI draws them that large),
  * pubspec.yaml lists an asset directory that does not exist.
"""
import os, re, sys, hashlib, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
MAX_FILE_MB = 3.0
MAX_STILL_PX = 2048  # profile cards and homepage skins are tall portrait art drawn at full screen height
EXTRA_SOURCE_DIRS = [os.path.join(ROOT, '..', 'backend', 'src'), os.path.join(ROOT, '..', 'backend', 'prisma')]
# Directories whose contents are selected by the server at runtime (gift catalogue), so a literal
# scan cannot prove they are unused.
SERVER_DRIVEN_PREFIXES = ('assets/gifts/',)


def read_text(path):
    try:
        with open(path, encoding='utf-8', errors='ignore') as fh:
            return fh.read()
    except OSError:
        return ''


def image_dims(path):
    with open(path, 'rb') as fh:
        b = fh.read(64)
    if b[:8] == b'\x89PNG\r\n\x1a\n':
        return struct.unpack('>II', b[16:24]) + (False,)
    if b[:4] == b'RIFF' and b[8:12] == b'WEBP':
        ch = b[12:16]
        if ch == b'VP8X':
            anim = bool(b[20] & 0x02)
            return (1 + int.from_bytes(b[24:27], 'little'), 1 + int.from_bytes(b[27:30], 'little'), anim)
        if ch == b'VP8 ':
            return (int.from_bytes(b[26:28], 'little') & 0x3fff, int.from_bytes(b[28:30], 'little') & 0x3fff, False)
        if ch == b'VP8L':
            bits = int.from_bytes(b[21:25], 'little')
            return ((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1, False)
    return None


def main():
    errors = []
    # 1. source text
    blobs = []
    for dp, _, fs in os.walk(os.path.join(ROOT, 'lib')):
        for f in fs:
            if f.endswith('.dart'):
                blobs.append(read_text(os.path.join(dp, f)))
    dart_blob = '\n'.join(blobs)
    for d in EXTRA_SOURCE_DIRS:
        for dp, _, fs in os.walk(d):
            if 'node_modules' in dp:
                continue
            for f in fs:
                if f.endswith(('.js', '.ts', '.json', '.prisma')):
                    blobs.append(read_text(os.path.join(dp, f)))
    blobs.append(read_text(os.path.join(ROOT, 'pubspec.yaml')))
    allow = os.path.join(ROOT, 'tool', 'asset_allowlist.txt')
    if os.path.exists(allow):
        blobs.append(read_text(allow))
    blob = '\n'.join(blobs)

    templates = []
    for lit in set(re.findall(r"['\"](assets/[^'\"]+)['\"]", dart_blob)):
        if '$' in lit:
            r = re.escape(lit)
            r = re.sub(r'\\\$\\\{[^}]*\\\}', '[0-9A-Za-z]+', r)
            r = re.sub(r'\\\$\w+', '[0-9A-Za-z]+', r)
            templates.append(re.compile('^' + r + '$'))

    # 2. walk assets
    by_md5 = {}
    for dp, _, fs in os.walk(ASSETS):
        for f in fs:
            if f.startswith('.'):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            size = os.path.getsize(path)
            with open(path, 'rb') as fh:
                by_md5.setdefault(hashlib.md5(fh.read()).hexdigest(), []).append(rel)
            if size > MAX_FILE_MB * 1048576:
                errors.append(f'too large ({size / 1048576:.1f} MB > {MAX_FILE_MB} MB): {rel}')
            dims = image_dims(path)
            if dims and not dims[2] and max(dims[0], dims[1]) > MAX_STILL_PX:
                errors.append(f'still image {dims[0]}x{dims[1]} exceeds {MAX_STILL_PX}px: {rel}')
            referenced = (rel in blob or os.path.basename(rel) in blob
                          or any(t.match(rel) for t in templates)
                          or rel.startswith(SERVER_DRIVEN_PREFIXES))
            if not referenced:
                errors.append(f'unreferenced asset: {rel}')
    warnings = []
    for md5, group in by_md5.items():
        if len(group) > 1:
            # Every name referenced from code: removing a copy needs a code change, so only warn.
            all_used = all(r in blob or os.path.basename(r) in blob or any(t.match(r) for t in templates) for r in group)
            (warnings if all_used else errors).append('byte-identical duplicates: ' + ', '.join(sorted(group)))

    # 3. pubspec asset dirs
    pub = read_text(os.path.join(ROOT, 'pubspec.yaml'))
    m = re.search(r'^\s{2}assets:\n((?:\s{4}- .*\n)+)', pub, re.M)
    if m:
        for line in m.group(1).splitlines():
            d = line.strip()[2:].strip()
            if not os.path.exists(os.path.join(ROOT, d)):
                errors.append(f'pubspec asset path does not exist: {d}')

    for w in warnings:
        print('  warning (same bytes under several referenced names):', w)
    if errors:
        print(f'check_assets: {len(errors)} problem(s)')
        for e in errors:
            print('  -', e)
        return 1
    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(ASSETS) for f in fs)
    print(f'check_assets: OK ({total / 1048576:.0f} MB under assets/)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
