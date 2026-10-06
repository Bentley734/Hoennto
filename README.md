# Hoennto v0.2.3 beta

One trainer across all eleven native stories on gen1recomp **0.3.54 or newer**: Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire and Emerald.

## Setup

1. Import the ZIP through the launcher; enable Hoennto for every game you want to visit.
2. Import each destination's original ROM and let its import finish.
3. Open **START -> TRAVEL**, select a cartridge, then confirm with A or the Travel button. B cancels. Keyboard, controller and touch are supported.
4. **MODS -> Hoennto -> OPTIONS -> CAMPAIGN OVERVIEW** lists eleven stories and the reserve count.

Destination cards show generation, new/continuing story and ROM availability. Use the D-pad, mouse hover/wheel or tap a card. Long setup notices support pages.

Missing imports and detected companion mismatches explain what to fix before departure. Fades and the bottom-right rotating Pokeball remain enabled. Loading is synchronous: individual blocking operations can pause the spinner between refresh checkpoints.

## Pokemon and stories

Party, PC Pokemon, trainer identity and compatible dex records travel across generations. Species, moves and items resolve against destination live registries. Unsupported Pokemon, Gen 1 eggs, incompatible moves/items, cross-generation mail carriers and storage overflow remain in campaign reserve and return in a compatible destination. Gen 1 cannot represent held items: remove the item in the source to bring its carrier. If no member of an existing party can travel, the source checkpoint is restored. Reserve has no individual management screen in this beta.

Native representations are archived per generation. Same-generation transfers retain native data. Cross-generation transfers update nickname, experience, moves/PP, OT, friendship, status and compatible items, recalculate native stats and preserve proportional HP. Gen 1/2 transfers preserve current DVs and stat experience, including training since the last visit. Transfers between GB and GBA restore archived native IV/DV and effort data when available; first visits convert IVs/DVs and start target-generation effort values at zero. Gen 1/2 boxes use compact lists; Gen 3 allows sparse slots. Older formats cannot expose every later-generation field; returning restores archived fields.

Each cartridge keeps its own badges, flags, bags, money, PC items, daycare, healing locations and story unlocks. First travel creates a new linked slot instead of replacing an unrelated save. Later visits resume its saved location. Ruby/Sapphire/Emerald use native truck initialization. Older games enter their native new-save world; this beta does not replay every naming/introduction screen. Normal saves update the collection; linked-slot loading projects it before native validation.

**RESET DESTINATION** selects the inactive story for the erase action. Confirmation defaults to NO. Shared Pokemon and other stories remain. Native follower preferences continue sharing where supported.

## Compatibility

Version-1 campaigns migrate to format 2. Internal ID/save key stays `kanto_hoenn`, retaining old links and options. Keep a pre-upgrade save copy: older Hoennto versions cannot read the new collection format.

Use a 1025Dex release that supports both linked games. Its expanded registries and storage adapter use [COMPANION_API.md](COMPANION_API.md). The transfer layer has no fixed national-dex ceilings. Compatible species/follower companions must support and be enabled for both endpoints; detected mismatches block travel.

The launcher requirement has a minimum of 0.3.54 and no upper version limit. Launcher updates use `Bentley734/Hoennto` and `kanto_hoenn-0.2.3.zip`.

## Beta validation

**4,693 headless assertions pass**, including all 110 directed routes and return trips, actual mod sandbox execution and native save schemas for eleven games. The runtime fixture uses the native Gen 1 loader facade and checks newly received Squirtle across all nine Gen 1-to-Gen 2 routes. A separate integration run passes with the installed 1025Dex transfer/storage adapters. Strict startup tests reject all Gen 3 module requests from Gen 1/2; native Gen 2 settings read/write also runs in the suite. Runtime mount/render services use fixtures. Full native graphical playthroughs remain pending. See [VALIDATION.md](VALIDATION.md) and [LIVE_TESTING.md](LIVE_TESTING.md).

Based on the [Pokemon Gen 1 Recompilation Project](https://github.com/bryanthaboi/gen1recomp) by BOIS CLUB GAMES, LLC; inspired by Johnto region travel. No ROMs, launcher executable or extracted game art are redistributed.
