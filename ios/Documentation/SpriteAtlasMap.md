# Master sprite atlas audit

Audited main: `0e01edc457b82bcd86a778ca95bc66cbbb9225ad` (latest main on 2026-10-19).

**MASTER ATLAS HAS MISSING REQUIRED ASSETS**

## Atlas dimensions and image properties

Pillow decoded `ios/RPG Pixel Art Sprite Sheet Atlas.png` as **1774 × 887, RGB, 8 bits per channel**. It has no alpha channel and no PNG transparency metadata. SHA-256: `6893b19ed05a1178ff4cd9b725f05453bc47bf6b87c45fdf698dc77c0af63d2f`.

All 1,573,538 pixels are opaque. Black surrounds many figures, while the castle panel has a bright magenta background. These colors are actual image pixels, not transparency. No color key is declared or inferred. A SpriteKit rectangle crop cannot recover the original transparent frame backgrounds.

This is a composite illustration with differently sized panels and illustrated animation-like rows, rather than a verified uniform frame grid. There is no supplied packing manifest, fixed padding contract, or common cell size. Exact intended panel/frame boundaries and gutter widths cannot be established from source matching: **zero current crops match**, even when alpha is ignored. Do not use guessed grid sizes, independently trim frames, rescale art or substitute lookalike figures. The visible red minotaur and robed wizard must not be treated as matches for the two distinct existing enemy sheets.

## Current inventory and resource membership

- **249 distinct RenderAssetID contracts**, counted as the union of all 12 production level manifests, including animation frames and fallback/base textures. These are required by current preflight/rendering; this does not claim every fallback is drawn in every session.
- **43 source PNGs** back those contracts.
- **1 additional currently rendered SwiftUI image**: `heart.png`, loaded directly by `GameplayView.HealthIcon`; it has no existing RenderAssetID. Its full 320 × 290 source is included separately as audit-only `ui.health-icon`, not a new production identifier.
- **250 total audited image requests**, comprising **200 distinct source crops** after alias deduplication. **0 verified atlas entries; 250 missing requests**.
- **CURRENTLY RENDERED / REQUIRED:** all 44 loose PNGs in the application Resources phase are accounted for by the 43 renderer sources plus the HUD heart. The source table below specifies every contract and crop.
- **BUNDLED BUT UNUSED:** no unused loose PNG was found. App icon variants in `Assets.xcassets` serve the app launcher and are outside the sprite atlas migration. They are not unused gameplay resources and must remain.
- The master atlas is repository-only: there is no file reference or Resources phase entry. This audit adds only Swift source/test membership; it does not add the atlas to either app/test resources or remove existing PNG registrations.

## Coordinate convention

All source rectangles use **top-left** integer pixels: `(x, y, width, height)`, retaining each entire current frame, including transparent padding. `TextureCatalog.load` in `GameScene.swift` converts to SpriteKit using `x / sheetWidth` and `1 - (y + height) / sheetHeight`; normalized width/height divide by sheet dimensions. `SpriteSheet.normalizedRect` uses the same convention. The typed audit centralizes sheet dimensions once. Synthetic tests explicitly check asymmetric coordinates to detect a vertical-origin reversal.

## Frame ordering and directions

| Family | Current sheet | Rows by direction | Frames per direction | Total frames | Current frame pixels |
| --- | --- | --- | ---: | ---: | --- |
| Lidia | lidia.png | up 0, left 1, down 2, right 3 | 9 | 36 | 64 × 64 |
| Skeleton | skeleton.png | up 8, left 9, down 10, right 11 | 9 | 36 | 64 × 64 |
| Flying Terror | flying_terror.png | left 0, up 2, right 4, down 6 | 10 | 40 | 128 × 128 |
| Minotaur | minotaur.png | down 0, left 1, right 2, up 3 | 3 | 12 | 48 × 64 |
| Ghost Wizard | minotaurWithAxe.png | down/none 0, right 1, left 2, up 3 | 2 | 8 | 45 × 58 |
| Coin | goldCoin1.png … goldCoin9.png | ordered files 1 … 9 | — | 9 | 32 × 32 |
| Waterfall | water.png | source y = 0, x = 96 × frame | — | 4 | 96 × 193 |

The 145 animation frames above retain existing IDs and ordering. Enemy/player frame crops use `x = frame × frameWidth`, `y = row × frameHeight`. Base IDs alias existing frame crops; they are not extra animation frames. No timing, logical render dimensions, anchor, z-position, presentation or simulation changes are made.

## Exact matching and missing assets

`SpriteAtlasInventory.tsv` is the complete text inventory: original filename, crop, sheet dimensions, source SHA-256 and status for each ID. `SpriteAtlasMap.md` is its human-readable rendering. The audit script searches every eligible integer origin at original scale/orientation, anchoring on the least frequent visible source color and then comparing the entire frame. It ignores RGB only where source alpha is zero; all alpha values, including partial transparency, must match. An additional diagnostic compares all visible RGB while ignoring alpha. Both searches return zero matches for every crop. Source and atlas hashes prevent silent replacement of audit inputs.

Every row marked **MISSING FROM MASTER ATLAS** is a required visual contract without a verified replacement. Dungeon tile/wall/door/item IDs are used in their named level presentations and shared simulations. Character/enemy IDs are used by player/enemy snapshots and the directional animation catalog. `country-road.*` is used by CountryRoad presentation/simulation; `hero-welcome.*` by HeroWelcome presentation/simulation. `enemy.ghost-wizard.projectile` is the current 8 × 8 bomb-fuse crop used by LevelTen. The HUD heart is used by GameplayView. **All are release-critical for a migration that preserves current rendering**; none may be dropped on the basis of this atlas.

This proves the supplied image is not a drop-in rectangle-only replacement. It does not claim that a visually similar subject cannot be drawn somewhere in the image. A lossless atlas export preserving current frame sizes/alpha, together with a packing manifest, is required before the migration can proceed. Any intentional new-art substitution requires its own explicit art/animation/layout review.

## Duplicated atlas regions

There are **no verified required sprite regions**, so there are no verified duplicate matches to register. The search returns every match, not just the first, and its duplicate behavior is tested with synthetic images. The illustration contains repeated-looking walls/figures; their intended frame boundaries and pixel-equivalent identity have not been established. They are not authoritative duplicate sprite coordinates. Existing logical aliases (for example country-road castle wall and Hero's Welcome wall-front) share old crops, which accounts for some of the 250-to-200 deduplication; these are source aliases, not proven atlas duplicates.

## Typed map and migration gate

`HookshotHero/Game/Rendering/SpriteAtlasLayout.swift` defines `MasterSpriteAtlas`: filename, dimensions, digest, verified `entries`, frozen `missingRequiredAssetIDs`, completeness status and finite/in-bounds rectangle validation. **The verified map is deliberately empty.** Filling it with estimated coordinates would hide the blocker. Every current renderer ID is explicitly missing. The separate HUD image remains in the text inventory rather than adding a new RenderAssetID contract. Production TextureCatalog continues to use the old sources.

Coverage tests classify every manifest texture and resolved animation frame as verified or explicitly missing, verify 249 IDs against the production catalog, check directional sequences and exact frame counts, and test bounds/NaN/origin handling. They explicitly expect the incomplete verdict. The requested assertion that all assets have valid atlas coordinates cannot pass for this image; it is not silently replaced with a completeness claim.

## Validation

Executed on Linux with Pillow/NumPy:

```sh
python ios/Scripts/audit_sprite_atlas.py
python -m unittest discover -s ios/Scripts -p 'test_audit_sprite_atlas.py' -v
```

Pixel audit reproduced: 250 requests, 200 unique crops, zero alpha-equivalent matches and zero visible-RGB matches. Six synthetic matcher tests passed (origins/full frames, hidden RGB, partial/lost alpha, visible color changes, duplicates/boundaries, oversized/empty content). For an explicit migration gate, `python ios/Scripts/audit_sprite_atlas.py --require-complete` exits 1 on this atlas.

**Xcode build, Swift XCTest and Simulator: NOT EXECUTED**; Swift/Xcode are unavailable in this environment. Five `SpriteAtlasLayoutTests` are added to the unit-test target for macOS/Xcode execution. No screenshot comparison is asserted.

## Complete source-to-atlas table

Atlas X/Y are intentionally `—` when missing. Width/Height below are the **current required frame dimensions**, not a fabricated atlas rectangle. All original crops use top-left coordinates; source sheet dimensions and hashes are in the TSV. No binary files are changed.

| RenderAssetID | Old Source | Old Crop (x,y,w,h) | Atlas X | Atlas Y | Width | Height | Status |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| `character.lidia` | lidia.png | (0,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-0` | lidia.png | (0,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-1` | lidia.png | (64,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-2` | lidia.png | (128,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-3` | lidia.png | (192,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-4` | lidia.png | (256,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-5` | lidia.png | (320,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-6` | lidia.png | (384,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-7` | lidia.png | (448,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.0-8` | lidia.png | (512,0,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-0` | lidia.png | (0,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-1` | lidia.png | (64,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-2` | lidia.png | (128,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-3` | lidia.png | (192,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-4` | lidia.png | (256,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-5` | lidia.png | (320,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-6` | lidia.png | (384,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-7` | lidia.png | (448,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.1-8` | lidia.png | (512,64,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-0` | lidia.png | (0,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-1` | lidia.png | (64,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-2` | lidia.png | (128,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-3` | lidia.png | (192,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-4` | lidia.png | (256,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-5` | lidia.png | (320,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-6` | lidia.png | (384,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-7` | lidia.png | (448,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.2-8` | lidia.png | (512,128,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-0` | lidia.png | (0,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-1` | lidia.png | (64,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-2` | lidia.png | (128,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-3` | lidia.png | (192,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-4` | lidia.png | (256,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-5` | lidia.png | (320,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-6` | lidia.png | (384,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-7` | lidia.png | (448,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `character.lidia.3-8` | lidia.png | (512,192,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `country-road.bags` | country1.png | (225,326,64,27) | — | — | 64 | 27 | MISSING FROM MASTER ATLAS |
| `country-road.bridge` | country1.png | (385,95,90,100) | — | — | 90 | 100 | MISSING FROM MASTER ATLAS |
| `country-road.castle-door` | castle1.png | (145,71,16,24) | — | — | 16 | 24 | MISSING FROM MASTER ATLAS |
| `country-road.castle-wall` | castle1.png | (76,0,40,30) | — | — | 40 | 30 | MISSING FROM MASTER ATLAS |
| `country-road.cliff` | terrain.png | (865,739,95,90) | — | — | 95 | 90 | MISSING FROM MASTER ATLAS |
| `country-road.cobble` | terrain.png | (580,750,90,80) | — | — | 90 | 80 | MISSING FROM MASTER ATLAS |
| `country-road.grass` | country1.png | (2,350,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `country-road.island` | water.png | (416,35,65,60) | — | — | 65 | 60 | MISSING FROM MASTER ATLAS |
| `country-road.lake` | terrain.png | (96,516,95,90) | — | — | 95 | 90 | MISSING FROM MASTER ATLAS |
| `country-road.market` | country1.png | (400,0,112,95) | — | — | 112 | 95 | MISSING FROM MASTER ATLAS |
| `country-road.market-1` | country1.png | (385,223,127,40) | — | — | 127 | 40 | MISSING FROM MASTER ATLAS |
| `country-road.market-2` | country1.png | (385,290,127,40) | — | — | 127 | 40 | MISSING FROM MASTER ATLAS |
| `country-road.npc.child` | c1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `country-road.npc.older-resident` | o1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `country-road.npc.townfolk` | t1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `country-road.road` | terrain.png | (580,1093,90,85) | — | — | 90 | 85 | MISSING FROM MASTER ATLAS |
| `country-road.water` | water.png | (390,290,100,50) | — | — | 100 | 50 | MISSING FROM MASTER ATLAS |
| `country-road.waterfall.0` | water.png | (0,0,96,193) | — | — | 96 | 193 | MISSING FROM MASTER ATLAS |
| `country-road.waterfall.1` | water.png | (96,0,96,193) | — | — | 96 | 193 | MISSING FROM MASTER ATLAS |
| `country-road.waterfall.2` | water.png | (192,0,96,193) | — | — | 96 | 193 | MISSING FROM MASTER ATLAS |
| `country-road.waterfall.3` | water.png | (288,0,96,193) | — | — | 96 | 193 | MISSING FROM MASTER ATLAS |
| `country-road.wheat` | country1.png | (290,257,62,62) | — | — | 62 | 62 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror` | flying_terror.png | (0,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-0` | flying_terror.png | (0,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-1` | flying_terror.png | (128,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-2` | flying_terror.png | (256,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-3` | flying_terror.png | (384,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-4` | flying_terror.png | (512,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-5` | flying_terror.png | (640,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-6` | flying_terror.png | (768,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-7` | flying_terror.png | (896,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-8` | flying_terror.png | (1024,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.0-9` | flying_terror.png | (1152,0,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-0` | flying_terror.png | (0,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-1` | flying_terror.png | (128,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-2` | flying_terror.png | (256,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-3` | flying_terror.png | (384,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-4` | flying_terror.png | (512,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-5` | flying_terror.png | (640,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-6` | flying_terror.png | (768,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-7` | flying_terror.png | (896,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-8` | flying_terror.png | (1024,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.2-9` | flying_terror.png | (1152,256,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-0` | flying_terror.png | (0,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-1` | flying_terror.png | (128,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-2` | flying_terror.png | (256,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-3` | flying_terror.png | (384,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-4` | flying_terror.png | (512,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-5` | flying_terror.png | (640,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-6` | flying_terror.png | (768,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-7` | flying_terror.png | (896,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-8` | flying_terror.png | (1024,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.4-9` | flying_terror.png | (1152,512,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-0` | flying_terror.png | (0,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-1` | flying_terror.png | (128,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-2` | flying_terror.png | (256,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-3` | flying_terror.png | (384,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-4` | flying_terror.png | (512,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-5` | flying_terror.png | (640,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-6` | flying_terror.png | (768,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-7` | flying_terror.png | (896,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-8` | flying_terror.png | (1024,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.flying-terror.6-9` | flying_terror.png | (1152,768,128,128) | — | — | 128 | 128 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard` | minotaurWithAxe.png | (0,0,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.0-0` | minotaurWithAxe.png | (0,0,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.0-1` | minotaurWithAxe.png | (45,0,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.1-0` | minotaurWithAxe.png | (0,58,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.1-1` | minotaurWithAxe.png | (45,58,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.2-0` | minotaurWithAxe.png | (0,116,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.2-1` | minotaurWithAxe.png | (45,116,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.3-0` | minotaurWithAxe.png | (0,174,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.3-1` | minotaurWithAxe.png | (45,174,45,58) | — | — | 45 | 58 | MISSING FROM MASTER ATLAS |
| `enemy.ghost-wizard.projectile` | bomb.png | (6,0,8,8) | — | — | 8 | 8 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur` | minotaur.png | (0,0,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.0-0` | minotaur.png | (0,0,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.0-1` | minotaur.png | (48,0,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.0-2` | minotaur.png | (96,0,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.1-0` | minotaur.png | (0,64,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.1-1` | minotaur.png | (48,64,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.1-2` | minotaur.png | (96,64,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.2-0` | minotaur.png | (0,128,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.2-1` | minotaur.png | (48,128,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.2-2` | minotaur.png | (96,128,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.3-0` | minotaur.png | (0,192,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.3-1` | minotaur.png | (48,192,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.minotaur.3-2` | minotaur.png | (96,192,48,64) | — | — | 48 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton` | skeleton.png | (0,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-0` | skeleton.png | (0,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-1` | skeleton.png | (64,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-2` | skeleton.png | (128,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-3` | skeleton.png | (192,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-4` | skeleton.png | (256,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-5` | skeleton.png | (320,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-6` | skeleton.png | (384,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-7` | skeleton.png | (448,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.10-8` | skeleton.png | (512,640,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-0` | skeleton.png | (0,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-1` | skeleton.png | (64,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-2` | skeleton.png | (128,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-3` | skeleton.png | (192,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-4` | skeleton.png | (256,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-5` | skeleton.png | (320,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-6` | skeleton.png | (384,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-7` | skeleton.png | (448,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.11-8` | skeleton.png | (512,704,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-0` | skeleton.png | (0,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-1` | skeleton.png | (64,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-2` | skeleton.png | (128,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-3` | skeleton.png | (192,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-4` | skeleton.png | (256,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-5` | skeleton.png | (320,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-6` | skeleton.png | (384,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-7` | skeleton.png | (448,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.8-8` | skeleton.png | (512,512,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-0` | skeleton.png | (0,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-1` | skeleton.png | (64,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-2` | skeleton.png | (128,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-3` | skeleton.png | (192,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-4` | skeleton.png | (256,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-5` | skeleton.png | (320,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-6` | skeleton.png | (384,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-7` | skeleton.png | (448,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `enemy.skeleton.9-8` | skeleton.png | (512,576,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `hero-welcome.barrels` | barrels.png | (0,0,128,64) | — | — | 128 | 64 | MISSING FROM MASTER ATLAS |
| `hero-welcome.bookshelf` | castle2.png | (53,100,20,27) | — | — | 20 | 27 | MISSING FROM MASTER ATLAS |
| `hero-welcome.carpet` | castle1.png | (0,97,47,31) | — | — | 47 | 31 | MISSING FROM MASTER ATLAS |
| `hero-welcome.column` | castle1.png | (64,96,16,50) | — | — | 16 | 50 | MISSING FROM MASTER ATLAS |
| `hero-welcome.desk` | castle2.png | (80,122,30,23) | — | — | 30 | 23 | MISSING FROM MASTER ATLAS |
| `hero-welcome.door` | castle1.png | (145,71,16,24) | — | — | 16 | 24 | MISSING FROM MASTER ATLAS |
| `hero-welcome.floor` | castle1.png | (79,95,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `hero-welcome.flower-1` | castle1.png | (150,165,20,27) | — | — | 20 | 27 | MISSING FROM MASTER ATLAS |
| `hero-welcome.flower-2` | castle1.png | (127,165,16,27) | — | — | 16 | 27 | MISSING FROM MASTER ATLAS |
| `hero-welcome.knight` | castle2.png | (47,75,16,23) | — | — | 16 | 23 | MISSING FROM MASTER ATLAS |
| `hero-welcome.npc.aristocrat` | a1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `hero-welcome.npc.king` | k1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `hero-welcome.npc.prince` | p1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `hero-welcome.npc.princess` | pr1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `hero-welcome.npc.queen` | q1.png | (0,64,24,32) | — | — | 24 | 32 | MISSING FROM MASTER ATLAS |
| `hero-welcome.red-carpet` | castle1.png | (112,96,64,64) | — | — | 64 | 64 | MISSING FROM MASTER ATLAS |
| `hero-welcome.side-wall` | castle1.png | (169,0,7,40) | — | — | 7 | 40 | MISSING FROM MASTER ATLAS |
| `hero-welcome.silver-chest` | chests.png | (259,67,25,25) | — | — | 25 | 25 | MISSING FROM MASTER ATLAS |
| `hero-welcome.wall-flags` | castle1.png | (112,37,50,25) | — | — | 50 | 25 | MISSING FROM MASTER ATLAS |
| `hero-welcome.wall-front` | castle1.png | (76,0,40,30) | — | — | 40 | 30 | MISSING FROM MASTER ATLAS |
| `level-five.chest.side` | ChestSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-five.door.closed.left` | DoorGreyClosedLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-five.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-five.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-five.lava` | lava.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-five.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-five.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-five.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.door.closed` | DoorGreyClosed.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.door.closed.right` | DoorGreyClosedRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.door.open.side` | DoorGreyOpenSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-four.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-four.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-one.cabbage` | barrels.png | (64,32,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.chest.closed` | chests.png | (291,67,25,25) | — | — | 25 | 25 | MISSING FROM MASTER ATLAS |
| `level-one.chest.open` | chests.png | (291,95,25,29) | — | — | 25 | 29 | MISSING FROM MASTER ATLAS |
| `level-one.coin` | goldCoin1.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.1` | goldCoin1.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.2` | goldCoin2.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.3` | goldCoin3.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.4` | goldCoin4.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.5` | goldCoin5.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.6` | goldCoin6.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.7` | goldCoin7.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.8` | goldCoin8.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.coin.9` | goldCoin9.png | (0,0,32,32) | — | — | 32 | 32 | MISSING FROM MASTER ATLAS |
| `level-one.door.closed` | DoorGreyClosed.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-one.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-one.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-one.lava` | lava.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-one.mine` | bomb.png | (0,0,20,26) | — | — | 20 | 26 | MISSING FROM MASTER ATLAS |
| `level-one.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-one.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-one.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.chest.back` | ChestBack.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.chest.side` | ChestSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.door.closed` | DoorGreyClosed.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-seven.lava` | lava.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-seven.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.chest.front` | ChestFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.chest.side` | ChestSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.door.closed` | DoorGreyClosed.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-six.lava` | lava.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-six.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-three.door.closed` | DoorGreyClosed.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-three.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-three.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-three.lava` | lava.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-three.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-three.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-three.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-two.door.closed` | DoorGreyClosed.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-two.door.open` | DoorGreyOpen.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-two.floor` | floor.png | (0,0,100,100) | — | — | 100 | 100 | MISSING FROM MASTER ATLAS |
| `level-two.lava` | lava.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-two.wall.front` | wallGreyFront.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-two.wall.left` | wallGreyLeftSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `level-two.wall.right` | wallGreyRightSide.png | (0,0,40,40) | — | — | 40 | 40 | MISSING FROM MASTER ATLAS |
| `ui.health-icon` | heart.png | (0,0,320,290) | — | — | 320 | 290 | MISSING FROM MASTER ATLAS |
