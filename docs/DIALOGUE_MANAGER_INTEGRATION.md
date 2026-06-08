# Dialogue Manager Integration

## Status

Dialogue Manager is now integrated as a second dialogue backend.

- Addon: Nathan Hoad Dialogue Manager
- Version: `v3.10.4`
- Source: GitHub release/tag `nathanhoad/godot_dialogue_manager@v3.10.4`
- Godot target: 4.6.x
- License: MIT, included under `addons/dialogue_manager/LICENSE`

The existing `.galscript` runner remains available as the Phase-1 fallback backend.

## Why v3.10.4 instead of Dialogue Manager 4

As of this integration, the upstream repository README describes Dialogue Manager 4 as the Godot 4.6+ main branch but explicitly recommends using version 3 until Dialogue Manager 4 is officially released. The Godot Asset Library and release listings identify `v3.10.4 for Godot 4.6` as the current stable release. Therefore this project uses `v3.10.4`.

## Added project files

```text
addons/dialogue_manager/
scripts/systems/DialogueManagerAdapter.gd
scenario/dialogue_manager/prologue.dialogue
scenario/dialogue_manager/prologue.dialogue.import
```

`project.godot` now includes:

```text
DialogueManager="*res://addons/dialogue_manager/dialogue_manager.gd"
DialogueManagerAdapter="*res://scripts/systems/DialogueManagerAdapter.gd"
```

and enables the editor plugin:

```text
enabled=PackedStringArray("res://addons/dialogue_manager/plugin.cfg")
```

## Runtime behavior

The title menu now has two start paths:

1. `Start .galscript` — existing self-built runner.
2. `Start Dialogue Manager` — Dialogue Manager sample file via `DialogueManagerAdapter`.

`DialogueManagerAdapter.gd` is the boundary layer. It calls:

```gdscript
await DialogueManager.get_next_dialogue_line(resource, title, extra_game_states)
```

and converts Dialogue Manager lines/responses into dictionaries that `VNDirector.gd` can display.

Extra game states currently exposed:

```text
VNState
PhoneSystem
CalendarSystem
RouteManager
```

This prepares the next step: Dialogue Manager `do`/`set` mutations can call into game systems without making Dialogue Manager own the game state.

## Import/bootstrap note

On a fresh checkout, run a Godot editor import once before headless runtime tests:

```bash
godot --headless --editor --path . --quit-after 10
```

This lets Godot register Dialogue Manager global classes and import `.dialogue` files. After that, runtime smoke tests can load `*.dialogue` resources normally.

## Validation

Run from project root:

```bash
godot --headless --editor --path . --quit-after 10
python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
godot --headless --path . --quit-after 120 -- --galsystem-smoke
godot --headless --path . --quit-after 120 -- --galsystem-dm-smoke
godot --headless --path . --quit-after 60 -- --galsystem-qa-invalid-save
```

Expected key output:

```text
galscript lint ok (1 files)
galscript lint self-test ok
galsystem smoke ok
dialogue manager smoke ok
qa: invalid save payload rejected
```

## Current limitations

- Dialogue Manager backend is integrated and playable as a sample path, but the main Phase-1 chapter still uses `.galscript`.
- Dialogue Manager save/load is only lightly snapshotted in `VNDirector` presentation state. Full DM conversation save/restore should be designed before migrating long chapters.
- Dialogue Manager commands/mutations are not yet mapped to all VNDirector presentation commands.
- The sample uses standard Dialogue Manager lines/responses, not a full custom DialogueLabel/balloon pipeline.

## Recommended next step

Phase 2 should migrate one short real scene from `.galscript` to `.dialogue` and define a stable adapter command contract:

1. Create a command/mutation bridge for presentation commands:
   - `bg(id)`
   - `show(character, pose, slot)`
   - `hide(slot)`
   - `phone_open()` / `phone_close()`
   - `mail_receive(...)`
   - `schedule_event(...)`
2. Decide how Dialogue Manager state checkpoints should be saved:
   - resource path,
   - current line id / next id,
   - current responses,
   - presentation snapshot,
   - VNState / PhoneSystem / CalendarSystem / FlowchartSystem snapshots.
3. Replace the sample Dialogue Manager text with a real VN scene.
4. Keep `.galscript` as a fallback until the DM path passes the same branch/save/load tests.
