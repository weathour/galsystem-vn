# galsystem-vn

**galsystem** is a Godot 4.6 ADV / visual-novel runtime skeleton for long-form branching stories. It combines a small self-built `.galscript` runner, a Dialogue Manager backend, centralized story state, save/load, backlog, auto/skip, phone/calendar route prototypes, and a Ren'Py/Dialogic-style presentation shell.

This repository is public-demo safe: it does **not** include private third-party visual novel assets or private reference scripts.

## Current status

Phase 5 is focused on making the project understandable, runnable, and verifiable from a fresh public clone.

Implemented now:

- Godot 4.6 project with `scenes/Main.tscn` as the runtime entry.
- Player-facing title screen, dialogue window, quick menu, system menu, backlog, and save/load components under `scripts/ui/`.
- Public `.galscript` demo at `scenario/common/prologue.galscript`.
- Dialogue Manager demo at `scenario/dialogue_manager/chapter_01.dialogue`.
- Centralized VN state: flags, variables, affection, route, chapter, day, worldline, backlog, CG/TIPS unlocks.
- Save/load slots, quick save/load, and save metadata preview cards.
- Phone/mail and calendar/affection route-condition prototypes.
- Headless smoke tests for public demo, Dialogue Manager, invalid saves, Narcissu compatibility entry points, and screenshot flow generation.
- GitHub Actions smoke workflow.

## What is intentionally not included

The project contains compatibility hooks and local tooling for studying private reference material, but this public repository does not distribute any copyrighted third-party VN content.

Excluded by `.gitignore`:

```text
reference_private/
external_reference/
```

Title-screen entries such as `Narcissu 1 Private` and `Narcissu 2 Private` are disabled in a fresh public clone until local private reference data is installed outside Git tracking.

## Requirements

- Godot `4.6.2-stable` or newer 4.6.x build.
- Python 3.10+ for tooling and lint smoke tests.

## Run the public demo

```bash
git clone https://github.com/weathour/galsystem-vn.git
cd galsystem-vn
godot --path .
```

Use the title menu:

- `Start Demo` for the public `.galscript` demo.
- `Start Dialogue Manager Demo` for the Dialogue Manager-backed short chapter.
- Private compatibility entries remain disabled unless local private reference data exists.

## Controls

- Left click / Space: advance text; if typewriter is active, reveal current line first.
- Right click / Esc: system menu.
- Quick menu: Backlog, Auto, Skip, Save, Load, Q.Save, Q.Load, Config, Title.
- F1: developer debug panel.
- F2: flow panel.
- F5: quick save slot 1.
- F9: quick load slot 1.
- B: backlog.
- A: auto mode.
- S: skip mode.
- M: return to title.

## Validation

Run local tool checks:

```bash
python3 tools/import_nscripter_case.py --self-test
python3 tools/build_narcissu_manifest.py --self-test
python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
```

Run Godot smoke tests:

```bash
godot --headless --path . --quit-after 3
godot --headless --path . --quit-after 120 -- --galsystem-smoke
godot --headless --path . --quit-after 120 -- --galsystem-dm-smoke
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-private-smoke
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-local-smoke
godot --headless --path . --quit-after 120 -- --galsystem-qa-invalid-save
godot --headless --path . --quit-after 120 -- --galsystem-public-title-smoke
godot --headless --path . --quit-after 120 -- --galsystem-screenshot-smoke
```

Notes:

- `--galsystem-dm-smoke` may ask for one editor import pass on a fresh checkout. If needed, run:

  ```bash
  godot --headless --import --path .
  ```

- Narcissu private/local smokes are public-safe: they pass when private local data exists and skip cleanly when it does not.
- In pure `--headless` dummy rendering, screenshot smoke validates UI flow and writes fallback PNGs under `/tmp`. Use a graphical environment for real rendered screenshots.

Expected screenshot outputs:

```text
/tmp/galsystem-title.png
/tmp/galsystem-gameplay.png
/tmp/galsystem-system-menu.png
/tmp/galsystem-backlog.png
/tmp/galsystem-save-load.png
```

## Architecture overview

Key runtime layers:

- `autoload/VNState.gd` — canonical story state.
- `autoload/ScenarioRunner.gd` — self-built `.galscript` runner and checkpoint source.
- `scripts/systems/DialogueManagerAdapter.gd` — Dialogue Manager backend adapter.
- `autoload/SaveSystem.gd` — JSON save/load and safe slot metadata reads.
- `scripts/presentation/VNDirector.gd` — runtime orchestrator and command dispatch.
- `scripts/ui/*.gd` — player-facing VN UI components.
- `scripts/systems/PhoneSystem.gd` and `CalendarSystem.gd` — route-condition prototypes.
- `autoload/FlowchartSystem.gd` — lightweight debug/flow tracking.

See `docs/ARCHITECTURE.md` for details.

## Documentation

- `PRODUCT.md` — product/design register for the VN presentation layer.
- `docs/ARCHITECTURE.md` — current runtime architecture.
- `docs/ROADMAP.md` — planned phases and future work.
- `docs/PUBLICATION_CHECKLIST.md` — public-release safety checklist.
- `docs/DIALOGUE_MANAGER_INTEGRATION.md` — Dialogue Manager backend notes.
- `docs/NARCISSU_CASE_STUDY.md` — compatibility-study notes without distributing private data.

## Third-party code

Dialogue Manager is vendored under `addons/dialogue_manager/` with its own license file at `addons/dialogue_manager/LICENSE`.

## License

Project code is released under the MIT License. See `LICENSE`.

Third-party assets, VN scripts, or private reference materials are not licensed by this repository and are not distributed here.
