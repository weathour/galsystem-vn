# Architecture

`galsystem-vn` is a Godot 4.6 ADV / visual-novel runtime skeleton. The current architecture keeps story state and backend execution separate from the player-facing presentation layer.

## Runtime entry

```text
project.godot
└── run/main_scene = res://scenes/Main.tscn
    └── scripts/presentation/VNDirector.gd
```

`VNDirector.gd` owns the running shell: title flow, input handling, typewriter behavior, command dispatch, UI component wiring, audio players, smoke-test entry points, and presentation snapshots.

## State and persistence

- `autoload/VNState.gd` is the canonical story state source:
  - flags;
  - variables;
  - affection;
  - current route/chapter/day/worldline;
  - backlog;
  - CG/TIPS unlocks.
- `autoload/SaveSystem.gd` stores JSON save payloads:
  - save metadata;
  - active backend;
  - VNState snapshot;
  - ScenarioRunner checkpoint or Dialogue Manager snapshot;
  - presentation snapshot;
  - phone/calendar/flow snapshots.
- `SaveSystem.peek_slot()` reads save metadata safely for UI slot cards without restoring runtime state.

## Story backends

### `.galscript`

- `autoload/ScenarioRunner.gd` parses and executes the public line-oriented `.galscript` format.
- Public demo entry: `scenario/common/prologue.galscript`.
- Command contracts are documented in `scenario/command_registry.json` and checked by `tools/lint_galscript.py`.

### Dialogue Manager

- Dialogue Manager is vendored under `addons/dialogue_manager/`.
- `scripts/systems/DialogueManagerAdapter.gd` converts Dialogue Manager lines/responses into dictionaries consumed by `VNDirector.gd`.
- `.dialogue` mutation commands reuse the same presentation/system command path where possible.
- Public demo entry: `scenario/dialogue_manager/chapter_01.dialogue`.

### Private compatibility hooks

- `scripts/systems/NarcissuAssetResolver.gd`, `NarcissuCommandExecutor.gd`, and `NarcissuRuntimeProfile.gd` support local compatibility experiments.
- Public repository smokes skip cleanly when `reference_private/` data is absent.
- No private scripts/assets are distributed.

## Presentation layer

Current player-facing UI components live under `scripts/ui/`:

```text
VNTheme.gd              shared style helpers
TitleScreen.gd          full-screen title/menu and public-safe availability labels
DialogueWindow.gd       lower text window, namebox, advance indicator
QuickMenu.gd            Backlog / Auto / Skip / Save / Load / Q.Save / Q.Load / Config / Title
SystemMenuOverlay.gd    right-click/Esc system menu
BacklogOverlay.gd       scrollable backlog overlay
SaveLoadOverlay.gd      save/load slot cards
```

`VNDirector.gd` instantiates these components and connects their signals to runtime actions. The UI is script-built for now; future designer iteration can convert components to `.tscn` scenes without changing the runtime boundaries.

## Input model

- Left click / Space: advance or reveal active typewriter line.
- Right click / Esc: system menu.
- F1/F2: developer debug/flow panels.
- F5/F9: quick save/load slot 1.
- B/A/S/M: backlog, auto, skip, title.

## Smoke-test modes

`VNDirector.gd` supports CLI smoke flags:

```text
--galsystem-smoke
--galsystem-dm-smoke
--galsystem-narcissu-private-smoke
--galsystem-narcissu-local-smoke
--galsystem-qa-invalid-save
--galsystem-screenshot-smoke
--galsystem-public-title-smoke
```

These are intentionally runtime-level tests: they exercise the same Godot scene and autoloads as the interactive project.

## Public safety boundary

The architecture intentionally allows local compatibility studies without publishing private data:

- private inputs live under ignored directories;
- title menu disables private entries when data is missing;
- public smokes skip private cases cleanly;
- publication checklist verifies Git tracking before release.
