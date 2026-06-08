# Phase 4 Spark Scope

## Spark-safe work (do now)

1. Keep `scripts/presentation/VNDirector.gd` focused; only small, local edits.
2. Add and run `--galsystem-screenshot-smoke` so it writes:
	- `/tmp/galsystem-title.png`
	- `/tmp/galsystem-gameplay.png`
	- `/tmp/galsystem-system-menu.png`
	- `/tmp/galsystem-backlog.png`
	- `/tmp/galsystem-save-load.png`
	- In `--headless` dummy rendering this is a flow/file-generation smoke with fallback PNGs; use graphical/Xvfb rendering for real visual evidence.
3. Keep existing smoke modes and runtime behavior intact.
4. Update `docs/PHASE4_VISUAL_HANDOFF.md` with a concise status line that screenshot smoke is implemented.

## Explicitly defer to main/high-reasoning agent

1. Full VN UI/system-menu/backlog/save-load visual redesign.
2. Scene extraction (`scenes/ui/*`) and layout refactors.
3. Broad style system work (fonts, theme, gradients, animation systems).
4. CI-quality true screenshot capture under the chosen rendering backend.
