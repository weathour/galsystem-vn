# Phase 1 Handoff: ADV Core Vertical Slice

## Project

- Project root: `/home/weathour/Desktop/galgame/galsystem`
- Engine: Godot 4.6.2 stable
- Phase: **Phase 1 — ADV Core Vertical Slice**
- Status: **Complete / reviewed / QA passed**

## Summary

This phase delivered a self-built Godot ADV/Galgame vertical slice suitable for exploring long-form games similar to *White Album* and *Steins;Gate*.

Phase 1 originally shipped with a self-built `.galscript` core. Phase 2 has since imported Dialogue Manager v3.10.4 as a second backend while keeping `.galscript` as the fallback path.

## What is included

### Runtime shell

- Title flow with Start / Continue / System / Debug access.
- Dialogue panel.
- Typewriter text reveal.
- Advance behavior: first click reveals current line, second click advances.
- Auto mode.
- Skip mode.
- Backlog panel.
- System menu.
- Save/load panel with six slots.
- F5 quick save and F9 quick load.
- Debug panel.
- Flow panel.

### Story systems

- `VNState.gd`: centralized story state.
- `ScenarioRunner.gd`: minimal text-first `.galscript` runner.
- `SaveSystem.gd`: save/load with payload validation and backend-aware ScenarioRunner/Dialogue Manager restore.
- `RouteManager.gd`: route/ending arbitration placeholder.
- `PhoneSystem.gd`: phone/mail trigger prototype.
- `CalendarSystem.gd`: calendar/affection event prototype.
- `FlowchartSystem.gd`: lightweight visited-label and choice-history tracker.

### Scenario tooling

- `scenario/common/prologue.galscript`: Phase-1 sample chapter.
- `scenario/command_registry.json`: shared command contract.
- `tools/lint_galscript.py`: static `.galscript` lint driven by the command registry.
- Lint detects:
  - missing labels,
  - duplicate labels,
  - malformed choice targets,
  - unknown commands,
  - invalid numeric command arguments.
- Lint self-test covers invalid synthetic scripts.

## Main files

```text
autoload/VNState.gd
autoload/ScenarioRunner.gd
autoload/SaveSystem.gd
autoload/RouteManager.gd
autoload/FlowchartSystem.gd
scripts/presentation/VNDirector.gd
scripts/systems/PhoneSystem.gd
scripts/systems/CalendarSystem.gd
scenario/common/prologue.galscript
tools/lint_galscript.py
README.md
docs/ARCHITECTURE.md
```

## Validation commands

Run from project root:

```bash
cd /home/weathour/Desktop/galgame/galsystem

python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
godot --headless --path . --quit-after 3
godot --headless --path . --quit-after 120 -- --galsystem-smoke
godot --headless --path . --quit-after 60 -- --galsystem-qa-invalid-save
```

Expected key output:

```text
galscript lint ok (1 files)
galscript lint self-test ok
smoke: title flow visible
smoke: phone branch mail->read->reply->worldline/tips/cg ok
smoke: calendar/affection branch route lock ok
galsystem smoke ok
qa: invalid save payload rejected
```

## Review and QA evidence

Autopilot artifacts were written under the parent workspace:

```text
/home/weathour/Desktop/galgame/.omx/autopilot/galsystem-phase1/
```

Important artifacts:

```text
deep-interview.md
ralplan.md
ralplan-cycle3.md
ultragoal-evidence-cycle3.md
code-review-final.md
ultraqa.md
```

Final gates:

- Code review: `APPROVE`
- Architecture status: `CLEAR`
- UltraQA: `PASS`

## Current limitations

These are accepted Phase-1 limitations, not current blockers:

1. `VNDirector.gd` is still large and code-generates most UI.
2. Command contracts are shared by convention across runner/director/lint rather than a central registry.
3. Phone UI is functional as a prototype, not a final phone interface.
4. Flow panel is debug visibility, not a full route-map editor.
5. Dialogue Manager is imported and smoke-tested; `scenario/dialogue_manager/chapter_01.dialogue` is the current DM short-chapter entry, while `.galscript` remains fallback.
6. Art/audio assets are placeholders or labels, not final production assets.

## Recommended Phase 2

1. Split `VNDirector.gd` into scene components:
   - `TitleMenu.tscn`
   - `DialogueBox.tscn`
   - `ChoiceMenu.tscn`
   - `SaveLoadUI.tscn`
   - `DebugPanel.tscn`
   - `FlowPanel.tscn`
2. Create a real `PhoneUI.tscn` with inbox/read/reply behavior.
3. Extract a shared command registry to reduce drift between runner, director, lint, and documentation.
4. Expand `FlowchartSystem` into a chapter/route map prototype.
5. Add a more complete event scheduler for calendar + affection + flags + route conditions.
6. Continue hardening Dialogue Manager save/load beyond the current mid-choice smoke.
7. Extend the command registry into runtime dispatch checks and begin splitting UI components.

## See also

See also: `docs/PHASE2_HANDOFF.md` for the current Dialogue Manager backend and command registry handoff.

## Safe continuation rule

Before starting Phase 2, rerun the validation commands above. If they fail, fix regressions before adding new systems.

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

The Dialogue Manager smoke now covers both branches plus mid-choice save/load restore.
