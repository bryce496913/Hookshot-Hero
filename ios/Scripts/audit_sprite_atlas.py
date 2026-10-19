#!/usr/bin/env python3
"""Reproduce the audit without changing images. Requires Pillow and NumPy.

Checks unscaled, unrotated, full-frame alpha-equivalent pixels at every eligible
integer top-left origin. Hidden RGB under alpha=0 is ignored. Partial alpha and
frame padding must be preserved. No color key, resampling or trimming is inferred.
Exit 0 means the audit reproduced; --require-complete exits 1 for missing assets.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / 'ios/RPG Pixel Art Sprite Sheet Atlas.png'
INVENTORY = ROOT / 'ios/Documentation/SpriteAtlasInventory.tsv'


def find_matches(atlas, source, *, preserve_alpha=True, frequencies=None):
    """Return all alpha-equivalent full-frame rectangles in top-left pixels."""
    ah, aw = atlas.shape[:2]
    h, w = source.shape[:2]
    if h > ah or w > aw:
        return []
    visible = source[:, :, 3] > 0
    points = np.argwhere(visible)
    if not len(points):
        raise ValueError('An entirely transparent source cannot identify artwork')
    # Any exact match must contain every visible source color. Choose the least
    # frequent atlas color as an anchor; absent colors prove absence immediately.
    colors, indices = np.unique(source[:, :, :3][visible], axis=0, return_index=True)
    if frequencies is None:
        atlas_colors, counts = np.unique(atlas[:, :, :3].reshape(-1, 3), axis=0, return_counts=True)
        frequencies = dict(zip(map(tuple, atlas_colors), counts))
    anchor = min(range(len(colors)), key=lambda i: frequencies.get(tuple(colors[i]), 0))
    if tuple(colors[anchor]) not in frequencies:
        return []
    py, px = points[indices[anchor]]
    yy, xx = np.where(np.all(atlas[:, :, :3] == source[py, px, :3], axis=2))
    xx, yy = xx - px, yy - py
    inside = (xx >= 0) & (yy >= 0) & (xx + w <= aw) & (yy + h <= ah)
    matches = []
    for x, y in zip(xx[inside], yy[inside]):
        region = atlas[y:y+h, x:x+w]
        if ((not preserve_alpha or np.array_equal(region[:, :, 3], source[:, :, 3]))
                and np.array_equal(region[:, :, :3][visible], source[:, :, :3][visible])):
            matches.append([int(x), int(y), w, h])
    return matches


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    with Image.open(ATLAS) as image:
        size, mode, alpha = image.size, image.mode, 'A' in image.getbands() or 'transparency' in image.info
        atlas = np.array(image.convert('RGBA'))
    assert size == (1774, 887) and mode == 'RGB' and not alpha
    layout = (ROOT / 'ios/HookshotHero/Game/Rendering/SpriteAtlasLayout.swift').read_text()
    assert hashlib.sha256(ATLAS.read_bytes()).hexdigest() in layout, 'Atlas changed: repeat audit'
    files = {}
    for path in (ROOT / 'Java/resources').rglob('*.png'):
        if path.name in files:
            raise ValueError('Ambiguous source filename: ' + path.name)
        files[path.name] = path
    rows = list(csv.DictReader(INVENTORY.open(), delimiter='\t'))
    assert len(rows) == len({r['assetID'] for r in rows}) == 250
    cache, results = {}, {}
    colors, counts = np.unique(atlas[:, :, :3].reshape(-1, 3), axis=0, return_counts=True)
    frequencies = dict(zip(map(tuple, colors), counts))
    for row in rows:
        path = files[row['oldSource']]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sourceSHA256'], str(path)
        x, y, w, h, sw, sh = (int(row[k]) for k in ('x', 'y', 'width', 'height', 'sheetWidth', 'sheetHeight'))
        assert w > 0 and h > 0 and x >= 0 and y >= 0 and x+w <= sw and y+h <= sh
        key = (str(path), x, y, w, h)
        if key not in cache:
            with Image.open(path) as image:
                assert image.size == (sw, sh)
                source = np.array(image.convert('RGBA'))[y:y+h, x:x+w]
            # Also ignore alpha as a diagnostic; never promote these candidates
            # to verified rectangles when their transparency has been lost.
            cache[key] = {'equivalent': find_matches(atlas, source, frequencies=frequencies),
                          'visibleRGB': find_matches(atlas, source, preserve_alpha=False, frequencies=frequencies)}
        results[row['assetID']] = cache[key]
        assert bool(cache[key]['equivalent']) == (row['status'] == 'VERIFIED'), row['assetID']
    mapped = sum(bool(r['equivalent']) for r in results.values())
    print(json.dumps({'dimensions': size, 'mode': mode, 'hasAlpha': alpha,
                      'rendererAssetCount': 249, 'additionalHUDImages': 1,
                      'uniqueSourceCrops': len(cache), 'mappedCount': mapped,
                      'visibleRGBMatchCount': sum(bool(r['visibleRGB']) for r in results.values()),
                      'missingCount': len(rows)-mapped,
                      'duplicateVerifiedRegions': {k: v['equivalent'] for k, v in results.items() if len(v['equivalent']) > 1},
                      'verdict': 'MASTER ATLAS HAS MISSING REQUIRED ASSETS' if mapped < len(rows) else 'MASTER ATLAS IS COMPLETE FOR CURRENT IOS RENDERING'}, indent=2))
    return 1 if args.require_complete and mapped < len(rows) else 0


if __name__ == '__main__':
    raise SystemExit(main())
