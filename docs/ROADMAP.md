# Roadmap

## Phase 1 — ADV core vertical slice

Completed:

- `.galscript` runner.
- VN state, save/load, backlog, auto/skip.
- Phone/mail and calendar/affection route prototypes.
- Deterministic smoke tests.

## Phase 2 — Dialogue Manager backend

Completed:

- Dialogue Manager vendored under `addons/dialogue_manager/`.
- `DialogueManagerAdapter.gd` bridges `.dialogue` lines/responses into the same presentation/runtime systems.
- Dialogue Manager branch and mid-choice save/load smoke coverage.

## Phase 3 — Narcissu compatibility study

Completed as a local/public-safe compatibility layer:

- Import/manifest tooling.
- Runtime profile and asset resolver.
- Public-safe smokes that skip when private local reference data is absent.
- No private third-party data is distributed in this repository.

## Phase 4 — Mature VN presentation layer

Completed first public slice:

- Title screen, dialogue window, quick menu, system menu, backlog, save/load components under `scripts/ui/`.
- Shared restrained VN skin through `VNTheme.gd`.
- Screenshot smoke for title/gameplay/system/backlog/save-load flows.

Remaining polish:

- Final typography and brand/art direction.
- Real save-slot thumbnails instead of text/placeholder markers.
- Optional conversion from script-built UI to `.tscn` scenes for designer iteration.

## Phase 5 — Public projectization

Current target:

- Public-facing README, license, contribution guide, roadmap, architecture, and publication checklist.
- Public-safe title menu states for missing private data.
- Fresh clone validation.
- GitHub Actions smoke workflow.

## Future directions

Potential Phase 6+ work:

1. Runtime command registry enforcement so `.galscript`, Dialogue Manager mutations, lint, docs, and execution cannot drift.
2. Real phone/mail UI and route-flow UI beyond prototype panels.
3. Save-slot screenshot thumbnails and configurable save metadata.
4. Theme/font packs and localization-friendly UI copy.
5. Export profiles for playable desktop demo builds.
6. Example authoring guide for adding a new short public chapter.
