#!/usr/bin/env python3
"""Build a private Narcissu asset manifest from local game data.

The output is intended for ignored paths under reference_private/. The tool itself
contains no third-party text or assets and its self-test uses synthetic fixtures.
"""
from __future__ import annotations

import argparse
import json
import re
import tempfile
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterable

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}
BGM_EXTS = {".mp3", ".ogg", ".wav"}
SFX_EXTS = {".ogg", ".wav", ".mp3"}
FONT_EXTS = {".ttf", ".otf"}
MOVIE_EXTS = {".mpg", ".mpeg", ".avi", ".mp4", ".wmv"}
QUOTE_RE = re.compile(r'"([^"]+)"')
BG_RE = re.compile(r'^\s*bg\s+"([^"]+)"', re.I)
SPRITE_RE = re.compile(r'^\s*(?:lsp|lsph|h_usewindow)\s+[^,]*,?\s*"([^"]+)"', re.I)
MUSIC_RE = re.compile(r'^\s*(?:mp3loop|mp3)\s+"([^"]+)"', re.I)
SFX_RE = re.compile(r'^\s*dwave(?:loop)?\s+[^,]*,\s*"([^"]+)"', re.I)
GALSCRIPT_RE = re.compile(r'^\s*(bg|bgm|music|sfx|voice|narcissu_bg|narcissu_lsp|narcissu_lsph|narcissu_bgm|narcissu_sfx|narcissu_voice)\s+(.+)$', re.I)

@dataclass
class ManifestReport:
    game_root: str
    scripts: list[str]
    indexed_files: int = 0
    referenced_assets: int = 0
    resolved_assets: int = 0
    missing_assets: int = 0
    categories: dict[str, int] = field(default_factory=dict)
    missing_by_category: dict[str, int] = field(default_factory=dict)


def norm_key(value: str) -> str:
    return value.replace('\\', '/').replace('//', '/').strip().lower().lstrip('./')


def classify(path: str, command: str = "") -> str:
    ext = Path(norm_key(path)).suffix.lower()
    cmd = command.lower()
    lower = norm_key(path)
    if cmd in {"bg", "narcissu_bg", "narcissu_lsp", "narcissu_lsph"} or ext in IMAGE_EXTS:
        return "image"
    if cmd in {"bgm", "music", "narcissu_bgm"} or "bgm" in lower or cmd.startswith("mp3"):
        return "bgm"
    if cmd in {"voice", "narcissu_voice"} or "voice" in lower or "/v/" in lower or lower.startswith("v/") or lower.startswith("voice/"):
        return "voice"
    if cmd in {"sfx", "narcissu_sfx"} or "se/" in lower or lower.startswith("se/"):
        return "sfx"
    if ext in FONT_EXTS:
        return "font"
    if ext in MOVIE_EXTS:
        return "movie/unsupported"
    if ext in BGM_EXTS or ext in SFX_EXTS:
        return "sfx"
    return "unsupported"


def iter_files(root: Path) -> Iterable[Path]:
    if not root.exists():
        return []
    return (p for p in root.rglob('*') if p.is_file())


def build_index(root: Path) -> dict[str, str]:
    index: dict[str, str] = {}
    for path in iter_files(root):
        rel = path.relative_to(root).as_posix()
        key = norm_key(rel)
        index.setdefault(key, rel)
        index.setdefault(norm_key(path.name), rel)
    return index


def resolve_ref(ref: str, index: dict[str, str]) -> str:
    key = norm_key(ref.strip().strip('"'))
    if key in index:
        return index[key]
    if Path(key).suffix == "":
        for ext in sorted(IMAGE_EXTS | BGM_EXTS | SFX_EXTS | FONT_EXTS | MOVIE_EXTS):
            if key + ext in index:
                return index[key + ext]
    name = Path(key).name
    if name in index:
        return index[name]
    stem = Path(key).stem.lower()
    matches = [rel for k, rel in index.items() if Path(k).stem.lower() == stem]
    return matches[0] if matches else ""


def refs_from_nscripter(text: str) -> list[tuple[str, str]]:
    refs: list[tuple[str, str]] = []
    for line in text.splitlines():
        stripped = line.strip()
        for regex, category_command in [(BG_RE, "bg"), (SPRITE_RE, "narcissu_lsp"), (MUSIC_RE, "bgm"), (SFX_RE, "sfx")]:
            m = regex.match(stripped)
            if m:
                refs.append((m.group(1), category_command))
                break
    return refs


def refs_from_galscript(text: str) -> list[tuple[str, str]]:
    refs: list[tuple[str, str]] = []
    for line in text.splitlines():
        m = GALSCRIPT_RE.match(line)
        if not m:
            continue
        cmd = m.group(1)
        payload = m.group(2).strip()
        quoted = QUOTE_RE.findall(payload)
        if quoted:
            refs.append((quoted[0], cmd))
        else:
            parts = payload.split()
            if parts:
                # For lsp-like commands, path follows sprite id.
                candidate = parts[1] if cmd.lower() in {"narcissu_lsp", "narcissu_lsph"} and len(parts) > 1 else parts[0]
                refs.append((candidate, cmd))
    return refs


def collect_refs(scripts: list[Path]) -> list[tuple[str, str]]:
    refs: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for script in scripts:
        text = script.read_text(encoding='utf-8', errors='replace')
        candidates = refs_from_galscript(text) if script.suffix == '.galscript' else refs_from_nscripter(text)
        for ref, cmd in candidates:
            key = (norm_key(ref), cmd.lower())
            if key not in seen:
                seen.add(key)
                refs.append((ref, cmd))
    return refs


def build_manifest(game_root: Path, scripts: list[Path]) -> tuple[dict, ManifestReport]:
    index = build_index(game_root)
    refs = collect_refs(scripts)
    assets: dict[str, dict] = {}
    missing: list[dict] = []
    report = ManifestReport(game_root=str(game_root), scripts=[str(p) for p in scripts], indexed_files=len({v for v in index.values()}), referenced_assets=len(refs))
    for ref, cmd in refs:
        category = classify(ref, cmd)
        report.categories[category] = report.categories.get(category, 0) + 1
        rel = resolve_ref(ref, index)
        entry = {"reference": ref, "category": category, "command": cmd, "resolved": bool(rel)}
        if rel:
            entry["path"] = rel
            assets[norm_key(ref)] = entry
            report.resolved_assets += 1
        else:
            missing.append(entry)
            report.missing_assets += 1
            report.missing_by_category[category] = report.missing_by_category.get(category, 0) + 1
    manifest = {"version": 1, "game_root": str(game_root), "assets": assets, "missing": missing}
    return manifest, report


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding='utf-8')


def run_self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / 'game_data'
        (root / 'haeleth' / '2').mkdir(parents=True)
        (root / 'bgm2').mkdir(parents=True)
        (root / 'se').mkdir(parents=True)
        (root / 'voice').mkdir(parents=True)
        for rel in ['synthetic_bg/blue_card.png', 'synthetic_audio/loop_theme.mp3', 'synthetic_sfx/click.ogg', 'synthetic_voice/line001.ogg']:
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_bytes(b'synthetic')
        script = Path(tmp) / 'sample.utf'
        script.write_text('\n'.join([
            'bg "synthetic_bg\\blue_card.png",3',
            'mp3loop "synthetic_audio\\loop_theme.mp3"',
            'dwave 5,"synthetic_sfx\\click.ogg"',
            'dwave 0,"synthetic_voice\\line001.ogg"',
        ]), encoding='utf-8')
        manifest, report = build_manifest(root, [script])
        if report.resolved_assets != 4 or report.missing_assets != 0:
            print(json.dumps(asdict(report), indent=2))
            return 1
        cats = set(item['category'] for item in manifest['assets'].values())
        if not {'image', 'bgm', 'sfx', 'voice'}.issubset(cats):
            print('missing categories', cats)
            return 1
    print('narcissu manifest self-test ok')
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--game-root', type=Path)
    parser.add_argument('--script', action='append', type=Path, default=[])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        return run_self_test()
    if not args.game_root or not args.script or not args.output:
        parser.error('--game-root, --script, and --output are required unless --self-test is used')
    missing_scripts = [str(p) for p in args.script if not p.exists()]
    if missing_scripts:
        parser.error('script(s) missing: ' + ', '.join(missing_scripts))
    manifest, report = build_manifest(args.game_root, args.script)
    write_json(args.output, manifest)
    if args.report:
        write_json(args.report, asdict(report))
    print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
