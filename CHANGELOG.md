## Unreleased - clock settings fix

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
