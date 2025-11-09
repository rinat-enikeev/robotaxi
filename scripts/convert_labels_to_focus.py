#!/usr/bin/env python3
"""
Convert `label` scalar fields into `focus` lists in YAML datasets.

Example transformation:

    label: passenger-cars-light-commercial-vehicles-engines-electric-motors-batteries

becomes:

    focus:
      - passenger-cars
      - light-commercial-vehicles
      - engines
      - electric-motors
      - batteries

Usage:
    ./scripts/convert_labels_to_focus.py data/factories.yaml

The script updates files in place. Use `--dry-run` to preview changes.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


# Known focus domains ordered by descending length for greedy prefix matching.
KNOWN_FOCI = [
    "light-commercial-vehicles",
    "heavy-duty-vehicles",
    "electric-motors",
    "passenger-cars",
    "engines",
    "batteries",
    "buses",
]


def split_focus(value: str, *, source: Path) -> list[str]:
    """Split a label string into focus domains."""
    value = value.strip()
    if not value:
        return []

    remaining = value
    items: list[str] = []

    while remaining:
        for focus in KNOWN_FOCI:
            if remaining.startswith(focus):
                items.append(focus)
                remaining = remaining[len(focus) :]
                if remaining.startswith("-"):
                    remaining = remaining[1:]
                break
        else:
            raise ValueError(
                f"Unable to parse label '{value}' in {source}. "
                f"Remaining segment: '{remaining}'"
            )

    return items


LINE_RE = re.compile(r"^(\s*)label:\s*(.*?)\s*$")


def transform_lines(lines: list[str], *, source: Path, dry_run: bool) -> list[str]:
    """Transform lines, returning a new list with label → focus updates."""
    result: list[str] = []
    changed = False

    for original in lines:
        line = original.rstrip("\n")
        comment = ""

        if "#" in line:
            body, comment_part = line.split("#", 1)
            comment = "#" + comment_part.rstrip()
            line = body.rstrip()

        match = LINE_RE.match(line)
        if not match:
            result.append(original)
            continue

        indent, value = match.groups()
        focus_items = split_focus(value, source=source)

        focus_line = f"{indent}focus:"
        if comment:
            focus_line += f" {comment}"
        focus_line += "\n"

        result.append(focus_line)
        for item in focus_items:
            result.append(f"{indent}  - {item}\n")

        changed = True

    if dry_run and changed:
        sys.stdout.write(f"[dry-run] Would update {source}\n")

    return result


def process_file(path: Path, *, dry_run: bool) -> None:
    """Read, transform, and optionally write the updated file."""
    original_lines = path.read_text().splitlines(keepends=True)
    transformed_lines = transform_lines(original_lines, source=path, dry_run=dry_run)

    if dry_run:
        return

    if transformed_lines != original_lines:
        path.write_text("".join(transformed_lines))
        print(f"Updated {path}")
    else:
        print(f"No changes for {path}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Convert label scalars into focus lists.")
    parser.add_argument(
        "paths",
        metavar="PATH",
        nargs="+",
        type=Path,
        help="One or more YAML files to update in place.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show which files would change without writing updates.",
    )

    args = parser.parse_args(argv)

    for path in args.paths:
        if not path.exists():
            print(f"Skipping missing file: {path}", file=sys.stderr)
            continue
        process_file(path, dry_run=args.dry_run)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

