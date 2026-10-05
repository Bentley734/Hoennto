# Hoennto v0.1.5 beta

A mod-only dual-story campaign for gen1recomp **0.3.51**. No custom executable,
app patch, installer or replacement engine files are needed.

## Setup

1. Import this ZIP with the recomp's normal mod manager. Enable **Hoennto**
   for your chosen Kanto game (FireRed or LeafGreen) and Emerald.
2. Import your original **FireRed or LeafGreen** and **Emerald** ROMs once through the normal
   launcher, if you have not already imported both. Let each import finish.
3. Start or continue either game. Select **HOENN** or **KANTO** from START,
   read the first-trip guide, and confirm departure. Confirmation defaults to NO.
4. Open MODS -> Hoennto -> OPTIONS -> **CAMPAIGN OVERVIEW** for each
   cartridge's badges and current/last saved location.

If the destination ROM has not been imported completely, travel stays in the
current region and tells you which game to import. No ROM data is bundled.

## Campaign behavior

Your trainer name, gender, Trainer ID/Secret ID, party, boxed PokÃ©mon and
PokÃ©dex seen/caught records travel together. PokÃ©mon retain their experience,
HP/status, IVs/EVs, nicknames, moves/PP, held items and original trainer details.
Box layout and names also travel.

Each region keeps its own eight badges, story flags and variables, trainers,
items/key items, money, PC items, healing locations, daycare and regional
systems. National Dex story unlocks stay regional; catch records are shared.
The destination runs its native game profile and original ROM scripts.

The first trip to the other region creates a new campaign save slot and starts
that region's native story. It does not merge or overwrite an unrelated existing
save. Emerald starts with the real truck sequence and opening flags. Later trips
restore the exact saved position and story state. Normal saves synchronize the
shared roster into all linked game slots. FireRed and LeafGreen keep independent
stories, wallets, locations, badges and save slots when both are linked.

The mod rebuilds the native session between complete updates, keeping the Game
object the unmodified app uses. This is a runtime action performed by the mod;
it does not write app source, executables, or engine files.

Travel is only offered in normal field menus, and is canceled while an event
prevents saving. Battles, tutorials, link rooms and special challenge menus keep
their normal restrictions. Emerald arrival autosaving waits until the truck
sequence has finished and field control is safe.

Other mods keep their own per-game enablement. For expanded species, use a
compatible species mod in both games. This mod does not add Johnto's unrelated
animation assets, cheats or interface overhaul.

## Beta status

Automated checks cover campaign serialization, repeated transfers, separate
badges/story variables, shared party/boxes, native Emerald initialization, mod
sandbox loading and retaining the host Game object across travel. This workspace
has not run an interactive full playthrough. Test your campaign on a copied save
first. Full story behavior is supplied by gen1recomp 0.3.51 and inherits its
existing limitations. See VALIDATION.md for what was checked.

## Attribution

Inspired by the supplied Johnto 1.1.0 region travel behavior.
Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC
(https://github.com/bryanthaboi/gen1recomp).

No launcher, original game ROM or extracted game art is redistributed.


## 0.1.1 / WildFollowers 2.22.15 updates

In MODS -> Hoennto -> OPTIONS, ERASE HOENN SAVE appears while in FireRed; ERASE KANTO SAVE appears while in Emerald. Press A to open confirmation, which defaults to NO. Confirming YES closes the menu layers, saves the current region, and resets only the linked inactive region's story and save slot. Shared trainer identity, party, PC Pokemon, dex records and WildFollowers preferences are preserved. The ROM import and independent saves are retained. The next trip starts that region's native new-game story. When no linked inactive save exists, the action reports that there is nothing to erase.

WildFollowers native WILDS/FOLLOWERS/IDLE settings use the current region's settings when traveling and persist native option changes immediately, mirror them into both region option blocks, and restore those latest shared preferences when reopening a linked save. Your existing active-region preferences become the shared preferences on the first trip with this update. Other mods and native game options retain their own settings.

Followers can emerge during automatic entry dialogue after the actual fade, warp and entry/scripted movement have ended. Genuine movement, battle, forced-motion and transition gates are retained. Non-door floor/room warps receive the same settled-arrival check; their previous non-ball presentation is retained.

Additional headless checks: 69 reset/settings/menu assertions (both reset directions, inactive-only slot deletion, failed-save/delete handling, retained shared data, no save resurrection, default-NO confirmation and parent-menu closure); 28 entry-dialogue assertions (six followers, door/non-door entry, NPC movement/fade gates, distinct placement and production single-core appearance). Graphical playthrough and live end-to-end reset testing remain outstanding.

Immediate native-menu sharing: 14 additional checks cover menu edits in both directions, count/idle toggles, mutual-exclusion flags, loader option persistence and standalone isolation.

Successful resets rotate a clean source save into its native backup, removing the embedded inactive-region snapshot from that backup as well.

## 0.1.2 travel and shutdown fixes

The outgoing native audio worker is shut down before cartridge modules are evicted, including failed destination loads. This prevents old and new workers from sharing the same named channels and makes their registered process shutdowns safe. Restart the app after installing so any workers left by the older version are cleared.

Travel now makes one source checkpoint instead of two, preserves current-region follower settings when refreshing slot options, and reuses the checkpoint destination during native boot rather than rereading/parsing its file twice. The temporary save reader is restored on success or error. Arrival autosaving and peer-save mirroring remain enabled. Campaign snapshots skip shared party, PC boxes and dex fields before copying instead of copying and discarding them. The campaign format stays version 1; existing linked saves remain compatible. Native cartridge and enabled-mod loading still takes time; no wall-clock end-to-end speed claim has been measured.

Validation: 200 passing headless assertions: 67 campaign, 26 actual sandbox roundtrip/teardown/checkpoint reader, 69 reset/settings/menu, and 38 actual stock audio owner checks across 12 region loads with simulated thread/channels and process exit. These are not a graphical Windows close-button test or a full story playthrough. A synthetic 1920-Pokemon storage benchmark confirmed snapshots omit shared data without losing regional fields.

## 0.1.3 repeated-switch memory fix

Native audio re-registers a process shutdown closure after every cartridge reload. Stopping its thread in 0.1.2 fixed competing workers, but the process list still retained those old module graphs. The mod now intercepts registration only during its own remount and installs one forwarding audio shutdown callback. Other callbacks are forwarded unchanged, and the native registration function is restored even if loading fails. Outgoing audio still shuts down before eviction. The initial pre-mod callback remains; the callback list no longer grows on each trip. Fully restart after updating to clear callbacks left by earlier versions.

Save-writing clones only mutable campaign metadata and the regional index; it replaces the shared roster and current regional snapshot with fresh captures. Unchanged regional snapshots remain immutable. Old checkpoints are not modified. A 100-transfer test verifies roster/story preservation and bounded serialized campaign size.

Each switch logs save, release, load durations and Lua heap size, allowing remaining native/import/mod loading delays to be distinguished from gradual retention. These timings are runtime diagnostics, not an asserted speedup. Mod ZIP only; no app files are modified.

1287 headless checks pass: campaign 67, mod sandbox/handoff 26, reset/settings/menu 69, repeated capture 800, stock audio lifecycle 325. The lifecycle test performs 80 reloads, verifies constant callback count and garbage collection of all 79 retired audio modules, joins every worker and checks error cleanup/unrelated callback preservation. Live Windows timing still needs testing.

## 0.1.4 â€” FireRed / LeafGreen support

One mod supports **FireRed + Emerald** or **LeafGreen + Emerald** on stock
gen1recomp 0.3.51. Import LeafGreen normally and enable the mod for LeafGreen.

In MODS â†’ Hoennto â†’ OPTIONS, **KANTO GAME** offers **AUTO**, **FIRERED**
and **LEAFGREEN**. AUTO remembers the Kanto game used by this campaign. For a
fresh Emerald campaign, it uses FireRed if imported, otherwise LeafGreen.
When both are imported, select the desired game explicitly. From either Kanto
game, HOENN always goes to Emerald. The selection determines the KANTO return
trip from Emerald; it does not change your current game immediately.

Existing version-1 linked saves remain compatible and default to their linked
FireRed story. Selecting LeafGreen from an existing campaign creates a separate
LeafGreen campaign slot on first arrival; it does not convert your FireRed story
or overwrite an unrelated LeafGreen save. You can return to the other Kanto game
by changing KANTO GAME in Hoenn. Shared trainer/Pokemon/dex follow you; each game
keeps its own progress. Use compatible 1025Dex and WildFollowers versions enabled
for every game you travel to.

The confirmed ERASE KANTO SAVE action in Emerald targets the currently selected
Kanto game and names that game in its confirmation. ERASE HOENN SAVE works from
either Kanto game. Other linked game stories and shared Pokemon are retained.
WildFollowers preference sharing and the 0.1.3 audio/lifecycle fixes are retained.

Automated checks cover both Kanto round trips, selection and legacy-save
inference, all four reset directions, separate FireRed/LeafGreen native save
schemas and LeafGreen new-game/resume initialization. The supplied USA LeafGreen
1.1 ROM passed the engine's native ROM accessor/revision-selection checks.
Interactive gameplay and rendering across LeafGreen travel still need testing.

## 0.1.5 - Hoennto polish

The launcher name, notices, logs and new campaign slot names now say Hoennto.
The internal `kanto_hoenn` ID, options bucket and version-1 campaign key remain
unchanged so existing saves and settings continue to work. Existing slot names
are retained. Disable/remove duplicate manual installs of the old ZIP if your
launcher does not replace the existing installation by ID.

Travel explains shared and regional progress on the first confirmed journey,
names the exact destination cartridge and distinguishes new stories from saved
returns. A native YES/NO prompt defaults to NO and supports B cancellation.
A short native loading message is presented before the between-update handoff.
Campaign Overview is a read-only Mod Options action; it shows all three stories,
native regional badge counts, readable map identifiers and selected Kanto return.

Travel checks known 1025Dex/WildFollowers companions and species/pokedex-tagged
mods for native game targets, per-game enablement and source loading. A mismatch
blocks departure and explains how to fix the setup. The check runs again before
saving/departure. It does not enable companions or certify arbitrary combinations.

Launcher updates use `"github": "Bentley734/Hoennto"`. Publish a GitHub release
with a semver tag such as `v0.1.5` and attach `kanto_hoenn-0.1.5.zip` (the launcher
prefers `<internal-id>-<version>.zip`). Keep tag, manifest and ZIP versions aligned.
This workspace does not publish the repository or release; the manifest metadata
alone cannot supply an update before a release asset exists.

Current headless validation: **1,490 passing assertions**. Native Message/Choice
control flow is exercised, with fixture YES/NO text and missing imported fonts;
this is not visual QA. See VALIDATION.md and LIVE_TESTING.md for exact coverage
and the pending live acceptance checklist.
