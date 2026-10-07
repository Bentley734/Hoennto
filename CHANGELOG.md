# Hoennto 0.2.4 beta - Oak intro protection and follower recall

- Recall WildFollowers 3 companions before Oak's Gen 1 approach, hold them through the escort/lab speech and restore their normal controller afterward.
- Animate visible companions shrinking into Pokeballs without changing follower preferences or party records.
- Keep the exact queued Oak actor scheduled if a people-list rebuild loses it, preserving native movement callbacks and dialogue.
- Cover fresh entry and unfinished-story revisits with imported Pokemon, including FireRed Charmander to Red.
- 18,900 assertions pass on both engine 0.3.54 and 0.3.58; 48 additional native runs with installed WildFollowers finish without overlap. The exact reported spontaneous freeze remains unconfirmed; the regression reproduces and recovers a lost-NPC callback freeze.
- Retain campaign format 2 and the minimum-only launcher requirement.

# Hoennto 0.2.3 beta - minimum-only launcher requirement

- Change the launcher requirement to `>=0.3.54`, removing the upper version limit that blocked newer launcher releases.
- Retain existing campaigns, transfer behavior and audio settings.
- Validate the range with the native manifest/semver parser; all 4,693 existing automated checks pass.

# Hoennto 0.2.2 beta - Gen 1 to Gen 2 travel fix

- Fix Gen 1 departure resolving Pokemon against an unloaded Gen 1 singleton after the destination runtime mounts. Retain the live native game owner for roster, save and options callbacks.
- Newly received Squirtle with Tackle and Tail Whip can transfer from Red/Blue/Yellow to Gold/Silver/Crystal and back.
- Preserve current DVs and stat experience between Gen 1 and Gen 2; derive the native HP DV and retain GB archives for GBA roundtrips.
- 4,693 automated checks pass. Separate integration passes with 1025Dex v1.2.15 transfer/storage adapters; full native playthrough remains pending.
- Retain campaign format 2, existing save links and the companion transfer API.

# Hoennto 0.2.1 beta - older-game fixes and travel cards

- Fix Gen 1/2 cold startup by installing the Gen 3 options guard only in its native runtime.
- Keep older-game arrival fades, notices and follower preference sync free of Gen 3 imports.
- Use the native Gen 2 options writer and restore native Gen 1 option aliases on save adoption/revisits.
- Replace the scrolling travel list with colored destination cards, generation/story/ROM status, grid navigation, mouse hover/wheel and touch controls.
- Refresh the eleven-story overview and departure confirmation; paginate long compatibility notices.
- 4,244 automated checks pass, including strict no-Gen-3-import tests for all six older games and actual native Gen 2 options persistence. Browser layout inspected; full native playthroughs remain pending.
- Retain campaign format 2, reserve data, fades/spinner and the 1025Dex transfer API.

# Hoennto 0.2.0 beta - eleven-game travel

- Support all eleven games on gen1recomp 0.3.54, including Ruby and Sapphire.
- Add common TRAVEL picker, controller/keyboard/touch controls and eleven-story overview.
- Transfer compatible Pokemon across generations; preserve unsupported records and storage overflow in campaign reserve.
- Archive native per-generation forms, migrate old campaigns and retain separate stories/save slots.
- Expose live registry resolver hooks for the upcoming eleven-game 1025Dex update; no fixed dex ceilings.
- Retain fades/spinner and source-checkpoint recovery; add generation-aware native lifecycle/options handling.
- 3,964 headless assertions pass. Native eleven-game playthroughs remain pending; see VALIDATION.md and LIVE_TESTING.md.
# Hoennto 0.1.7 beta - region transitions

- Fade out before travel and fade in after arrival or successful rollback.
- Draw a rotating Pokeball in the bottom-right during loading, with no game-art dependency.
- Refresh at native cache and graphics checkpoints without reentering gameplay; restore temporary wrappers and graphics state on failures.
- Hold gameplay/input through the transition and clear pending input on arrival.
- Preserve the 0.1.6 Emerald clock/settings fix and version-1 saves.
- 1,869 passing headless assertions. Live graphical travel remains pending; individual synchronous operations can still pause the spinner.

# Hoennto 0.1.6 beta - clock settings fix

- Prevent Emerald clock setup/viewing from nesting a default options block and resetting WildFollowers count and idle settings.
- Install the session-options guard through the real mod sandbox; no engine patch is required.
- Verify the stock clock call and sharing across FireRed, LeafGreen and Emerald with 316 additional checks (1,806 total). Live gameplay verification remains pending.

# Hoennto 0.1.5 beta

- Rename the launcher title, new linked save-slot names and logs to Hoennto.
- Add Bentley734/Hoennto GitHub update metadata.
- Preserve kanto_hoenn internal identity, existing settings and version-1 saves.
- Explain shared Pokemon/trainer/dex and independent regional progress before
  the first journey. Name the destination and distinguish new/returning stories.
- Confirm departure with native YES/NO controls, default NO and B cancellation.
- Present an instant native loading message before the safe runtime handoff.
- Add read-only Campaign Overview to Mod Options with cartridge selection,
  regional badge counts and current/last saved locations.
- Block travel for detected companion enablement/target/source-load mismatches;
  recheck before departure. Leave companion settings under player control.
- Extend headless coverage to 1,490 passing assertions and include a pending
  live acceptance checklist. Graphical/full-story verification remains pending.

Install this update manually once: older releases do not contain the GitHub
field and cannot discover the new repository themselves. Subsequent updates
require newer tagged GitHub releases with an attached mod ZIP.

Compatible engine: gen1recomp >=0.3.51 <0.3.52. Restart after installation.

