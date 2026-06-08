# Phase 4 Handoff: Mature VN Visual Layer in Godot

## Decision

Do **not** continue the current engineering-placeholder UI as the product direction.

Next phase should keep the existing Godot runtime, Narcissu import/resolver work, and save/load systems, but replace the presentation layer with a mature visual-novel UI pattern inspired by **Ren'Py** and **Dialogic**.

In short:

```text
Keep Godot runtime + current parser/resolver/state systems.
Replace the crude UI shell with a Ren'Py/Dialogic-style VN presentation layer.
```

## Why

The current Phase 3 work proves functionality:

- Narcissu private scripts can start.
- Local private media can resolve/load.
- Save/load/backlog/auto/skip paths exist.
- Mouse advance and title return now work.

But the visual result is still an engineering prototype:

- flat placeholder backgrounds;
- small/debug-looking title panel;
- weak text window styling;
- no polished quick menu;
- no proper VN system menu hierarchy;
- poor spatial composition;
- not visually comparable to mature VN engines.

The next phase is therefore a **visual/presentation rewrite**, not another parser/runtime phase.

## Mature VN visual target

Use established Ren'Py/Dialogic conventions as the design target:

### Screen/layout

- 16:9 presentation first, preferably 1280×720 baseline with scalable anchors.
- Background/CG fills the full screen.
- Text window sits at the lower 25–32% of the screen.
- Dialogue window has readable padding, semi-transparent material, border/skin, and high contrast.
- Status/debug text should not dominate the player-facing screen.

### Text UI

- Dedicated namebox above or attached to dialogue box.
- Dialogue text area with large readable font and consistent line height.
- Click/advance indicator.
- Text speed behavior preserved.
- Mouse left click advances; first click completes typewriter.
- Keyboard advance remains supported.

### Quick menu

Add a player-facing quick menu, usually near the bottom or side:

```text
Backlog | Auto | Skip | Save | Load | Q.Save | Q.Load | Config | Title
```

The quick menu should be visible during gameplay and hidden/disabled during title screen as appropriate.

### System menu

Esc/right-click should open a polished overlay menu with:

- Resume
- Save
- Load
- Backlog
- Auto toggle
- Skip toggle
- Return to Title
- Quit/Close menu

Return-to-title already exists as `M` and system-menu action; Phase 4 should present it cleanly.

### Backlog

Backlog should become a proper overlay:

- readable scroll area;
- speaker/name styling;
- day/route metadata de-emphasized or optional;
- close button and click/Esc close behavior.

### Save/load

Save/load should move from debug buttons to VN-style slot cards:

- slot number;
- timestamp;
- current script/chapter/label;
- current line excerpt;
- thumbnail placeholder or actual screenshot later;
- clear empty/filled slot states.

### Title screen

Replace the current centered debug panel with a real title menu:

- full-screen title composition;
- game title/logo area;
- buttons: Start, Load, Narcissu 1, Narcissu 2, Config, Quit;
- clear missing-private-data message when Narcissu scripts/assets are absent;
- no overlapping background label.

## Technical direction

Keep these systems:

```text
autoload/ScenarioRunner.gd
autoload/SaveSystem.gd
autoload/VNState.gd
autoload/FlowchartSystem.gd
scripts/systems/NarcissuAssetResolver.gd
scripts/systems/NarcissuCommandExecutor.gd
scripts/systems/NarcissuRuntimeProfile.gd
scripts/systems/DialogueManagerAdapter.gd
```

Refactor/rewrite around:

```text
scripts/presentation/VNDirector.gd
```

Implemented split for the current Phase 4 slice:

```text
scripts/ui/VNTheme.gd
scripts/ui/TitleScreen.gd
scripts/ui/DialogueWindow.gd
scripts/ui/QuickMenu.gd
scripts/ui/SystemMenuOverlay.gd
scripts/ui/BacklogOverlay.gd
scripts/ui/SaveLoadOverlay.gd
```

`VNDirector.gd` is now closer to an orchestrator: it wires runtime events, state, save/load, and component signals; the player-facing title/dialogue/system/backlog/save-load UI is no longer built inline. A future pass can convert these script-built components to `.tscn` scenes if designer iteration requires it.

## Acceptance criteria for Phase 4

Phase 4 is complete when:

1. Gameplay screen visually resembles a mature VN layout rather than a debug prototype.
2. Mouse left click advances reliably outside buttons/menus.
3. Esc/right-click opens a polished system menu.
4. Quick menu exposes Backlog, Auto, Skip, Save, Load, Q.Save, Q.Load, Config/Title.
5. Return-to-title is visible and tested.
6. Save/load overlay is usable and no longer debug-looking.
7. Backlog overlay is readable and player-facing.
8. Title screen is visually coherent and handles missing private data clearly.
9. Existing runtime behavior remains intact:
   - `.galscript` smoke passes;
   - Dialogue Manager smoke passes after editor import;
   - Narcissu private smoke passes/skips correctly;
   - Narcissu local smoke passes/skips correctly;
   - invalid save QA passes.
10. Add screenshot-based visual smoke evidence, preferably:

```bash
godot --headless --path . --quit-after 120 -- --galsystem-screenshot-smoke
```

Status: screenshot smoke command is implemented (`VNDirector.gd` writes the five PNG targets under `/tmp`). The Phase 4 UI component slice is also implemented: title screen, gameplay dialogue window, quick menu, system menu, backlog, and save/load now use script components under `scripts/ui/` plus a shared restrained VN skin. In Godot `--headless` dummy rendering, the smoke validates the UI flow and writes fallback placeholder PNGs; run the same flag without `--headless` in a graphical/Xvfb environment for true rendered visual evidence.

Expected screenshot set:

```text
/tmp/galsystem-title.png
/tmp/galsystem-gameplay.png
/tmp/galsystem-system-menu.png
/tmp/galsystem-backlog.png
/tmp/galsystem-save-load.png
```

## Suggested first implementation slice

Start with the smallest visible upgrade:

1. Extract `DialogueWindow` and `QuickMenu` scenes. **Done as script components under `scripts/ui/`.**
2. Restyle gameplay screen. **First pass done:**
   - full-screen background;
   - lower dialogue box;
   - namebox;
   - quick menu row;
   - click indicator.
3. Restyle and extract title/system/save/backlog internals. **Done as script components under `scripts/ui/`.**
4. Screenshot smoke is implemented for title, gameplay, system menu, backlog, and save/load.
5. Verify all existing smokes. **Done for this slice.**
6. Commit.

Then continue with:

- final visual QA pass in a graphical renderer;
- private-data absence messaging on title buttons;
- optional slot thumbnail capture;
- optional conversion from script-built UI components to `.tscn` scenes for designer iteration;
- final art/branding and typography pass.

## Current known visual issues to fix first

- Title menu has a player-facing first-pass layout; final art/branding can still improve it.
- Game background can become a flat blue placeholder when using synthetic fixtures.
- Dialogue box now has a VN-style frame, namebox, click indicator, and quick menu; final typography/art polish remains.
- Status text is hidden on title and reduced to subtle gameplay metadata, but should eventually become a timed notification/toast rather than persistent HUD copy.
- Save/load/backlog/system panels now have extracted player-facing components; actual screenshot thumbnails and final art polish remain.
- Quick menu exists and exposes Backlog, Auto, Skip, Save, Load, Q.Save, Q.Load, Config, and Title.
- Screenshot smoke is implemented, but overall VN polish still pending.

## Validation baseline before Phase 4 edits

Current HEAD after input/menu fix:

```text
886e3f2 Add title return and mouse advance
b952026 Fix save load panel lookup
```

Recent validation passed:

```text
galsystem smoke ok
narcissu private import smoke ok
narcissu local smoke ok
```

Known expected warnings remain:

- Dialogue Manager cleanup warnings at process exit.
- Invalid save QA intentionally logs a save payload error before confirming rejection.

## Stop condition for next conversation

The next conversation should begin Phase 4 as a visual/UI implementation pass, not more requirements discovery.

Default plan for next conversation:

```text
1. run graphical screenshot smoke and inspect true rendered PNGs;
2. add private-data missing/disabled states to title menu;
3. add optional save-slot thumbnail capture if time allows;
4. do a typography/final-art pass;
5. rerun screenshot + functional smokes;
6. commit Phase 4 visual component slice.
```
