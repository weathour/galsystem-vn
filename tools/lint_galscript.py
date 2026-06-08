#!/usr/bin/env python3
"""Static lint for galsystem .galscript files."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import tempfile
import sys

KNOWN_COMMANDS = {
    "label", "jump", "choice", "if_flag", "if_var", "if_affection", "if_calendar_event",
    "say", "narr", "set_flag", "set_var", "affection", "route", "chapter", "day", "worldline",
    "show", "hide", "bg", "mail", "read_mail", "reply_mail", "schedule_event", "advance_day",
    "phone", "clear_chars", "bgm", "music", "sfx", "cg", "tip", "end",
}
TARGET_COMMANDS = {"jump": [0], "if_flag": [1, 2], "if_var": [2, 3], "if_affection": [2, 3], "if_calendar_event": [1, 2]}
MIN_ARGS = {
    "label": 1, "jump": 1, "choice": 1, "if_flag": 3, "if_var": 4, "if_affection": 4,
    "if_calendar_event": 3, "say": 1, "narr": 1, "set_flag": 1, "set_var": 2,
    "affection": 2, "route": 1, "chapter": 1, "day": 1, "worldline": 1, "show": 1,
    "hide": 1, "bg": 1, "mail": 3, "read_mail": 1, "reply_mail": 2, "schedule_event": 2,
    "advance_day": 0, "phone": 0, "clear_chars": 0, "bgm": 0, "music": 0, "sfx": 0,
    "cg": 1, "tip": 1, "end": 0,
}
INT_ARGS = {
    "day": [0],
    "advance_day": [0],
    "affection": [1],
    "if_affection": [1],
    "schedule_event": [1, 3],
}

@dataclass
class ParsedLine:
    file: Path
    line_no: int
    op: str
    args: list[str]
    raw: str


def parse_line(path: Path, line_no: int, raw: str) -> ParsedLine | None:
    stripped = raw.strip()
    if not stripped or stripped.startswith("#"):
        return None
    if stripped.startswith("say "):
        return ParsedLine(path, line_no, "say", [stripped[4:]], raw.rstrip("\n"))
    if stripped.startswith("narr|"):
        return ParsedLine(path, line_no, "narr", [stripped[5:]], raw.rstrip("\n"))
    if stripped.startswith("choice "):
        return ParsedLine(path, line_no, "choice", [stripped[7:]], raw.rstrip("\n"))
    parts = stripped.split()
    return ParsedLine(path, line_no, parts[0], parts[1:], raw.rstrip("\n"))


def iter_scripts(paths: list[Path]) -> list[Path]:
    result: list[Path] = []
    for path in paths:
        if path.is_dir():
            result.extend(sorted(path.rglob("*.galscript")))
        elif path.suffix == ".galscript":
            result.append(path)
    return sorted(set(result))


def choice_targets(payload: str) -> list[str]:
    targets: list[str] = []
    for item in payload.split("|"):
        if "->" in item:
            _, target = item.split("->", 1)
            targets.append(target.strip())
    return targets


def is_int(value: str) -> bool:
    try:
        int(value)
        return True
    except ValueError:
        return False


def lint_file(path: Path) -> list[str]:
    errors: list[str] = []
    lines: list[ParsedLine] = []
    labels: dict[str, int] = {}
    for idx, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        parsed = parse_line(path, idx, raw)
        if parsed is None:
            continue
        lines.append(parsed)
        if parsed.op == "label":
            if not parsed.args:
                errors.append(f"{path}:{idx}: label requires a name")
            else:
                label = parsed.args[0]
                if label in labels:
                    errors.append(f"{path}:{idx}: duplicate label '{label}' first declared at line {labels[label]}")
                labels[label] = idx

    for line in lines:
        if line.op not in KNOWN_COMMANDS:
            errors.append(f"{line.file}:{line.line_no}: unknown command '{line.op}'")
            continue
        expected = MIN_ARGS[line.op]
        if len(line.args) < expected:
            errors.append(f"{line.file}:{line.line_no}: command '{line.op}' expects at least {expected} args, got {len(line.args)}")
            continue
        for arg_idx in INT_ARGS.get(line.op, []):
            if len(line.args) > arg_idx and not is_int(line.args[arg_idx]):
                errors.append(f"{line.file}:{line.line_no}: command '{line.op}' argument {arg_idx + 1} must be an integer, got '{line.args[arg_idx]}'")
        if line.op == "choice":
            targets = choice_targets(line.args[0] if line.args else "")
            if not targets:
                errors.append(f"{line.file}:{line.line_no}: choice requires at least one text->label target")
            for target in targets:
                if target not in labels:
                    errors.append(f"{line.file}:{line.line_no}: choice target '{target}' is missing")
        elif line.op in TARGET_COMMANDS:
            for arg_idx in TARGET_COMMANDS[line.op]:
                if len(line.args) > arg_idx and line.args[arg_idx] not in labels:
                    errors.append(f"{line.file}:{line.line_no}: {line.op} target '{line.args[arg_idx]}' is missing")
    return errors


def run_self_test() -> int:
    cases = {
        "unknown": "label start\ntypo_command foo\nend\n",
        "bad_numeric": "label start\naffection kazusa nope\nend\n",
        "missing_target": "label start\nchoice A->missing\nend\n",
        "valid": "label start\nday 1\naffection kazusa +1\nchoice A->end_label\nlabel end_label\nend\n",
    }
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        failures = []
        for name, content in cases.items():
            path = root / f"{name}.galscript"
            path.write_text(content, encoding="utf-8")
            errors = lint_file(path)
            if name == "valid" and errors:
                failures.append(f"valid case failed: {errors}")
            elif name != "valid" and not errors:
                failures.append(f"invalid case {name} unexpectedly passed")
        if failures:
            print("galscript lint self-test failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1
    print("galscript lint self-test ok")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", type=Path, default=[Path("scenario")])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return run_self_test()
    scripts = iter_scripts(args.paths)
    if not scripts:
        print("galscript lint: no scripts found", file=sys.stderr)
        return 1
    errors: list[str] = []
    for script in scripts:
        errors.extend(lint_file(script))
    if errors:
        print("galscript lint failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"galscript lint ok ({len(scripts)} files)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
