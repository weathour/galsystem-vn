# Publication Checklist

Use this checklist before every public push, release tag, demo build, or archive.

## Private data boundary

Must remain untracked:

```text
reference_private/
external_reference/
.omx/
.godot/
```

Check before publishing:

```bash
git status --short
git ls-files | grep -Ei 'reference_private|external_reference|game_data|downloads|\.zip$|secret|token|credential|\.env' || true
find reference_private external_reference -maxdepth 3 -type f 2>/dev/null | head
```

Expected result: no tracked private reference files. Local private files may exist on disk, but they must not appear in `git ls-files`.

## Public clone readiness

From a clean clone:

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

Private Narcissu smokes should skip cleanly when local data is absent.

## Title-screen expectations

In a fresh public clone:

- `Start Demo` is enabled.
- `Start Dialogue Manager Demo` is enabled.
- `Narcissu 1 Private` is disabled with a "not installed" label.
- `Narcissu 2 Private` is disabled with a "not installed" label.
- `Continue Slot 1` is disabled until a save exists.

## Documentation expectations

Update these files when public-facing behavior changes:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `PRODUCT.md` when product/design direction changes

## Visual evidence

For UI changes, run screenshot smoke and inspect real rendered screenshots in a graphical session:

```bash
godot --path . --quit-after 120 -- --galsystem-screenshot-smoke
```

Expected files:

```text
/tmp/galsystem-title.png
/tmp/galsystem-gameplay.png
/tmp/galsystem-system-menu.png
/tmp/galsystem-backlog.png
/tmp/galsystem-save-load.png
```
