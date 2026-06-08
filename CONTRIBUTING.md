# Contributing

Thanks for considering a contribution to `galsystem-vn`.

## Project scope

This project is a Godot ADV / visual-novel runtime skeleton. Contributions should preserve the public-demo-safe boundary:

- Do not commit copyrighted third-party VN assets, scripts, audio, CG, screenshots, or extracted private corpora.
- Do not commit `reference_private/` or `external_reference/` content.
- Keep public demos self-contained under `scenario/`, `assets/`, `scripts/`, and `scenes/`.

## Before opening a PR

Run the smallest relevant checks, and prefer the full public smoke suite before larger changes:

```bash
python3 tools/import_nscripter_case.py --self-test
python3 tools/build_narcissu_manifest.py --self-test
python3 tools/lint_galscript.py scenario
python3 tools/lint_galscript.py --self-test
godot --headless --path . --quit-after 3
godot --headless --path . --quit-after 120 -- --galsystem-smoke
godot --headless --path . --quit-after 120 -- --galsystem-dm-smoke
godot --headless --path . --quit-after 120 -- --galsystem-qa-invalid-save
godot --headless --path . --quit-after 120 -- --galsystem-public-title-smoke
```

For presentation/UI changes, also run:

```bash
godot --headless --path . --quit-after 120 -- --galsystem-screenshot-smoke
```

In a graphical environment, inspect the generated `/tmp/galsystem-*.png` screenshots manually.

## Code style

- Keep runtime behavior smoke-testable.
- Prefer small, reversible UI components over large inline builders.
- Preserve keyboard and mouse parity for player actions.
- Keep `scenario/command_registry.json` aligned with parser/runtime/documentation changes.
- Add docs when changing public behavior, setup, or validation commands.

## Commit hygiene

- Keep private/local data out of Git.
- Explain user-visible behavior changes in commit messages.
- Avoid unrelated formatting churn in vendored addons.
