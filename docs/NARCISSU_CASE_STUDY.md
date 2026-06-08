# Narcissu 1/2 private case-study import

This repository supports using the legally obtained Narcissu 1/2 scripts as a **private local case study** for galsystem. The generated story text is third-party material and is intentionally kept under `reference_private/`, which is ignored by Git.

## Legal/source boundary

- Narcissu 1/2 are free visual novels, but free download does not automatically mean the text should be committed into this project or redistributed as modified `.galscript`.
- Keep downloaded archives, extracted `0.utf`, and generated `.galscript` files in `reference_private/`.
- Commit only import tooling, docs, stats, and system support. Do not commit complete third-party scenario text unless a later license review confirms that modified redistribution is allowed.

## Local import commands used

From the project root:

```bash
mkdir -p reference_private/narcissu/downloads reference_private/narcissu/extracted reference_private/narcissu/generated
curl -L --fail --retry 3 -A 'Mozilla/5.0' \
  -o reference_private/narcissu/downloads/Narcissu_2_Eng_v1.1_script_All_platforms.zip \
  'https://www.neechin.net/file_download/27/Narcissu_2_Eng_v1.1_script_%5BAll_platforms%5D.zip'
unzip -o reference_private/narcissu/downloads/Narcissu_2_Eng_v1.1_script_All_platforms.zip \
  -d reference_private/narcissu/extracted/script_v1_1
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

Current local conversion stats:

| Case | Output lines | Text lines | Labels | Background commands | Music commands | SFX commands |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Narcissu 1 gp32 path | 3,895 | 2,883 | 9 | 407 | 33 | 549 |
| Narcissu Side 2nd Haeleth path | 26,624 | 16,192 | 498 | 2,891 | 211 | 6,633 |

## Runtime entry

`VNDirector` now has title-menu entries:

- `Start Narcissu 1 private`
- `Start Narcissu 2 private`

They load:

- `res://reference_private/narcissu/generated/narcissu1_gp32.galscript`
- `res://reference_private/narcissu/generated/narcissu2_haeleth.galscript`

If those files are absent, the runtime reports a status message and does not fail the public project.

## Verification

```bash
python3 tools/import_nscripter_case.py --self-test
python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
godot --headless --path . --quit-after 120 -- --galsystem-narcissu-private-smoke
```

The private smoke test skips cleanly if private files are missing; with the current local import present, it verifies both private converted scripts can start and present text through `ScenarioRunner`.
