#!/usr/bin/env python3
"""Convert a legally obtained NScripter/PONScripter script into galsystem .galscript.

This tool is intentionally source-agnostic and does not contain third-party text.
Use it against a locally downloaded, authorized game script and write outputs to an
ignored directory such as reference_private/.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

LABEL_RE = re.compile(r"^\*([A-Za-z0-9_][A-Za-z0-9_\-]*)")
BG_RE = re.compile(r'^bg\s+"([^"]+)"')
MUSIC_RE = re.compile(r'^(?:mp3loop|mp3)\s+"([^"]+)"')
SFX_RE = re.compile(r'^dwave(?:loop)?\s+(?:\d+,)?\s*"([^"]+)"')
GOTO_RE = re.compile(r'^(?:goto|gosub)\s+\*([A-Za-z0-9_][A-Za-z0-9_\-]*)')
CSEL_TARGET_RE = re.compile(r'\^?([^,]+?)\s*,\s*\*([A-Za-z0-9_][A-Za-z0-9_\-]*)')
STYLE_RE = re.compile(r"~[^\s~]{1,24}~")
INLINE_CMD_RE = re.compile(r"![A-Za-z0-9_][^\s\\@]*")

@dataclass
class ImportStats:
    input: str
    output: str
    source_lines: int = 0
    output_lines: int = 0
    labels: int = 0
    text_lines: int = 0
    backgrounds: int = 0
    music: int = 0
    sfx: int = 0
    jumps: int = 0
    choices: int = 0
    truncated: bool = False


def asset_id(path: str) -> str:
    stem = Path(path.replace("\\", "/")).stem
    cleaned = re.sub(r"[^A-Za-z0-9_\-]+", "_", stem).strip("_")
    return cleaned or "asset"


def clean_text(raw: str) -> str:
    text = raw.strip()
    if text.startswith("^"):
        text = text[1:]
    text = text.replace("\\", " ").replace("^@^", " ").replace("^", " ").replace("@", " ")
    text = STYLE_RE.sub("", text)
    text = INLINE_CMD_RE.sub("", text)
    text = text.replace("``,", "\"").replace("''", "\"")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def is_text_line(line: str) -> bool:
    return line.startswith("^")


def parse_choice(start_line: str, following: list[str]) -> tuple[str | None, int]:
    # NScripter csel can span several physical lines. Consume until no trailing comma.
    block = [start_line]
    consumed = 0
    for candidate in following:
        if not block[-1].rstrip().endswith(","):
            break
        block.append(candidate.strip())
        consumed += 1
    joined = " ".join(block)
    joined = joined.replace("csel", "", 1).strip()
    choices: list[str] = []
    for text, label in CSEL_TARGET_RE.findall(joined):
        cleaned = clean_text(text).strip(' "')
        if cleaned:
            choices.append(f"{cleaned}->{label}")
    if not choices:
        return None, consumed
    return "choice " + "|".join(choices), consumed


def convert_text(text: str, output: Path, *, start_label: str | None = None, max_text_lines: int = 0, title: str = "") -> ImportStats:
    lines = text.splitlines()
    out: list[str] = []
    stats = ImportStats(input="<memory>", output=str(output), source_lines=len(lines))
    if title:
        out.append(f"# {title}")
    out.append("# Generated from a locally obtained NScripter/PONScripter script.")
    out.append("# Do not commit generated third-party story text unless its license allows it.")
    out.append("")

    active = start_label is None
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        i += 1
        if not line or line.startswith(";"):
            continue
        label_match = LABEL_RE.match(line)
        if label_match:
            label = label_match.group(1)
            if start_label and label == start_label:
                active = True
            if not active:
                continue
            out.append(f"label {label}")
            stats.labels += 1
            continue
        if not active:
            continue
        if max_text_lines and stats.text_lines >= max_text_lines:
            stats.truncated = True
            break
        bg_match = BG_RE.match(line)
        if bg_match:
            out.append(f"bg {asset_id(bg_match.group(1))}")
            stats.backgrounds += 1
            continue
        music_match = MUSIC_RE.match(line)
        if music_match:
            out.append(f"bgm {asset_id(music_match.group(1))}")
            stats.music += 1
            continue
        sfx_match = SFX_RE.match(line)
        if sfx_match:
            out.append(f"sfx {asset_id(sfx_match.group(1))}")
            stats.sfx += 1
            continue
        goto_match = GOTO_RE.match(line)
        if goto_match:
            out.append(f"jump {goto_match.group(1)}")
            stats.jumps += 1
            continue
        if line.startswith("csel"):
            choice_line, consumed = parse_choice(line, lines[i:])
            i += consumed
            if choice_line:
                out.append(choice_line)
                stats.choices += 1
            continue
        if is_text_line(line):
            cleaned = clean_text(line)
            if cleaned:
                out.append(f"narr|{cleaned}")
                stats.text_lines += 1
            continue

    if not out or not any(line.startswith("label ") for line in out):
        out.append("label start")
    out.append("end")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(out) + "\n", encoding="utf-8")
    stats.output_lines = len(out)
    return stats


def run_self_test() -> int:
    sample = """
*start
bg "e\\b.jpg",5
mp3loop "bgm2\\2sou01.mp3"
^~i~A first line.\\
dwave 5,"se\\ele2.ogg"
csel ^Go left^,*left,
     ^Go right^,*right
*left
^Left branch.\\
goto *end_label
*right
^Right branch.\\
*end_label
"""
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "sample.galscript"
        stats = convert_text(sample, out, title="self test")
        generated = out.read_text(encoding="utf-8")
        expected = ["label start", "bg b", "bgm 2sou01", "narr|A first line.", "sfx ele2", "choice Go left->left|Go right->right", "label left", "narr|Left branch.", "jump end_label", "label right", "narr|Right branch.", "label end_label", "end"]
        missing = [line for line in expected if line not in generated]
        if missing:
            print("import_nscripter_case self-test failed:")
            print(generated)
            print("missing", missing)
            return 1
        if stats.text_lines != 3 or stats.choices != 1:
            print("import_nscripter_case self-test failed stats", stats)
            return 1
    print("import_nscripter_case self-test ok")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", nargs="?", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--encoding", default="utf-8")
    parser.add_argument("--start-label")
    parser.add_argument("--max-text-lines", type=int, default=0)
    parser.add_argument("--title", default="")
    parser.add_argument("--stats-json", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return run_self_test()
    if args.input is None or args.output is None:
        parser.error("input and output are required unless --self-test is used")
    source = args.input.read_text(encoding=args.encoding, errors="replace")
    stats = convert_text(source, args.output, start_label=args.start_label, max_text_lines=args.max_text_lines, title=args.title)
    stats.input = str(args.input)
    print(json.dumps(asdict(stats), ensure_ascii=False, indent=2))
    if args.stats_json:
        args.stats_json.parent.mkdir(parents=True, exist_ok=True)
        args.stats_json.write_text(json.dumps(asdict(stats), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
