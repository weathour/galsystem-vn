# galsystem

Godot 4.6 ADV/Galgame skeleton for long-form games similar to *White Album* and *Steins;Gate*.

## Current status

Phase 1 targets an **ADV Core Vertical Slice**: a small but verifiable self-built system slice, not a final commercial VN engine.

Current status:

- Self-built `.galscript` runner.
- Title/start flow.
- Dialogue UI with typewriter, advance, auto, skip, backlog.
- System menu, save/load slots, quick save/load.
- Debug panel and flow panel.
- Centralized story state.
- Phone/mail prototype for Steins;Gate-like triggers.
- Calendar/affection prototype for White Album-like route conditions.
- Static `.galscript` lint driven by `scenario/command_registry.json`.
- Headless smoke test with deterministic branch and save/load assertions.
- Dialogue Manager `.dialogue` backend with `scenario/dialogue_manager/chapter_01.dialogue` as the current DM short-chapter entry and a mutation bridge for bg/show/bgm/sfx, phone/mail, calendar/affection, route, worldline, TIPS, and CG commands.
- Dialogue Manager mid-choice save/load regression.

Dialogue Manager v3.10.4 is now imported as a second backend. The self-built `ScenarioRunner.gd` remains available as the fallback path while `.dialogue` scenes are promoted into the main workflow.

## Run

Open this folder with Godot 4.6.2+ or run:

```bash
godot --path .
```

## Controls

- Left click / Space: advance text; if typewriter is active, reveal current line first.
- Esc: system menu.
- F1: debug panel.
- F2: flow panel.
- F5: quick save slot 1.
- F9: quick load slot 1.
- B: backlog.
- A: auto mode.
- S: skip mode.

## Validation

Static scenario lint:

```bash
python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
```

Expected output:

```text
galscript lint ok (1 files)
galscript lint self-test ok
```

Godot startup smoke:

```bash
godot --headless --path . --quit-after 3
```

Full Phase-1 vertical-slice smoke:

```bash
godot --headless --path . --quit-after 120 -- --galsystem-smoke
```

Expected output includes:

```text
smoke: title flow visible
smoke: phone branch mail->read->reply->worldline/tips/cg ok
smoke: calendar/affection branch route lock ok
galsystem smoke ok
```

The full smoke test asserts:

- title flow is visible before starting;
- save/load restores the current line, choice state, day, and worldline before branch selection;
- phone branch performs mail received -> read -> reply -> worldline/TIPS/CG -> branch observed;
- calendar branch performs day advance -> affection threshold -> scheduled event -> route lock;
- flow tracking records visited labels and choices.

## Script commands

Example file: `scenario/common/prologue.galscript`.

```text
label start
chapter prologue
day 1
worldline 1.000000
bg winter_street
bgm winter_theme
show kazusa neutral center
say 冬马|你迟到了。
narr|十二月的风从校门口穿过。
schedule_event music_rehearsal 2 kazusa 3 visited_music_room
mail sg001 unknown 世界线变动率 正文内容
choice 接电话->phone_call|去音乐室->music_room
read_mail sg001
reply_mail sg001 el_psy_congroo
set_flag answered_phone true
set_var phone_keyword el_psy_congroo
affection kazusa +1
advance_day 1
if_flag answered_phone sg_note white_album_note
if_var phone_keyword el_psy_congroo true_label false_label
if_affection kazusa 3 affection_ready affection_low
if_calendar_event music_rehearsal event_ready event_miss
cg first_phone_trigger
tip worldline_tips
clear_chars
jump ending
end
```

## Key architecture

- `autoload/VNState.gd`: story flags, variables, affection, route, day, worldline, backlog, CG/TIPS.
- `autoload/ScenarioRunner.gd`: minimal text runner and checkpointing.
- `autoload/SaveSystem.gd`: JSON save/load for state, runner, presentation, phone, calendar, flowchart.
- `autoload/FlowchartSystem.gd`: lightweight visited-label/choice tracker.
- `scripts/systems/PhoneSystem.gd`: phone/mail prototype state.
- `scripts/systems/CalendarSystem.gd`: day/event/affection scheduler state.
- `scripts/presentation/VNDirector.gd`: presentation shell and command dispatch.
- `scenario/command_registry.json`: shared command contract used by lint and checked against Dialogue Manager mutations.

## Phase 2 follow-ups

- Use `scenario/command_registry.json` as the command-contract source of truth and extend it into docs/runtime checks.
- Split `VNDirector.gd` into scene components (`TitleMenu`, `DialogueBox`, `ChoiceMenu`, `SaveLoadUI`, `DebugPanel`, `FlowPanel`).
- Keep extending `scenario/command_registry.json` so `.galscript`, Dialogue Manager, lint, docs, and smoke tests cannot drift.
- Expand phone UI and calendar/event UI beyond the current prototype panels.

## Dialogue Manager integration update

Dialogue Manager v3.10.4 is now installed under `addons/dialogue_manager/` and available as a second backend through `DialogueManagerAdapter.gd`. Its mutation bridge can now drive VN presentation/system commands from `.dialogue` files. See `docs/DIALOGUE_MANAGER_INTEGRATION.md`.

Additional validation:

```bash
godot --headless --editor --path . --quit-after 10
godot --headless --path . --quit-after 120 -- --galsystem-dm-smoke
```

Expected key output:

```text
dialogue manager smoke ok
```
