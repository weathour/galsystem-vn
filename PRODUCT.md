# Product

## Register

product

## Users

Players and developers working with a Godot visual-novel / ADV framework. Players need a readable, familiar VN interface for long sessions. Developers need a presentation layer that can keep `.galscript`, Dialogue Manager, Narcissu import, save/load, backlog, auto, and skip behavior stable while the UI becomes production-facing.

## Product Purpose

`galsystem` is a Godot 4.6 ADV/Galgame foundation for long-form stories in the tradition of *White Album*, *Steins;Gate*, and Narcissu-style kinetic/branching visual novels. Phase 4 exists to turn a proven engineering vertical slice into a mature VN presentation layer that can be shown, tested, and extended without looking like a debug harness.

## Brand Personality

Quiet, cinematic, reliable. The interface should feel like a serious VN runtime: restrained enough not to compete with story art, polished enough to earn trust, and explicit enough that save/load/backlog/system actions are always discoverable.

## Anti-references

- Debug panels presented as player UI.
- Flat placeholder boxes with no VN skin detail.
- Tiny status text dominating the play screen.
- SaaS-like cards, decorative gradients, glassmorphism, or web-dashboard styling.
- Overly animated menus that delay reading or basic player actions.

## Design Principles

1. Story first: background, character art, and dialogue readability outrank decoration.
2. Familiar VN affordances: use established Ren'Py/Dialogic-style patterns for text windows, quick menu, backlog, and save/load.
3. Keep runtime behavior stable: visual upgrades must preserve all existing smoke-tested story paths.
4. Player-facing by default: debug and flow tools stay available but should not define the main screen.
5. Screenshot-verifiable: every Phase 4 UI milestone should leave reproducible visual evidence.

## Accessibility & Inclusion

Target readable contrast for all dialogue and menu text, large enough type for 1280x720 play, keyboard and mouse parity for core actions, and reduced/no decorative motion unless it communicates state. Preserve existing keyboard shortcuts while making common actions visible through the quick menu.
