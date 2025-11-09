#!/usr/bin/env python3

"""
Check that every country listed in data/operations.yaml exists in data/cities.yaml.

Usage:
    python scripts/check_operations_countries.py
    python scripts/check_operations_countries.py --operations /path/to/operations.yaml --cities /path/to/cities.yaml

Requires PyYAML (`pip install pyyaml`).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Iterable, Set

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OPERATIONS_PATH = REPO_ROOT / "data" / "operations.yaml"
DEFAULT_CITIES_PATH = REPO_ROOT / "data" / "cities.yaml"


def load_yaml(path: Path) -> Iterable[dict]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)

    if not isinstance(data, list):
        raise ValueError(f"Expected a list in {path}, got {type(data).__name__}")
    return data


def collect_operation_countries(operations: Iterable[dict]) -> Set[str]:
    countries: Set[str] = set()
    for entry in operations:
        if not isinstance(entry, dict):
            continue
        entry_countries = entry.get("countries") or []
        for country in entry_countries:
            if isinstance(country, str):
                countries.add(country.strip())
    return countries


def collect_city_countries(cities: Iterable[dict]) -> Set[str]:
    countries: Set[str] = set()
    for entry in cities:
        if not isinstance(entry, dict):
            continue
        slug = entry.get("country_slug")
        if isinstance(slug, str) and slug.strip():
            countries.add(slug.strip())
            continue
        country = entry.get("country")
        if isinstance(country, dict):
            slug = country.get("slug")
            if isinstance(slug, str) and slug.strip():
                countries.add(slug.strip())
    return countries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify that operations.yaml countries are present in cities.yaml."
    )
    parser.add_argument(
        "--operations",
        type=Path,
        default=DEFAULT_OPERATIONS_PATH,
        help=f"Path to operations.yaml (default: {DEFAULT_OPERATIONS_PATH})",
    )
    parser.add_argument(
        "--cities",
        type=Path,
        default=DEFAULT_CITIES_PATH,
        help=f"Path to cities.yaml (default: {DEFAULT_CITIES_PATH})",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.operations.is_file():
        print(f"Operations file not found: {args.operations}", file=sys.stderr)
        return 2
    if not args.cities.is_file():
        print(f"Cities file not found: {args.cities}", file=sys.stderr)
        return 2

    operations_data = load_yaml(args.operations)
    cities_data = load_yaml(args.cities)

    operation_countries = collect_operation_countries(operations_data)
    city_countries = collect_city_countries(cities_data)

    missing_countries = sorted(operation_countries - city_countries)

    print(f"Countries in operations.yaml: {len(operation_countries)}")
    print(f"Countries in cities.yaml: {len(city_countries)}")

    if missing_countries:
        print("Countries missing in cities.yaml:")
        for country in missing_countries:
            print(f" - {country}")
        return 1

    print("All operations.yaml countries are present in cities.yaml.")
    return 0


if __name__ == "__main__":
    sys.exit(main())


