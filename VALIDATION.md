# Validation - v0.2.1 beta

Executed against gen1recomp 0.3.54 source using Lua 5.3 / Lupa 2.8 and a LuaJIT-style bit shim. Each suite uses a fresh VM.

| Suite | Assertions |
| --- | ---: |
| Eleven-game collection transfers, 110 routes and roundtrips | 1049 |
| Sandbox runtime handoffs, 110 routes and roundtrips | 992 |
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
| **Total** | **4244** |

Collection tests cover reserve retention, unsupported moves/items, overflow, releases, sparse-to-compact boxes and synthetic expanded registries. Runtime tests execute production code through the real sandbox with mocked native service owners, checking retained host identity, independent stories and rollback. Native schema tests use actual engine save modules with synthetic ROM datasets. Ruby/Sapphire truck/reset-script requests and callbacks are checked; original ROM event bytecode is not executed.

Missing-font/species warnings and intentional failure logs are expected fixture output. Full native gameplay, Windows close-button behavior and eleven-game story completion remain untested. Browser replay of actual Lua draw commands checks panel layout only.

Run `python run_tests.py` from the workspace with Lupa installed. Lua tests ship in the ZIP; runtime, engine source and ROMs do not.

The new dependency suites deliberately reject every Gen 3 module request, including attempts hidden inside pcall. They cover all six cold older-game entries, game.ready, save adoption, menus, fades, notices, preference sync and lifecycle. Actual native Gen 2 options loading/writing verifies other cartridges and launcher slot registrations remain intact. This addresses the startup gap in v0.2.0 fixtures, which preloaded Gen 3 services.

The card picker, confirmation, overview and 480x320 layout were visually inspected in browser canvas replay of production Lua commands. Native LOVE compositing remains pending.
