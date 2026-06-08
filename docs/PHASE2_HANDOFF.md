# Phase 2 Handoff: Dialogue Manager Backend and Command Contract

## Project

- Project root: `/home/weathour/Desktop/galgame/galsystem`
- Engine: Godot 4.6.2 stable
- Current phase: **Phase 2 — Dialogue Manager backend + command contract hardening**
- Status: **Current slice complete / committed / smoke-tested**

## Summary

Phase 1 delivered a self-built `.galscript` ADV vertical slice. Phase 2 has now connected Nathan Hoad's Dialogue Manager v3.10.4 as a second backend while keeping `.galscript` as the fallback path.

The current project can start either:

1. `Start .galscript` — Phase-1 self-built runner sample.
2. `Start Dialogue Manager` — `scenario/dialogue_manager/chapter_01.dialogue`, a short Dialogue Manager chapter using the same VN shell.

Dialogue Manager is no longer just installed; it can drive presentation and story-system commands through `DialogueManagerAdapter` mutation methods, can be saved/restored at a visible choice menu, and is covered by headless smoke tests.

## Completed in this phase

### Dialogue Manager integration

- Installed Dialogue Manager v3.10.4 under `addons/dialogue_manager/`.
- Registered autoloads in `project.godot`:
  - `DialogueManager`
  - `DialogueManagerAdapter`
- Added import artifacts for `.dialogue` files.
- Kept `.galscript` as a fallback backend.

### Mutation bridge

`DialogueManagerAdapter.gd` exposes mutation methods for `.dialogue` scripts, including:

```text
bg(id)
bgm(id = "stop")
music(id = "stop")
sfx(id = "none")
show(character_id, pose = "neutral", slot = "center")
hide(slot = "center")
clear_chars()
phone_open(screen = "inbox")
phone_close()
mail_receive(mail_id, sender, subject, body = "")
mail_read(mail_id)
mail_reply(mail_id, keyword)
schedule_event(event_id, day, affection_character = "", affection_min = 0, required_flag = "")
advance_day(delta = 1)
add_affection(character_id, delta)
set_flag(key, value = true)
set_var(key, value)
lock_route(route_id)
set_worldline(value)
unlock_tip(tip_id)
unlock_cg(cg_id)
```

These either emit presentation commands into `VNDirector._on_command_requested()` or mutate central systems such as `VNState`, `PhoneSystem`, `CalendarSystem`, and `RouteManager`.

### Dialogue Manager chapter entry

New current DM entry:

```text
scenario/dialogue_manager/chapter_01.dialogue
```

It includes:

- short common scene setup;
- Steins;Gate-like phone/mail/worldline branch;
- White Album-like calendar/affection/route branch;
- state mutations through Dialogue Manager `do` commands.

The older sample remains available:

```text
scenario/dialogue_manager/prologue.dialogue
```

### Backend-aware save/load

`SaveSystem.gd` now stores `scenario_backend` and restores the proper backend:

- `.galscript` restores through `ScenarioRunner.restore_checkpoint()`;
- Dialogue Manager restores through `DialogueManagerAdapter.restore()` and saved presentation state.

Dialogue Manager snapshots currently include:

- `resource_path`;
- `next_id`;
- `active`;
- `current_display`;
- `current_responses`.

The smoke test verifies save/load while the Dialogue Manager choice menu is visible, then continues the chosen branch.

### Shared command registry

New file:

```text
scenario/command_registry.json
```

It records the shared command contract for `.galscript` and Dialogue Manager mappings:

- command names;
- minimum argument counts;
- integer argument positions;
- label target argument positions;
- Dialogue Manager mutation mappings.

`tools/lint_galscript.py` now reads this registry instead of hardcoding command rules. Its self-test also checks that registry-declared Dialogue Manager mutation names exist on `DialogueManagerAdapter.gd`.

## Important files

```text
addons/dialogue_manager/
autoload/SaveSystem.gd
autoload/ScenarioRunner.gd
autoload/VNState.gd
project.godot
scenario/command_registry.json
scenario/common/prologue.galscript
scenario/dialogue_manager/chapter_01.dialogue
scenario/dialogue_manager/prologue.dialogue
scripts/presentation/VNDirector.gd
scripts/systems/DialogueManagerAdapter.gd
tools/lint_galscript.py
docs/DIALOGUE_MANAGER_INTEGRATION.md
docs/ARCHITECTURE.md
docs/PHASE1_HANDOFF.md
```

## Fresh checkout bootstrap

On a fresh checkout, run a Godot editor import once before headless Dialogue Manager runtime tests:

```bash
cd /home/weathour/Desktop/galgame/galsystem
godot --headless --editor --path . --quit-after 10
```

This registers Dialogue Manager global classes and imports `.dialogue` resources into `.godot/imported/`.

## Validation commands

Run from project root:

```bash
cd /home/weathour/Desktop/galgame/galsystem

python3 -m json.tool scenario/command_registry.json
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

Known expected warning:

- `--galsystem-dm-smoke` exits successfully but currently prints Dialogue Manager resource cleanup warnings at process exit.
- `--galsystem-qa-invalid-save` intentionally prints a save payload error before confirming rejection.

## Commit history for this phase

```text
c628870 Add scenario command registry
0d57933 Add Dialogue Manager chapter entry
9963b78 Support Dialogue Manager save restore
42dda2e Add Dialogue Manager command bridge
54c5ebb Integrate Dialogue Manager backend
fd2ad40 Complete Phase 1 ADV vertical slice
```

## Current limitations

1. `VNDirector.gd` is still a large shell and owns UI construction plus command execution.
2. `scenario/command_registry.json` is used by lint and DM mutation checking, but runtime command dispatch is not yet generated/validated from it.
3. Dialogue Manager save/load covers mid-choice restore, but not yet every long-scene save/load position.
4. Phone UI is still a prototype overlay rather than a full inbox/read/reply interface.
5. Calendar/event UI is represented by state and smoke tests, not a real schedule interface.
6. Art/audio are placeholder labels and hashed colors.

## Recommended next step

Proceed with **Phase 2D: command execution split and UI boundary cleanup**.

Acceptance for the next slice:

1. Extract command execution out of `VNDirector.gd` into a dedicated system, e.g. `ScenarioCommandExecutor.gd`.
2. Make both `.galscript` and Dialogue Manager commands go through that executor.
3. Check executor-supported commands against `scenario/command_registry.json`.
4. Keep all current validation commands passing.
5. Optionally begin splitting `DialogueBox` or `ChoiceMenu` into separate scenes/scripts after command execution is isolated.

## Safe continuation rule

Before changing the next phase, rerun the validation commands above. If any fail, fix regressions before adding new features.
