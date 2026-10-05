# Validation - v0.1.7 beta

Run in this workspace against the workspace gen1recomp 0.3.51 source using Lua 5.3
through Lupa 2.8, with a LuaJIT-style bit shim. Every test uses a fresh VM.

| Suite | Passing assertions |
| --- | ---: |
| Campaign serialization/isolation | 67 |
| Actual mod sandbox round trip/failed-arrival recovery - FireRed | 35 |
| Actual mod sandbox round trip/failed-arrival recovery - LeafGreen | 35 |
| Reset/settings/native option actions | 150 |
| Repeated campaign capture (100 transfers) | 800 |
| Stock audio lifecycle (80 reloads) | 325 |
| LeafGreen selection/native schema/ROM/manifest/compilation | 50 |
| Guidance, overview and compatibility | 22 |
| Stock native Message/Choice control flow in all three games | 21 |
| Native clock settings/stock-call regression | 316 |
| Transition timing, spinner refresh, graphics/cache cleanup (real sandbox) | 48 |
| **Total run for this release** | **1,869** |

The supplied LeafGreen USA 1.1 ROM passed native accessor/revision checks.
The engine manifest validator accepts Hoennto, version 0.1.7 and the GitHub
repository. Production Lua compiles. Campaign version remains 1 and internal
ID remains kanto_hoenn, preserving old save links and option buckets.

Native mount/render services are mocked in sandbox round trips. Native dialogue
uses real Message/Choice with fixture YES/NO text; imported fonts and species
packs are missing in the headless fixture. Its warnings are expected and do not
establish graphical correctness. The optional extracted-ROM bridge fixture and
the previous release's separate upstream schema suites were not rerun. Historical
v0.1.4 assertion totals are not added to this release's executed test count.

No interactive gameplay, graphical render QA, Windows close-button test or full
story playthrough was completed. See LIVE_TESTING.md for pending acceptance cases.

From the workspace root, with the workspace Lupa runtime installed:

    python run_tests.py

Individual tests can also run with LuaJIT from the engine source root, passing
an absolute mod directory as argument 1. Pass firered/leafgreen as argument 2
for kanto_hoenn_mod_test.lua, or the optional LeafGreen ROM path for
leafgreen_support_test.lua. Tests and fixture instructions are included in the ZIP;
engine source, test runtime and original ROMs are not.

## v0.1.6 clock settings fix

The full workspace suite now passes 1,806 assertions, including 316 clock/settings checks. The clock regression recreates the stock native Options.block(session.options) call and loads Hoennto's guard through the actual Sandbox.envFor environment. It covers counts 0-6, idle preferences, table identity and sharing across all three games. The local engine also has session-aware reads in four Emerald native screens; the published Hoennto guard is tested against the original stock clock call independently of those edits and WildFollowers' wrapper. Live clock/mom-event verification remains pending.

Run clock_settings_test.lua from the engine source root with the absolute Hoennto directory as argument 1.

## v0.1.7 transition coverage

Actual production transition.lua runs through Sandbox.envFor with recorded
LÖVE graphics calls and a controllable monotonic clock. Tests cover fade endpoints,
window-scaled bottom-right placement, changing rotation during slow cache reads,
30Hz refresh throttling, preserved multi-return values (including nils), cache
and graphics wrapper restoration, render-target and stack restoration, load and
draw errors, later mod replacements and inactive graphics. Source sandbox round
trips additionally fail Emerald loading and verify restored source profile,
checkpoint Pokemon, temporary reader cleanup and completed fade-in.

Visual QA: a standalone browser canvas preview replayed the actual Lua drawing
commands, using a neutral background. It verifies the geometric spinner's shape
and placement, not live game compositing, GPU state or loading responsiveness.
No engine source was edited for this animation. The native loader remains
synchronous; no uninterrupted animation claim is made for indivisible calls.
