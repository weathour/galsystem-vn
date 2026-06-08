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
import shlex
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

LABEL_RE = re.compile(r"^\*([A-Za-z0-9_][A-Za-z0-9_\-]*)")
BG_RE = re.compile(r'^bg\s+"([^"]+)"(?:\s*,\s*([^\s]+))?')
LSP_RE = re.compile(r'^(lsp|lsph)\s+([^,\s]+)\s*,\s*"([^"]+)"\s*,\s*([^,\s]+)\s*,\s*([^,\s]+)')
VSP_RE = re.compile(r'^vsp\s+(.+)')
CSP_RE = re.compile(r'^csp\s+(.+)')
MUSIC_RE = re.compile(r'^(mp3loop|mp3)\s+"([^"]+)"')
MP3_FADE_RE = re.compile(r'^mp3fadeout\s*(\d+)?')
SFX_RE = re.compile(r'^(dwave|dwaveloop)\s+(?:([^,]+),)?\s*"([^"]+)"')
DWAVE_STOP_RE = re.compile(r'^dwavestop\s*([^\s,]+)?')
GOTO_RE = re.compile(r'^(goto|gosub)\s+\*([A-Za-z0-9_][A-Za-z0-9_\-]*)')
IF_RE = re.compile(r'^if\s+(.+?)\s+(goto|gosub)?\s*\*?([A-Za-z0-9_][A-Za-z0-9_\-]*)\s*$')
MOV_RE = re.compile(r'^(mov|add|sub|mul)\s+([%$]?[A-Za-z0-9_]+)\s*,\s*(.+)$')
TABLEGOTO_RE = re.compile(r'^(tablegoto1?|tablegoto)\s+([^,]+),\s*(.+)$')
WAIT_RE = re.compile(r'^wait\s+(\d+)')
INLINE_WAIT_RE = re.compile(r'^!w(\d+)')
H_USEWINDOW_RE = re.compile(r'^h_usewindow\s+"([^"]+)"')
CSEL_TARGET_RE = re.compile(r'\^?([^,]+?)\s*,\s*\*([A-Za-z0-9_][A-Za-z0-9_\-]*)')
STYLE_RE = re.compile(r"~[^\s~]{1,24}~")
INLINE_CMD_RE = re.compile(r"![A-Za-z0-9_][^\s\\@]*")

NOOP_PREFIXES = (
    "!s", "!sd", "br", "br2", "click", "textspeed", "gettextspeed", "btn", "btndef",
    "btnwait", "exbtn", "exbtn_d", "spbtn", "cell", "cellcheckspbtn", "bar", "monocro",
    "h_locate", "h_centreline", "h_textheight", "h_mapfont", "h_defwindow", "intlimit",
    "numalias", "movz", "itoa", "checkpage", "texthide", "textshow", "isfull", "jumpb",
    "getcursorpos", "effect", "_dwave", "+", "~",
)

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
    sprites: int = 0
    waits: int = 0
    jumps: int = 0
    calls: int = 0
    returns: int = 0
    choices: int = 0
    variables: int = 0
    conditionals: int = 0
    ignored_commands: int = 0
    truncated: bool = False


def quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


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


def split_inline_commands(line: str) -> list[str]:
    if line.startswith("^"):
        return [line]
    parts: list[str] = []
    current: list[str] = []
    in_quote = False
    for char in line:
        if char == '"':
            in_quote = not in_quote
        if char == ':' and not in_quote:
            part = ''.join(current).strip()
            if part:
                parts.append(part)
            current = []
        else:
            current.append(char)
    tail = ''.join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def normalize_var(token: str) -> str:
    token = token.strip()
    if token.startswith(("%", "$")):
        token = token[1:]
    return re.sub(r"[^A-Za-z0-9_]+", "_", token).strip("_") or "var"


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("*"):
        value = value[1:]
    if value.startswith('"') and value.endswith('"'):
        return quote(value.strip('"'))
    if value.startswith("%"):
        return "%" + normalize_var(value)
    if value.startswith("$"):
        return "$" + normalize_var(value)
    return quote(value) if re.search(r"\s", value) else value


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


def labels_from_table(rest: str) -> list[str]:
    return [item.strip().lstrip('*') for item in rest.split(',') if item.strip().startswith('*')]


def convert_command(line: str, stats: ImportStats) -> list[str]:
    out: list[str] = []
    bg_match = BG_RE.match(line)
    if bg_match:
        out.append(f"narcissu_bg {quote(bg_match.group(1))} {bg_match.group(2) or ''}".rstrip())
        stats.backgrounds += 1
        return out
    lsp_match = LSP_RE.match(line)
    if lsp_match:
        cmd, sprite_id, path, x, y = lsp_match.groups()
        out.append(f"narcissu_{cmd.lower()} {sprite_id} {quote(path)} {x} {y}")
        stats.sprites += 1
        return out
    vsp_match = VSP_RE.match(line)
    if vsp_match:
        out.append("narcissu_vsp " + vsp_match.group(1).replace(',', ' '))
        stats.sprites += 1
        return out
    csp_match = CSP_RE.match(line)
    if csp_match:
        out.append("narcissu_csp " + csp_match.group(1).replace(',', ' '))
        stats.sprites += 1
        return out
    music_match = MUSIC_RE.match(line)
    if music_match:
        out.append(f"narcissu_bgm {quote(music_match.group(2))} {'loop' if music_match.group(1) == 'mp3loop' else 'once'}")
        stats.music += 1
        return out
    fade_match = MP3_FADE_RE.match(line)
    if fade_match:
        out.append("narcissu_bgm_fadeout " + (fade_match.group(1) or "0"))
        stats.music += 1
        return out
    if line == "stop" or line.startswith("stop "):
        out.append("narcissu_bgm_stop")
        stats.music += 1
        return out
    sfx_match = SFX_RE.match(line)
    if sfx_match:
        cmd, channel, path = sfx_match.groups()
        channel = (channel or "0").strip()
        category = "voice" if channel == "0" or "voice" in path.lower().replace('\\', '/') else "sfx"
        op = "narcissu_voice" if category == "voice" else "narcissu_sfx"
        out.append(f"{op} {channel} {quote(path)} {'loop' if cmd == 'dwaveloop' else 'once'}")
        stats.sfx += 1
        return out
    dwavestop_match = DWAVE_STOP_RE.match(line)
    if dwavestop_match:
        out.append("narcissu_sfx_stop " + (dwavestop_match.group(1) or "all"))
        stats.sfx += 1
        return out
    goto_match = GOTO_RE.match(line)
    if goto_match:
        if goto_match.group(1) == "gosub":
            out.append(f"call {goto_match.group(2)}")
            stats.calls += 1
        else:
            out.append(f"jump {goto_match.group(2)}")
            stats.jumps += 1
        return out
    if line == "return":
        out.append("return")
        stats.returns += 1
        return out
    if_match = IF_RE.match(line)
    if if_match:
        expr, kind, label = if_match.groups()
        out.append(f"if_expr {quote(expr.strip())} {kind or 'goto'} {label}")
        stats.conditionals += 1
        return out
    mov_match = MOV_RE.match(line)
    if mov_match:
        op, var_name, value = mov_match.groups()
        table = {"mov": "set_value", "add": "add_value", "sub": "sub_value", "mul": "mul_value"}
        out.append(f"{table[op]} {normalize_var(var_name)} {normalize_value(value)}")
        stats.variables += 1
        return out
    table_match = TABLEGOTO_RE.match(line)
    if table_match:
        _, var_name, rest = table_match.groups()
        labels = labels_from_table(rest)
        if labels:
            out.append("tablegoto %s %s" % (normalize_var(var_name), " ".join(labels)))
            stats.jumps += 1
        return out
    wait_match = WAIT_RE.match(line) or INLINE_WAIT_RE.match(line)
    if wait_match:
        out.append("wait " + wait_match.group(1))
        stats.waits += 1
        return out
    h_match = H_USEWINDOW_RE.match(line)
    if h_match:
        out.append(f"narcissu_window {quote(h_match.group(1))}")
        return out
    if line.startswith("erasetextwindow"):
        out.append("narcissu_erasetextwindow " + " ".join(line.split()[1:]))
        return out
    if line.startswith("print"):
        out.append("narcissu_print " + " ".join(line.split()[1:]))
        return out
    if line.startswith(NOOP_PREFIXES):
        out.append("narcissu_noop " + quote(line.split()[0]))
        stats.ignored_commands += 1
        return out
    return out


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
        i += 1
        for line in split_inline_commands(raw.strip()):
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
            converted = convert_command(line, stats)
            out.extend(converted)
        if stats.truncated:
            break

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
bg "synthetic_bg\\blue_card.png",5
mp3loop "synthetic_audio\\loop_theme.mp3"
mp3 "synthetic_audio\\one_shot.mp3"
mp3fadeout 1500
^~i~A first line.\\
dwave 5,"synthetic_sfx\\click.ogg"
dwaveloop 0,"synthetic_voice\\line001.ogg"
dwavestop 5
lsp 200,"synthetic_fg\\sprite.png",0,0
lsph 201,"synthetic_fg\\hidden.png",10,20
vsp 200,1
csp 200
print 3
wait 500
!w1500
mov %11,1
add %11,2
sub %11,1
mul %11,8
if %11>=1 goto *left
gosub *sub_label
tablegoto1 %11, *start, *left, *right
csel ^Go left^,*left,
     ^Go right^,*right
*sub_label
^Sub branch.\\
return
*left
h_usewindow "synthetic_ui\\frame.png"
erasetextwindow 0
^Left branch.\\
goto *end_label
*right
^Right branch.\\
*end_label
stop
"""
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "sample.galscript"
        stats = convert_text(sample, out, title="self test")
        generated = out.read_text(encoding="utf-8")
        expected = [
            'label start', 'narcissu_bg "synthetic_bg\\\\blue_card.png" 5', 'narcissu_bgm "synthetic_audio\\\\loop_theme.mp3" loop',
            'narcissu_bgm "synthetic_audio\\\\one_shot.mp3" once', 'narcissu_bgm_fadeout 1500', 'narr|A first line.',
            'narcissu_sfx 5 "synthetic_sfx\\\\click.ogg" once', 'narcissu_voice 0 "synthetic_voice\\\\line001.ogg" loop',
            'narcissu_sfx_stop 5', 'narcissu_lsp 200 "synthetic_fg\\\\sprite.png" 0 0', 'narcissu_lsph 201 "synthetic_fg\\\\hidden.png" 10 20',
            'narcissu_vsp 200 1', 'narcissu_csp 200', 'narcissu_print 3', 'wait 500', 'wait 1500',
            'set_value 11 1', 'add_value 11 2', 'sub_value 11 1', 'mul_value 11 8',
            'if_expr "%11>=1" goto left', 'call sub_label', 'tablegoto 11 start left right',
            'choice Go left->left|Go right->right', 'label sub_label', 'return', 'narcissu_window "synthetic_ui\\\\frame.png"',
            'narcissu_erasetextwindow 0', 'jump end_label', 'narcissu_bgm_stop', 'end']
        missing = [line for line in expected if line not in generated]
        if missing:
            print("import_nscripter_case self-test failed:")
            print(generated)
            print("missing", missing)
            return 1
        if stats.text_lines != 4 or stats.choices != 1 or stats.backgrounds != 1 or stats.music < 4 or stats.sfx < 3 or stats.sprites < 4 or stats.conditionals != 1 or stats.variables != 4:
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
