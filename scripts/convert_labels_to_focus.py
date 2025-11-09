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
from functools import lru_cache
from pathlib import Path


# Known focus domains ordered by descending length for greedy prefix matching.
def strip_quotes(text: str) -> str:
    """Remove matching single or double quotes surrounding a string."""
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in {'"', "'"}:
        return text[1:-1]
    return text


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
    value = strip_quotes(value)
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


LABEL_RE = re.compile(r"^(\s*)label:\s*(.*?)\s*$")
BRAND_RE = re.compile(r"^(\s*)brand:\s*(.*?)\s*$")


def prepare_brand_terms(lines: list[str]) -> tuple[set[str], set[str]]:
    """Derive contiguous hyphenated terms present in brand values."""
    terms: set[str] = set()
    full_values: set[str] = set()

    for raw in lines:
        line = raw.rstrip("\n")
        if "#" in line:
            body, _ = line.split("#", 1)
            line = body.rstrip()

        match = BRAND_RE.match(line)
        if not match:
            continue

        _, value = match.groups()
        value = strip_quotes(value)
        if not value:
            continue

        full_values.add(value)
        tokens = [token for token in value.split("-") if token]
        length = len(tokens)
        if not length:
            continue

        for i in range(length):
            for j in range(i + 1, length + 1):
                term = "-".join(tokens[i:j])
                if term:
                    terms.add(term)

    return terms, full_values


def split_brand(value: str, *, source: Path, terms: set[str], full_values: set[str]) -> list[str]:
    """Split a brand string into a list while keeping meaningful hyphenated phrases."""
    value = strip_quotes(value)
    if not value:
        return []

    tokens = [token for token in value.split("-") if token]
    if not tokens:
        return []

    token_count = len(tokens)

    @lru_cache(maxsize=None)
    def dp(index: int) -> tuple[int, list[str]] | None:
        if index == token_count:
            return (0, [])

        best: tuple[int, list[str]] | None = None

        for end in range(index + 1, token_count + 1):
            term = "-".join(tokens[index:end])
            if term not in terms:
                continue

            segment_len = end - index

            if term == value and segment_len > 1:
                term_cost = segment_len
            elif term in full_values and segment_len > 1:
                term_cost = 1
            else:
                term_cost = segment_len

            remainder = dp(end)
            if remainder is None:
                continue

            total_cost = term_cost + remainder[0]
            candidate = (total_cost, [term, *remainder[1]])

            if best is None or total_cost < best[0]:
                best = candidate
            elif best is not None and total_cost == best[0]:
                if len(candidate[1]) < len(best[1]):
                    best = candidate

        return best

    result = dp(0)
    if result is None or result[1] is None:
        return tokens

    components = result[1]
    if not components:
        return tokens

    return components


def transform_lines(
    lines: list[str],
    *,
    source: Path,
    dry_run: bool,
    brand_terms: set[str],
    brand_full_values: set[str],
) -> list[str]:
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

        label_match = LABEL_RE.match(line)
        brand_match = BRAND_RE.match(line)

        if label_match:
            indent, value = label_match.groups()
            focus_items = split_focus(value, source=source)

            focus_line = f"{indent}focus:"
            if comment:
                focus_line += f" {comment}"
            focus_line += "\n"

            result.append(focus_line)
            for item in focus_items:
                result.append(f"{indent}  - {item}\n")

            changed = True
            continue

        if brand_match:
            indent, value = brand_match.groups()
            clean_value = strip_quotes(value)
            if not clean_value:
                result.append(original)
                continue

            brand_items = split_brand(
                value,
                source=source,
                terms=brand_terms,
                full_values=brand_full_values,
            )

            brand_line = f"{indent}brand:"
            if comment:
                brand_line += f" {comment}"
            brand_line += "\n"

            result.append(brand_line)
            for item in brand_items:
                result.append(f"{indent}  - {item}\n")

            changed = True
            continue

        if not label_match and not brand_match:
            result.append(original)
            continue

    if dry_run and changed:
        sys.stdout.write(f"[dry-run] Would update {source}\n")

    return result


def process_file(path: Path, *, dry_run: bool) -> None:
    """Read, transform, and optionally write the updated file."""
    original_lines = path.read_text().splitlines(keepends=True)
    brand_terms, brand_full_values = prepare_brand_terms(original_lines)
    transformed_lines = transform_lines(
        original_lines,
        source=path,
        dry_run=dry_run,
        brand_terms=brand_terms,
        brand_full_values=brand_full_values,
    )

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

