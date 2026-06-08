# Dialogue Manager Integration

## Status

Dialogue Manager is integrated as a second dialogue backend and can now drive VN presentation/system commands through `DialogueManagerAdapter` mutations.

- Addon: Nathan Hoad Dialogue Manager
- Version: `v3.10.4`
- Source: GitHub release/tag `nathanhoad/godot_dialogue_manager@v3.10.4`
- Godot target: 4.6.x
- License: MIT, included under `addons/dialogue_manager/LICENSE`

The existing `.galscript` runner remains available as the fallback/backend for the Phase-1 vertical slice.

## Why v3.10.4 instead of Dialogue Manager 4

The upstream repository describes Dialogue Manager 4 as the Godot 4.6+ main branch but recommends using version 3 until Dialogue Manager 4 is officially released. Therefore this project uses `v3.10.4`.

## Added project files

```text
addons/dialogue_manager/
scripts/systems/DialogueManagerAdapter.gd
scenario/dialogue_manager/prologue.dialogue
scenario/dialogue_manager/prologue.dialogue.import
```

`project.godot` includes:

```text
DialogueManager="*res://addons/dialogue_manager/dialogue_manager.gd"
DialogueManagerAdapter="*res://scripts/systems/DialogueManagerAdapter.gd"
```

## Runtime behavior

The title menu has two start paths:

1. `Start .galscript` — existing self-built runner.
2. `Start Dialogue Manager` — Dialogue Manager sample through `DialogueManagerAdapter`.

`DialogueManagerAdapter.gd` calls:

```gdscript
await DialogueManager.get_next_dialogue_line(resource, title, extra_game_states)
```

and converts `DialogueLine` / `DialogueResponse` into dictionaries consumed by `VNDirector.gd`.

## Mutation bridge

`.dialogue` files can now use `do` mutations to drive the same VN shell used by `.galscript`.

Example:

```text
~ start
do bg("dm_lab_evening")
do bgm("dm_theme")
do show("okabe", "serious", "center")
系统: Dialogue Manager can now drive presentation commands.
- Test phone => phone_path

~ phone_path
do phone_open("inbox")
do mail_receive("dm_sg001", "unknown", "世界线变动率", "body")
do mail_read("dm_sg001")
do mail_reply("dm_sg001", "el_psy_congroo")
do set_worldline("1.048596")
do unlock_tip("dm_worldline_tips")
do unlock_cg("dm_phone_trigger")
系统: Phone chain complete.
=> END
```

Currently exposed bridge methods:

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

The bridge emits presentation commands into `VNDirector._on_command_requested()` and mutates central systems through `VNState`, `PhoneSystem`, `CalendarSystem`, and `RouteManager`.

## Import/bootstrap note

On a fresh checkout, run a Godot editor import once before headless runtime tests:

```bash
godot --headless --editor --path . --quit-after 10
```

This registers Dialogue Manager global classes and imports `.dialogue` files into `.tres` resources.

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

`--galsystem-dm-smoke` now verifies both Dialogue Manager branches:

- phone path: mail receive/read/reply, worldline, TIPS, CG;
- calendar path: background, affection, scheduled event, route lock;
- choice restore: save/load while the Dialogue Manager response menu is visible, then choose a branch and continue.

## Current limitations

- The main Phase-1 sample still uses `.galscript`; Dialogue Manager has a separate command-bridge sample.
- Dialogue Manager save/load now stores resource path, next id, active flag, current displayed line, current responses, and presentation state; the smoke test covers mid-choice restore. It still needs broader coverage for long-scene mid-line and branch-after-save cases.
- `VNDirector.gd` still owns command execution; Phase 2 should split UI/presentation components.
- Command bridge is code-based rather than generated from a central registry.

## Recommended next step

Proceed with **Phase 2C: migrate one real short scene to `.dialogue` and promote it toward the default start path**.

Acceptance for the next step:

1. A real scene, not just the integration sample, is written in `.dialogue`.
2. It uses presentation mutations for bg/show/hide/bgm/sfx.
3. It uses either the phone chain or calendar/affection chain, ideally both in separate branches.
4. It has save/load smoke covering Dialogue Manager mid-scene, mid-choice, and branch-after-save state.
5. `.galscript` remains as fallback until the DM scene passes equivalent validation.
