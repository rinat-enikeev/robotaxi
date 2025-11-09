#!/usr/bin/env python3
"""
Utility script to convert JSON data to YAML.

Usage:
    python scripts/json_to_yaml.py data/eu_factories.json data/eu_factories.yaml
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import List, Mapping, Sequence
from unicodedata import normalize

try:
    import yaml  # type: ignore
except ImportError as exc:  # pragma: no cover - defensive guard
    raise SystemExit(
        "Missing optional dependency 'PyYAML'. "
        "Install it with 'pip install pyyaml'."
    ) from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a tabular JSON file (list of rows) into structured YAML."
    )
    parser.add_argument(
        "input_path",
        type=Path,
        help="Path to the source JSON file.",
    )
    parser.add_argument(
        "output_path",
        type=Path,
        help="Path for the generated YAML file.",
    )
    parser.add_argument(
        "--cities-path",
        type=Path,
        default=Path("data/cities.yaml"),
        help="Path to the cities registry YAML file (default: data/cities.yaml).",
    )
    parser.add_argument(
        "--indent",
        type=int,
        default=2,
        help="Number of spaces used to indent nested YAML structures (default: 2).",
    )
    return parser.parse_args()


def load_json(path: Path) -> object:
    with path.open("r", encoding="utf-8") as fp:
        return json.load(fp)


def dump_yaml(data: object, path: Path, indent: int) -> None:
    with path.open("w", encoding="utf-8") as fp:
        yaml.safe_dump(
            data,
            fp,
            sort_keys=False,
            allow_unicode=True,
            indent=indent,
        )


def to_table(data: object) -> Sequence[Sequence[str]]:
    if not isinstance(data, Sequence):
        raise SystemExit("Expected JSON to be a list of rows.")

    rows: List[Sequence[str]] = []
    for row in data:  # type: ignore[assignment]
        if not isinstance(row, Sequence):
            raise SystemExit("Each JSON row must be a sequence of values.")
        rows.append(row)  # type: ignore[arg-type]
    return rows


def drop_parenthetical(text: str) -> str:
    return re.sub(r"\s*\([^)]*\)", "", text).strip()


def slugify(value: str) -> str:
    value = normalize("NFKD", value)
    value = "".join(ch for ch in value if ch.isascii())
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-{2,}", "-", value)
    return value.strip("-")


def slug_with_optional_suffix(value: str) -> str:
    value = value.strip()
    suffix = ""
    if value.endswith("*"):
        suffix = "*"
        value = value[:-1]
    base = slugify(value)
    return f"{base}{suffix}" if base else suffix


def load_city_slugs(path: Path) -> Mapping[str, Mapping[str, object]]:
    if not path.exists():
        raise SystemExit(f"Cities registry file not found: {path}")

    with path.open("r", encoding="utf-8") as fp:
        try:
            cities = yaml.safe_load(fp)
        except yaml.YAMLError as exc:
            raise SystemExit(f"Failed to parse cities registry: {exc}") from exc

    if not isinstance(cities, list):
        raise SystemExit("Expected cities registry to be a list.")

    registry = {}
    for entry in cities:
        if not isinstance(entry, dict):
            raise SystemExit("Each city entry must be a mapping.")
        slug = entry.get("slug")
        if not isinstance(slug, str):
            raise SystemExit("City entry missing string slug.")
        registry[slug] = entry
    return registry


def transform_row(
    row: Mapping[str, str],
    city_registry: Mapping[str, Mapping[str, object]],
) -> Mapping[str, object]:
    country = row.get("Country", "").strip()
    city_region = row.get("City/Region", "").strip()
    city_core = drop_parenthetical(city_region) or city_region

    slug = slugify(f"{row.get('Manufacturer', '')} {city_core} {country}")
    city = slugify(f"{city_core} {country}")
    if city not in city_registry:
        print(
            "[WARN] City slug not found in registry:"
            f" slug={city}, manufacturer={row.get('Manufacturer', '').strip()},"
            f" raw_city='{city_region}', country='{country}'",
            file=sys.stderr,
        )

    manufacturer = slugify(row.get("Manufacturer", ""))
    label = slugify(row.get("Label", ""))
    brand = slugify(row.get("Brand", ""))
    selection = slugify(row.get("Selection", ""))
    icons = slug_with_optional_suffix(row.get("Icons", ""))

    rank_raw = row.get("rank", "").strip()
    try:
        rank: object = int(rank_raw)
    except (TypeError, ValueError):
        rank = rank_raw

    return {
        "slug": slug,
        "city": city,
        "latitude": row.get("Latitude", "").strip(),
        "longitude": row.get("Longitude", "").strip(),
        "manufacturer": manufacturer,
        "label": label,
        "brand": brand,
        "address": row.get("address", "").strip(),
        "rank": rank,
        "selection": selection,
        "icons": icons,
    }


def convert(
    rows: Sequence[Sequence[str]],
    city_registry: Mapping[str, Mapping[str, object]],
) -> List[Mapping[str, object]]:
    if not rows:
        return []

    header = rows[0]
    converted: List[Mapping[str, object]] = []
    for raw_row in rows[1:]:
        mapping = dict(zip(header, raw_row))
        converted.append(transform_row(mapping, city_registry))
    return converted


def main() -> None:
    args = parse_args()

    if not args.input_path.exists():
        raise SystemExit(f"Input file not found: {args.input_path}")

    data = load_json(args.input_path)
    table = to_table(data)
    city_registry = load_city_slugs(args.cities_path)
    yaml_payload = convert(table, city_registry)
    dump_yaml(yaml_payload, args.output_path, args.indent)


if __name__ == "__main__":
    main()


