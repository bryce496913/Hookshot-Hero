# Native audio port audit

Reviewed 2026-10-17 against main `55a75edff48383dda7c56d6cd8a6a82172737d07`.

## WAV files found in Java/resources

All **22** files are copied without changes to `ios/HookshotHero/Resources/Audio/`, retained in Java and included once in the application resource phase. No non-WAV binary is added or modified. `AudioAssetHashes.tsv` records SHA-256, channels, sample rate, bit depth and duration for every file. SHA-256/source-destination byte checks and Python PCM WAV parsing passed. Python parsing is not an AVFoundation or audible-output check.

| Filename | Java reference | Java event / class | iOS event / use | Bundled |
|---|---|---|---|---|
| `Atmosphere.wav` | GameAudio constructor; LevelOne/5/6.ApplyLevelMusic | Music: dungeon theme | Levels 1–3, 5–9 | Yes |
| `lava.wav` | LevelFour/10.ApplyLevelMusic | Music: boss theme | Levels 4 and 10 | Yes |
| `pretty-maiden-mageonduty.wav` | CountryRoad.ApplyLevelMusic; inherited by HeroWelcome | Music: ending theme | Country Road and Hero’s Welcome, including direct entry | Yes |
| `start.wav` | StartMenu constructor and startAudioLoop | Music: Java menu | Reserved; native menu stays silent | Yes |
| `walk.wav` | GameAudio.WalkAudio; World.PlayAudio(Player) | SFX: movement; incidental voice-wrapper Player requests | Committed normal grid steps only; no incidental voice-step sound | Yes |
| `step.wav` | GameAudio.StepAudio only | SFX: loaded but no active playback path found | Reserved, no invented usage | Yes |
| `hit.wav` | World.PlayAudio(Ball); World.UpdateBalls and Player lava path | SFX: projectile / direct hazard impact | Accepted Ghost projectile and lava damage | Yes |
| `whip.wav` | World.PlayAudio(Grapple); Player.Move and CheckObjectCollision | SFX: launch and second whip on enemy strike | Accepted Grapple launch and successful enemy damage | Yes |
| `coin.wav` | World.PlayAudio(Coin) | SFX: pickup | One per collected coin | Yes |
| `crunch.wav` | World.PlayAudio(Apple); World.HandleCollision food | SFX: food pickup | Cabbage pickup, including full health; never chest | Yes |
| `explosion.wav` | World.PlayAudio(Mine); Ball.HandleDamage | SFX: explosion | One per mine collision/destruction; no additional projectile explosion invented | Yes |
| `skeleton.wav` | Skeleton.HandleDamage; World.PlayAudio(Skeleton OR GhostWizard) | SFX: enemy damage; Ghost mapping configured but not requested | Skeleton damage only | Yes |
| `ft.wav` | FlyingTerror.HandleDamage; World.PlayAudio | SFX: enemy damage | Flying Terror damage | Yes |
| `monsterdamage.wav` | Minotaur.HandleDamage; World.PlayAudio | SFX: enemy damage | Minotaur damage; Ghost request remains commented out | Yes |
| `t3-healed3.wav` | Player.HandleVoice(Cabbage); World.PlayAudio(LidiaHealed) | Voice: Lidia healed | Food (Java explicitly includes full health) and actual chest healing | Yes |
| `t3-damaged1.wav` | Player.HandleVoice(Mine); World.PlayAudio(LidiaDamaged) | Voice: Lidia damaged | One per actual health-loss event | Yes |
| `t3-attack3.wav` | Player.HandleVoice(Skeleton); World.PlayAudio(LidiaAttack) | Voice: Lidia attacks | Successful enemy damage, including Ghost Wizard; never launch alone | Yes |
| `t2-healed3.wav` | Player.HandleVoice; World.PlayAudio(ShuraHealed) | Voice: Shura healed | Reserved; no native multiplayer | Yes |
| `t2-damaged1.wav` | Player.HandleVoice; World.PlayAudio(ShuraDamaged) | Voice: Shura damaged | Reserved | Yes |
| `t2-attack3.wav` | Player.HandleVoice; World.PlayAudio(ShuraAttack) | Voice: Shura attacks | Reserved | Yes |
| `t1-healed3.wav` | Player.HandleVoice; World.PlayAudio(AvaHealed) | Voice: Ava healed | Reserved; no native Ava/quest gameplay | Yes |
| `t1-damaged1.wav` | Player.HandleVoice; World.PlayAudio(AvaDamaged) | Voice: Ava damaged | Reserved | Yes |

## Java review and music source of truth

Reviewed GameAudio, World, Player, Skeleton, FlyingTerror, Minotaur, GhostWizard, Ball, HookshotHeroesGameEngine, GameOptions, BaseLevel, SinglePlayerWorldBuilder, DoublePlayerWorldBuilder, LevelOne, LevelFour, LevelFive, LevelSix, LevelTen, CountryRoad, HeroWelcome, StartMenu, and Java/README.md. Full-tree searches covered AudioRequest, AudioVoiceType, ApplyLevelMusic, ApplyTheme, playAudio, startAudioLoop, stopAudioLoop, HandleVoice and every WAV filename.

Both world builders select explicit themes only for Levels 1/4/5/6/10 and Country Road. BaseLevel.ApplyLevelMusic is empty; HeroWelcome inherits the Country Road theme. Native `GameMusicTrack.forLevel` explicitly maps all twelve destinations, so Level Select cannot inherit an unrelated previous track. Atmosphere covers 1/2/3/5/6/7/8/9; lava covers 4/10; Pretty Maiden covers both ending areas.

## Native audio architecture and lifecycle

GameAudioEvent is a transient domain callback, not save state, a SpriteKit observation or a popout animation. Successful movement/Grapple emit directly. Existing authoritative feedback emission also emits the corresponding domain audio event before a possible terminal callback. Accepted Ghost projectile damage has an additional typed impact event after the cooldown guard. GameSession gates audio by canSimulate and delegates to an injectable GameAudioServicing protocol; simulations never import AVFoundation.

GameAudioService holds playback policy. AVGameAudioBackend uses public AVFoundation APIs and an ambient AVAudioSession, respecting Silent mode and other audio without requesting microphone access. Session activation/resource/decoder failures log diagnostics and cannot block gameplay. Short common effects are prepared at startup. Music has one looping player: identical tracks retain the same player/current position, changed themes stop the previous player before starting another. Muting music pauses it and unmuting selects the current level theme.

The one-shot pool accepts up to 16 simultaneous players and caches at most one finished player per active effect. Completion immediately removes active players; overflow drops a new effect instead of cutting off a prior one. The long unchanged `ft.wav` (41.386 seconds), `skeleton.wav` (12.983 seconds) and `monsterdamage.wav` (5.590 seconds) require real-device mixing/performance review. They are not trimmed or re-encoded. Relative linear volumes: music 0.20, movement 0.035, normal SFX 0.25, voice 0.40. These preserve the intended relative roles without treating Java dB as linear volume.

User Pause/dialogue can retain music, but produce no new simulation SFX. Inactive/background pauses music and stops effects. Foreground resumes the desired theme only for active gameplay with Music enabled. Interruptions suspend playback; resume requires the system’s shouldResume flag. Headphone/route disconnection pauses sound until a new game or an explicit Music OFF→ON action, avoiding an unexpected speaker switch. Media-services reset discards invalid players and rebuilds on demand. Results stops music immediately while allowing an already-started terminal reaction to finish. Main Menu, loading failure and abandoned sessions stop all playback. Retained-session loading Retry selects the successfully installed destination theme.

## Java parity decisions

* Preserve the second whip at a successful enemy strike, plus the reachable enemy damage effect and Lidia attack voice. The launch whip remains mandatory. No audible divergence is claimed without device testing.
* GhostWizard.HandleDamage has a commented Minotaur request. World can map a hypothetical GhostWizard request to skeleton.wav, but that request is not emitted in the reviewed class. Native Ghost combat plays strike whip + Lidia attack voice, with no invented skeleton/monster impact sound.
* World.HandleCollision requests food voice even at maximum health; hooked cabbage also does so. Native full-health cabbage therefore plays crunch + one heal voice. Chest voice occurs only on actual health gain, with no crunch.
* Java HandleVoice wraps every voice as WorldObjectType.Player, unintentionally selecting walk.wav as well. Native voices do not fabricate walking sounds. Java can queue duplicate food voices across Player and World; native emits one voice per pickup. Hooked Cabbage’s Java request is not selected by the Apple-only crunch branch; native consistently supplies the required crunch for both pickup paths.
* Java Player lava damage queues Ball audio. Native lava damage plays hit + one damage voice; mines use explosion, and Ghost projectile impact uses hit. Cooldown rejection is silent.
* step.wav is loaded only: no StepAudio playback reference anywhere in Java. start.wav is active Java menu music; it ships reserved without introducing native menu music. All Shura/Ava clips ship reserved.

## Settings

Music and Sound Effects default ON independently. Missing or malformed fields fall back individually, preserving Reduced Motion, Control Hints and Control Layout. UserDefaults key and progression V3 schema remain unchanged. Settings publishers immediately update audio policy, including stop/pause when disabled. Effects OFF stops active voices/effects and blocks future ones while leaving music independently controlled.

## Validation

Executed: source/destination byte and SHA-256 checks for 22 WAVs; PCM header/format inventory; resource/source target-membership audit; git diff --check. Added mock-driven catalog, player-pool, policy, lifecycle, session/domain-event, settings migration/persistence and UI settings tests. Existing input, boss, progression and announcement tests remain.

**NOT EXECUTED:** Xcode Debug/Release builds, focused/full XCTest, UI tests, archived .app membership, AVFoundation decode tests, afinfo and physical-device/Simulator audible QA (Linux host has no Xcode/Simulator). The checked-in resource phase is build-configuration independent; archived inclusion still requires Xcode verification.

Manual pass: level transitions 1→2, 3→4, 4→5/6, 9→10, 10→Country Road→Hero’s Welcome; direct entry into 8/10/Hero’s Welcome; repeated Pause/Resume; Silent mode; other device audio; background/foreground, interruptions and headphone removal; every pickup/damage/strike/chest event and independent audio toggles. Listen specifically for long enemy-clip overlap and first-use latency. No audible correctness claim is made from mocks.

## Audio licensing and distribution blockers

See THIRD_PARTY_NOTICES.md and AudioLicenseAudit.md for file-by-file leads, current source-page observations and unresolved exact-file/redistribution checks. Copying an existing repository WAV or finding a permissive source page is not distribution clearance. Existing artwork blockers remain open. All audio remains blocked until exact provenance, selected applicable terms, notices/contributors and any required permission/license are verified.
