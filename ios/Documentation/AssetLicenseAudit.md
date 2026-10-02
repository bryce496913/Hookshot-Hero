# iOS Asset License Verification Record

Checked: **2026-10-02 UTC**  
Target baseline: `ios/HookshotHero.xcodeproj/project.pbxproj`, application target `PBXResourcesBuildPhase`  
Deterministic inventory: `ShippedAssetInventory.txt`

## Verification method and limitation

The target build phase, `LevelOneTextureCatalog`, every `LevelAssetManifest`, and `Assets.xcassets` were inspected. The historical credits in `Java/README.md` were used only as leads. A direct HTTPS request to `https://opengameart.org/content/spinning-gold-coin` was attempted on 2026-10-02; the environment's proxy rejected the tunnel with `403 Forbidden`. The browser search service was also unavailable (`401 Unauthorized`). Consequently, upstream pages and downloads could not be fetched and bundled images could not be compared with current upstream downloads. **No unverified row was converted to resolved.** A network-enabled reviewer must open every URL below, retain dated evidence, download the offered files, compare dimensions/pixels or sprite regions, and record the exact applicable license and contributors.

## Repository and owner-decision checks

* **Project code:** `Java/LICENSE.txt` is the repository's canonical complete MIT text: Copyright (c) 2023 Jerry Hsiung. The file first appears in repository history at commit `26b5e85a5b8422941d1df535660dbce8c87a58bc`. An unmodified copy is now an application resource at `Resources/Licenses/Hookshot-Hero-MIT.txt`.
* **Lidia selection:** content and full Git-history searches for `Lidia`, `lpc-heroine`, `BY-SA`, and `GPL` found historical credit and offered-license documentation, but no explicit project-owner distribution choice. **OWNER LICENSE SELECTION REQUIRED FOR LIDIA.** Do not add either license text or mark this resolved until the owner decides and the exact upstream version is verified.
* **App icon:** `Assets.xcassets/AppIcon.appiconset` contains 18 PNG renditions of one apparent design. No author, source master, assignment, or license statement was found. Owner must provide first-party authorship/assignment evidence or a verifiable third-party source and license.

## Source records requiring a network-enabled/manual pass

| URL to check | Historical title / credited creator(s) | Bundled filename mapping to verify | Current finding and remaining uncertainty |
|---|---|---|---|
| https://opengameart.org/content/barrels-mage-city-arcanos-remix | Barrel Sprites — AntumDeluge | `barrels.png` | Page, download, exact contributors, license, and pixel mapping not reachable. |
| https://opengameart.org/content/16x16-and-animated-lava-tile-45-frames | Lava Sprite — davesch | `lava.png` | Page, download, license, and exact mapping not reachable. |
| https://opengameart.org/content/flying-terror | Flying Terror — Danimal | `flying_terror.png` | Page, download, license, and exact mapping not reachable. |
| https://opengameart.org/content/edited-and-extended-24x32-character-pack | Edited and Extended 24x32 Character Pack — diamonddmgirl | `a1.png`, `k1.png`, `q1.png`, `p1.png`, `pr1.png`, `c1.png`, `o1.png`, `t1.png` | Contributor chain, licenses, and mapping of each extracted sheet not reachable. |
| https://opengameart.org/content/bomb-2 | Bomb Sprite — IndigoFenix | `bomb.png` | Page, download, license, and exact mapping not reachable. |
| https://opengameart.org/content/spinning-gold-coin | Spinning Gold Coin — morgan3d | `goldCoin1.png`–`goldCoin9.png` | Existing audit records CC BY 3.0. Current page/download revalidation and pixel comparison could not be performed in this environment; retain the resolved record but obtain archival evidence before release. |
| https://opengameart.org/content/rpg-indoor-tileset-expansion-1 and https://opengameart.org/content/16x16-indoor-rpg-tileset-the-baseline | Castle Interior / Indoor RPG Tileset — Redshrike | `castle1.png`, `castle2.png` | Contributor chain, licenses, and source regions not reachable. |
| https://opengameart.org/content/16x16-pixel-art-dungeon-wall-and-cobblestone-floor-tiles | Dungeon Wall Sprite Sheet — D. Siegmund | `wallGreyFront.png`, `wallGreyLeftSide.png`, `wallGreyRightSide.png`, four `DoorGrey*.png`, `ChestSide.png`, `ChestFront.png`, `ChestBack.png` | Exact extraction mapping, license, and modification permission not reachable. |
| https://opengameart.org/content/lpc-terrains | LPC Terrains — bluecarrot16 | `terrain.png` | Contributor chain, license, and exact mapping not reachable. |
| https://opengameart.org/content/lpc-medieval-village-decorations | LPC Medieval Village Decorations — bluecarrot16 | `chests.png` | Contributor chain, license, and exact mapping not reachable. |
| https://opengameart.org/content/lpc-animated-water-and-waterfalls | LPC Animated Water and Waterfalls — ZaPaper | `water.png` | Contributor chain, license, and exact mapping not reachable. |
| https://opengameart.org/content/rpg-tiles-cobble-stone-paths-town-objects | RPG Tiles / Cobble Stone Paths / Town Objects — Zabin | `country1.png` | Contributor chain, license, and exact mapping not reachable. |
| https://opengameart.org/content/lpc-heroine | LPC Heroine / Lidia — Yamilian | `lidia.png` | Exact download and offered licenses require revalidation; no owner selection exists. Runtime extracts frames without changing the stored sheet. |

## No confident source lead

| Bundled files | Repository finding | Required owner/manual evidence |
|---|---|---|
| `heart.png` | No matching historical credit. | Identify creator/title/source and license, or document first-party ownership. |
| `floor.png` | Historical credit says “Floor Sprite — Bryce (2023)” without a source or ownership grant. | Identify Bryce fully and provide first-party authorship/assignment or distribution permission. |
| `skeleton.png` | No confident historical-credit mapping. | Locate exact upstream work or document first-party ownership. |
| `minotaur.png` | No matching historical credit. | Locate exact upstream work or document first-party ownership. |
| `minotaurWithAxe.png` | No matching historical credit; native use calls it a Ghost Wizard, conflicting with its filename. | Establish the depicted work's identity, creator, source, and license. |
| All 18 `Icon-App-*.png` files | No provenance record; renditions appear related but filename/appearance is not ownership evidence. | Provide source-master provenance and author/assignment/license documentation. |

## Modification and redistribution follow-up

The stored sprite sheets (`lidia.png`, `barrels.png`, `bomb.png`, `chests.png`, enemy sheets, terrain/water/castle/NPC sheets) are cropped at runtime. Dungeon wall, door, and chest-face PNGs appear extracted or repacked, but their editing history is unknown. For every verified upstream match, the reviewer must record whether the checked-in bytes are unchanged, cropped, resized, extended, or repacked; preserve required attribution; bundle the authoritative license text when its terms require it; and satisfy any share-alike, source, or corresponding-source requirement. Until all rows are resolved, **DISTRIBUTION REMAINS BLOCKED**.
