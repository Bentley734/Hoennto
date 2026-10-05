# Hoennto v0.1.5 live acceptance checklist

Status: **not executed in this workspace**. Source and headless fixtures are
available, but graphical native app control is unavailable in this session.
Imported font/species caches are absent from the headless fixtures. This beta
must not be described as visually verified or full-story tested.

Use gen1recomp 0.3.51 and a copied campaign. Record game, mod versions,
starting location, expected result, actual result, and a screenshot/log for
each failure. Exercise FireRed/Emerald and LeafGreen/Emerald separately, then
one campaign linking all three games. Keep the original saves as a baseline.

| Check | Expected result | Status |
| --- | --- | --- |
| Upgrade an existing v0.1.4 campaign | Hoennto displayed; party, boxes, dex, slots, selection and settings retained | Pending |
| First trip in each direction | Guide explains shared/regional rules; correct game named; NO selected initially | Pending |
| B or NO at departure | Remain in current game; no destination save created | Pending |
| YES at departure | Loading message appears; destination loads; one source checkpoint; safe arrival save | Pending |
| Overview in all three games | Correct cartridge, badge counts, current/saved locations; unstarted stories identified | Pending |
| Long dialogue/location names | Text stays within native windows; all pages readable with controller/keyboard | Pending |
| Companion disabled on either side | Actionable message; no switch or save-slot mutation | Pending |
| Matching 1025Dex/WildFollowers | Loaded in both games; expanded species and follower settings survive travel | Pending |
| Missing destination import | Correct ROM-import guidance; remain in source game | Pending |
| First Emerald arrival | Truck, moving-in, Birch rescue, starter and rival events work with existing party | Pending |
| First Kanto arrival | Bedroom, Oak introduction, starter and rival events work with existing party | Pending |
| Full party at starter events | No Pokemon lost or overwritten; native event completes or reports a clear restriction | Pending |
| Regional badge/HM/obedience checks | Each region uses its own native badge and story rules; verify shared Pokemon OT ownership | Pending |
| Separate regional data | Bags, wallets, PC items, daycare, story flags and healing locations remain regional | Pending |
| Shared Pokemon data | Nicknames, OT, IV/EV, XP, moves/PP, held items, HP/status and box names/layout survive | Pending |
| Save, quit and reopen each linked slot | Latest shared roster and independent regional story restored | Pending |
| 20 alternating trips | No old audio, stale menus, growing pause or memory trend; record timings and memory | Pending |
| Destination-load failure | Source checkpoint restored or launcher returned safely; no roster loss | Pending |
| Reset from all four directions | Only selected inactive story erased; shared roster and third game retained | Pending |
| Windows close after switching | Process exits promptly; no audio worker left running | Pending |
| Full stories and postgame | All gyms, Elite Four, story events and regional postgame remain playable | Pending |
| Launcher update from this release | Newer GitHub tag and attached mod ZIP found; same internal ID replaces installation | Pending |

Companion checks inspect known 1025Dex/WildFollowers names and species/pokedex
tags, native manifest game targets, per-game enablement, and whether the source
companion loaded. They cannot certify arbitrary mod combinations, extracted
assets, story behavior or runtime compatibility. Installed mod versions are
shared across launcher games; Hoennto does not invent separate version checks
or enable companion mods automatically.
