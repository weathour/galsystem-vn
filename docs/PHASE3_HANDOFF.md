# Phase 3 Handoff: Local Narcissu 1/2 Godot Runtime MVP

## Project context

- Project root: `/home/weathour/Desktop/galgame/galsystem`
- Engine: Godot 4.6.2 stable
- Phase 3 status: **implementation complete / committed / validation passing**
- Current target: local Narcissu 1 gp32 and Narcissu Side 2nd Haeleth private case-study runtime in Godot.

## Privacy boundary

Third-party story text and assets remain private and ignored by Git:

```text
reference_private/narcissu/
external_reference/
```

Do not commit:

- full Narcissu `.galscript` outputs;
- downloaded archives;
- extracted `0.utf`;
- original images/audio/fonts;
- generated manifests/reports that expose complete private asset inventories.

Committed artifacts are limited to tooling, runtime code, docs, and synthetic self-tests/smokes.

## What Phase 3 added

### Manifest tooling

New tool:

```bash
python3 tools/build_narcissu_manifest.py --self-test
```

Private manifest command:

```bash
python3 tools/build_narcissu_manifest.py \
  --game-root reference_private/narcissu/game_data \
  --script reference_private/narcissu/extracted/script_v1_1/0.utf \
  --output reference_private/narcissu/generated/asset_manifest.json \
  --report reference_private/narcissu/generated/asset_manifest_report.json
```

The manifest builder normalizes NScripter paths, categorizes image/BGM/SFX/voice/font/movie/unsupported references, resolves against ignored local data, and reports missing assets. The generated manifest/report remain ignored.

### Converter command subset

`tools/import_nscripter_case.py` now preserves a wider Narcissu-compatible subset in generated private `.galscript`:

```text
^ text lines
bg
lsp / lsph
vsp
csp
print
wait / !w
mp3loop / mp3 / mp3fadeout / stop
dwave / dwaveloop / dwavestop
goto / gosub / return
csel
tablegoto / tablegoto1
if
mov / add / sub / mul
h_usewindow
erasetextwindow
common harmless UI/button/text-speed commands as narcissu_noop
```

The self-test fixture is synthetic and covers the widened subset without third-party text.

Private conversion commands remain:

```bash
python3 tools/import_nscripter_case.py \
  reference_private/narcissu/extracted/script_v1_1/0.utf \
  reference_private/narcissu/generated/narcissu1_gp32.galscript \
  --start-label gp32_image \
  --title 'Narcissu 1 private converted case (gp32 path)' \
  --stats-json reference_private/narcissu/generated/narcissu1_gp32.stats.json

python3 tools/import_nscripter_case.py \
  reference_private/narcissu/extracted/script_v1_1/0.utf \
  reference_private/narcissu/generated/narcissu2_haeleth.galscript \
  --start-label haeleth_nar2 \
  --title 'Narcissu Side 2nd private converted case (Haeleth path)' \
  --stats-json reference_private/narcissu/generated/narcissu2_haeleth.stats.json
```

Current local private conversion stats after Phase 3 converter widening:

| Case | Output lines | Text lines | Labels | Background commands | Music commands | SFX/voice commands |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Narcissu 1 gp32 path | 4,967 | 2,883 | 9 | 407 | 107 | 1,376 |
| Narcissu Side 2nd Haeleth path | 40,586 | 16,192 | 498 | 2,891 | 685 | 13,588 |

### Runtime systems

New dedicated systems:

```text
scripts/systems/NarcissuRuntimeProfile.gd
scripts/systems/NarcissuAssetResolver.gd
scripts/systems/NarcissuCommandExecutor.gd
```

Responsibilities:

- `NarcissuRuntimeProfile.gd`: 800x600 source layout, private paths, audio bus defaults.
- `NarcissuAssetResolver.gd`: manifest/direct private filesystem resolution, case/path normalization, absolute-path fallback for ignored assets, texture/audio loading.
- `NarcissuCommandExecutor.gd`: Narcissu media/window command dispatch and runtime diagnostics.

`VNDirector.gd` remains the presentation shell. It now has:

- real `TextureRect` background layer;
- Narcissu sprite overlay stage;
- BGM player;
- SFX pool;
- voice player;
- title entries for private Narcissu 1/2;
- `--galsystem-narcissu-local-smoke`.

### Scenario compatibility VM

`ScenarioRunner.gd` now stores/restores:

- numeric variables;
- string variables;
- call stack;
- compatibility checkpoint metadata.

It supports converted flow/state commands: `call`, `return`, `if_expr`, `tablegoto`, `set_value`, `add_value`, `sub_value`, `mul_value`, and `wait` as a safe emitted/no-crash command.

This preserves save/load and quick-save/load compatibility for Narcissu scripts while keeping existing `.galscript` and Dialogue Manager behavior intact.

## Local data status

The repo has no committed Narcissu media and no committed generated manifest. During this Phase 3 run, full real private game media was not present under:

```text
reference_private/narcissu/game_data/
```

Therefore `--galsystem-narcissu-local-smoke` correctly skips on a fresh/private-data-missing checkout.

To validate the actual image/audio loader path without committing third-party assets, ignored synthetic private fixtures were temporarily placed under `reference_private/narcissu/game_data/` and an ignored manifest was generated. With those ignored fixtures, `--galsystem-narcissu-local-smoke` passed through real Godot texture/audio loading. Replace those fixtures with legally obtained real Narcissu game data for actual playback.

## Smoke behavior

```bash
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-private-smoke
```

- Skips if private generated scripts are absent.
- With private scripts present, verifies both Narcissu private scripts start and present text.

```bash
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-local-smoke
```

- Skips if private generated scripts or private media/manifest are absent.
- With private media/manifest present, verifies for both Narcissu 1 and Narcissu 2:
  - script starts;
  - non-empty text is presented;
  - backlog is populated;
  - at least one background texture loads;
  - at least one BGM stream loads;
  - at least one SFX or voice stream loads;
  - quick save/load restores the script path and compatibility-state containers;
  - backlog, auto, and skip toggles remain functional.

## Fresh checkout bootstrap

On a tracked/public checkout without `.godot/`, run a Godot editor import once before Dialogue Manager runtime validation:

```bash
godot --headless --editor --path . --quit-after 10
```

The `.galscript` and Narcissu skip/runtime smokes are safe without private data. Dialogue Manager resources depend on Godot's generated global-class/import cache, so the editor-import step is part of the validation contract for fresh checkouts.

## Validation evidence

Full documented validation was run from project root after implementation:

```bash
python3 -m json.tool scenario/command_registry.json
python3 tools/import_nscripter_case.py --self-test
python3 tools/build_narcissu_manifest.py --self-test
python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
godot --headless --editor --path . --quit-after 10   # required once on fresh checkout before DM runtime smoke
godot --headless --path . --quit-after 120 -- --galsystem-smoke
godot --headless --path . --quit-after 120 -- --galsystem-dm-smoke
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-private-smoke
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-local-smoke
godot --headless --path . --quit-after 60 -- --galsystem-qa-invalid-save
```

Observed results:

```text
import_nscripter_case self-test ok
narcissu manifest self-test ok
galscript lint ok (1 files)
galscript lint self-test ok
galsystem smoke ok
dialogue manager smoke ok
narcissu private import smoke ok
narcissu local smoke ok                    # with ignored synthetic private media fixtures
qa: invalid save payload rejected
```

Known expected warnings remain:

- `--galsystem-dm-smoke` prints Dialogue Manager/Godot cleanup warnings while exiting 0.
- `--galsystem-qa-invalid-save` intentionally prints a save payload error before confirming rejection.

## Commits in this phase

```text
8612b35 Add Narcissu manifest tooling
9ccf6c6 Add Narcissu runtime media support
```

The final docs update is committed after this handoff is written.

## What works

- Title menu has Narcissu 1/2 private entries.
- Private converted scripts start and present text.
- Converter emits a wider observed Narcissu command subset.
- Runtime resolves private assets from manifest/direct ignored data.
- Runtime loads real image/audio files via absolute private paths, avoiding dependence on Godot importing ignored assets.
- Background/BGM/SFX/voice code paths are covered by local smoke when private media exists.
- Save/load/backlog/auto/skip/quick-save/load are preserved and covered in local smoke.
- Fresh public checkout remains safe: private smokes skip cleanly when ignored data is missing.

## Phase 4 visual direction

The next direction is now documented in:

```text
docs/PHASE4_VISUAL_HANDOFF.md
```

Do not keep polishing the current debug/prototype UI directly. Phase 4 should retain the Godot runtime and Narcissu systems, but replace the presentation layer with a mature Ren'Py/Dialogic-style VN visual layer.

## Partial / next recommended phase

Phase 3 is a Narcissu local-runtime MVP, not a full NScripter emulator. Remaining recommended Phase 4 work:

1. Add a richer sprite/layer compositor for all `lsp`/`lsph` positioning and transitions.
2. Add timed wait/fade behavior instead of best-effort no-crash command handling.
3. Expand expression parsing beyond the current simple variable comparison and `&&`/`||` cases.
4. Add a small private-data setup guide for users to place their legally obtained Narcissu media under `reference_private/narcissu/game_data/`.
5. If a license review permits, add a public minimal media fixture package generated by the project, not from Narcissu assets.
