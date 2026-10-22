# Hoennto v0.2.6 beta

One trainer across all eleven native stories on gen1recomp **0.3.54 or newer**: Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire and Emerald.

## Setup

1. Import the ZIP through the launcher; enable Hoennto for every game you want to visit.
2. Import each destination's original ROM and let its import finish.
3. Open **START -> TRAVEL**, select a cartridge, then confirm with A or the Travel button. B cancels. Keyboard, controller and touch are supported.
4. **MODS -> Hoennto -> OPTIONS -> CAMPAIGN OVERVIEW** lists eleven stories and the reserve count.

The travel menu uses the supplied illustrated cartridge buttons, grouped as Gen I, Gen II, Gen III and Gen III remakes. All eleven stories stay visible, including the current cartridge. Labels show live new/continuing/current story and ROM availability. Use the D-pad, mouse hover/wheel or tap a card; confirm before departure. Long setup notices support pages. Artwork is cached lazily and uses the same native-independent overlay on all games.

Missing imports and detected companion mismatches explain what to fix before departure. Fades and the bottom-right rotating Pokeball remain enabled. Loading is synchronous: individual blocking operations can pause the spinner between refresh checkpoints.

## Pokemon and stories

Party, PC Pokemon, trainer identity and compatible dex records travel across generations. Species, moves and items resolve against destination live registries. Unsupported Pokemon, Gen 1 eggs, incompatible moves/items, cross-generation mail carriers and storage overflow remain in campaign reserve and return in a compatible destination. Gen 1 cannot use held items: Hoennto now archives the held item in the campaign while its carrier visits Gen 1, then restores it on return to a compatible Gen 2/3 cartridge. If no member of an existing party can travel, the source checkpoint is restored. Reserve has no individual management screen in this beta.

Native representations are archived per generation. Same-generation transfers retain native data. Cross-generation transfers update nickname, experience, moves/PP, OT, friendship, status and compatible items, recalculate native stats and preserve proportional HP. Gen 1/2 transfers preserve current DVs and stat experience, including training since the last visit. Transfers between GB and GBA restore archived native IV/DV and effort data when available; first visits convert IVs/DVs and start target-generation effort values at zero. Gen 1/2 boxes use compact lists; Gen 3 allows sparse slots. Older formats cannot expose every later-generation field; returning restores archived fields.

Hoennto remembers the main rival's name from your first departure and uses it in the other linked stories. For example, leave Red with `gary` and the Hoennto-created Blue, Yellow, Gold, Silver, Crystal, Ruby, Sapphire, Emerald, FireRed and LeafGreen stories use `gary`, including native dialogue and rival battle names. Ruby/Sapphire/Emerald rename the May/Brendan rival; Wally and other trainers keep their identities. Unrelated saves are untouched, and your original source story keeps its own native rival field.

Existing campaigns establish this name on their first departure after updating. Start from the game whose rival name you want to keep; existing linked destinations adopt it on loading/revisit. Once chosen, later departures do not replace it. In linked Gen 2 destinations, the police naming event reuses the known campaign name and resumes its native script without asking you to rename him. If the first source is Gen 2 and its rival is still `???`, Hoennto waits for that source's naming event instead of borrowing a destination default. A Hoenn source uses its native May/Brendan name when no custom rival field exists.

Each cartridge keeps its own badges, flags, bags, money, PC items, daycare, healing locations and story unlocks. First travel creates a new linked slot instead of replacing an unrelated save. Later visits resume its saved location. Ruby/Sapphire/Emerald use native truck initialization. Older games enter their native new-save world; this beta does not replay every naming/introduction screen. Normal saves update the collection; linked-slot loading projects it before native validation.

In Gen 1, WildFollowers 3 companions recall into Pokeballs before Oak approaches at the grass boundary. They stay recalled through his escort and starter speech, then return. Hoennto preserves Oak's native script and can restore a queued moving Oak NPC lost from the update list. Imported Pokemon remain with you.

**RESET DESTINATION** selects the inactive story for the erase action. Confirmation defaults to NO. Shared Pokemon and other stories remain. Native follower preferences continue sharing where supported.

## Compatibility

Version-1 campaigns migrate to format 2. Internal ID/save key stays `kanto_hoenn`, retaining old links and options. Keep a pre-upgrade save copy: older Hoennto versions cannot read the new collection format.

Use a 1025Dex release that supports both linked games. Its expanded registries and storage adapter use [COMPANION_API.md](COMPANION_API.md). The transfer layer has no fixed national-dex ceilings. Compatible species/follower companions must support and be enabled for both endpoints; detected mismatches block travel.

The launcher requirement has a minimum of 0.3.54 and no upper version limit. Launcher updates use `Bentley734/Hoennto` and `kanto_hoenn-0.2.6.zip`.

## Beta validation

**20,917 headless assertions pass on engine 0.3.54 and 0.3.58**, including all 110 directed routes and return trips, actual mod sandbox execution and native save schemas for eleven games. The runtime fixture uses the native Gen 1 loader facade and checks newly received Squirtle across all nine Gen 1-to-Gen 2 routes. A separate integration run passes with the installed 1025Dex transfer/storage adapters. Strict startup tests reject all Gen 3 module requests from Gen 1/2; native Gen 2 settings read/write also runs in the suite. Runtime mount/render services use fixtures. Full native graphical playthroughs remain pending. See [VALIDATION.md](VALIDATION.md) and [LIVE_TESTING.md](LIVE_TESTING.md).

Based on the [Pokemon Gen 1 Recompilation Project](https://github.com/bryanthaboi/gen1recomp) by BOIS CLUB GAMES, LLC; inspired by Johnto region travel. No ROMs, launcher executable or extracted game art are redistributed.

## 0.2.5 name repair

Blank and whitespace-only nicknames are treated as no nickname during save loading and travel. Missing display names are restored from the destination species registry. Existing party and PC Pokemon are repaired when loading their save, including old campaign records when projected. Genuine nicknames are preserved.

## 0.2.6 held-item travel

Fixes Pokemon such as Cyndaquil with an Oran Berry staying in reserve when travelling from FireRed to Red. The carrier travels normally; its held item is archived until it returns to a compatible game. Gen 1 cannot use or consume the archived item. Items removed or consumed after restoration are not recreated. Existing campaign reserve records become eligible on save loading. Unsupported moves/species, incompatible mail carriers and items unavailable in a Gen 2/3 destination still remain in reserve.

Button artwork supplied by the user, prepared as a transparent runtime atlas with the built-in image tool. Story labels are drawn live rather than baked into the artwork. No imported ROM art is added by this update.
