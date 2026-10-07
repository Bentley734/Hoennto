# Validation - v0.2.4 beta

Executed against gen1recomp 0.3.54 and the installed 0.3.58 source using Lua 5.3 / Lupa 2.8 and a LuaJIT-style bit shim. Each suite uses a fresh VM.

The manifest uses `>=0.3.54` with no upper bound. A separate native semver check accepts 0.3.54, 0.3.55, 0.4.0 and 1.0.0, and rejects 0.3.53. This verifies launcher range handling; gameplay validation below identifies the engine source used.

| Suite | Assertions |
| --- | ---: |
| Eleven-game collection transfers, 110 routes and roundtrips | 1049 |
| Sandbox runtime handoffs, 110 routes and starter regressions | 1064 |
| GB native DVs / stat experience, all 18 directed routes | 377 |
| Native all-game save schemas / Ruby-Sapphire initialization | 54 |
| Campaign serialization | 67 |
| FireRed / LeafGreen sandbox recovery | 70 |
| Reset/settings/menu | 150 |
| Native clock | 316 |
| Repeated capture | 800 |
| Stock audio lifecycle | 325 |
| LeafGreen/schema/manifest | 50 |
| Presentation | 22 |
| Stock Message/Choice | 21 |
| Transition timing/refresh/cleanup | 48 |
| Cold Gen 1/2 dependency boundary and native options | 105 |
| Older-generation bridge isolation / native Gen 2 options persistence | 119 |
| Travel panel native input / scaled touch / pagination | 56 |
| Native Gen 1 Oak intro / imported GB-GBA party / revisit / recall / lost-NPC recovery | 14207 |
| **Total per engine version** | **18900** |

Collection tests cover reserve retention, unsupported moves/items, overflow, releases, sparse-to-compact boxes and synthetic expanded registries. Runtime tests execute production code through the real sandbox with mocked native service owners, checking retained host identity, independent stories and rollback. Native schema tests use actual engine save modules with synthetic ROM datasets. Ruby/Sapphire truck/reset-script requests and callbacks are checked; original ROM event bytecode is not executed.

Missing-font/species warnings and intentional failure logs are expected fixture output. Full native gameplay, Windows close-button behavior and eleven-game story completion remain untested. Browser replay of actual Lua draw commands checks panel layout only.

Run `python run_tests.py` from the workspace with Lupa installed. Lua tests ship in the ZIP; runtime, engine source and ROMs do not.

The new dependency suites deliberately reject every Gen 3 module request, including attempts hidden inside pcall. They cover all six cold older-game entries, game.ready, save adoption, menus, fades, notices, preference sync and lifecycle. Actual native Gen 2 options loading/writing verifies other cartridges and launcher slot registrations remain intact. This addresses the startup gap in v0.2.0 fixtures, which preloaded Gen 3 services.

The card picker, confirmation, overview and 480x320 layout were visually inspected in browser canvas replay of production Lua commands. Native LOVE compositing remains pending.

The runtime fixture now uses the actual native Loader:_game() facade. Gen 1 singleton eviction is modeled; the previous always-retained mock hid the Gen 1-to-Gen 2 empty-registry failure. Native Pokemon.new constructs a newly received Squirtle with Tackle and Tail Whip for all nine Gen 1-to-Gen 2 routes and returns. Replacing the fixed owner getter with the old lookup makes Red-to-Gold fail, confirming this regression catches the reported defect.

A separate 1,073-check matrix run loads the installed 1025Dex v1.2.15 compatibility and storage adapters for the starter cases. Transfers, return trips and 52-box storage pass. This is adapter integration with fixture registries, not a complete 1025Dex native gameplay test. GB stat regressions use actual Pokemon.new/Mon.new and native calculators to check live DVs, effort, proportional HP, nonaliasing and GBA archive retention.

The Oak suite executes native Red/Blue/Yellow story scripts, TextBox, StateStack, NPC/Player movement, commands and map warps with synthetic maps/art and real font metrics. It imports Gold Squirtle and FireRed Charmander through the production roster, including capture/restore of an unfinished Red bedroom visit. It verifies dialogue, escort, lab speech, original party identity, native flags, recall rendering/list membership, controller restoration and freshBoot triggers. Yellow's fixed capture battle presentation is stubbed; its native story callbacks and transition run.

A negative control reproduces silent Oak arrival by removing the exact moving Oak actor from the NPC update list while leaving it visible. A presses cannot unblock the pending native movement callback. Protection reinserts the original actor and completes the same native scene without skipping dialogue or changing flags directly. This is a tested failure mode, not proof of the exact spontaneous cause on the user's save.

A private integration matrix also runs 48 full native intros with the installed WildFollowers 3.0.0-beta.4 controller, extracted dialogue, native Oak STAY/NONE behavior, entry columns 8 through 11 and four RNG seeds: all finish with zero overlaps (unprotected control: 48 overlaps). Private extracted game data and diagnostic fixtures are excluded from the release. The installed 0.3.58 native story scripts were checked, and its full automated suite passes. Full graphical acceptance of the reported save remains pending.
