#!/usr/bin/env python3
"""
Find the closest matches in `cities.yaml` for missing city slugs reported in
`data/missing.txt`, using the latitude/longitude values stored in
`data/eu_factories.yaml`.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Mapping, MutableMapping, Optional, Sequence, Tuple

try:
    import yaml  # type: ignore
except ImportError as exc:  # pragma: no cover - defensive guard
    raise SystemExit(
        "Missing optional dependency 'PyYAML'. Install it with 'pip install pyyaml'."
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MISSING_PATH = ROOT / "data" / "missing.txt"
DEFAULT_FACTORIES_PATH = ROOT / "data" / "eu_factories.yaml"
DEFAULT_CITIES_PATH = ROOT / "data" / "cities.yaml"


@dataclass(frozen=True)
class MissingEntry:
    slug: str
    manufacturer: str
    raw_city: str
    country: str


@dataclass(frozen=True)
class FactoryLocation:
    latitude: float
    longitude: float


@dataclass(frozen=True)
class CityEntry:
    slug: str
    city: str
    country_slug: str
    latitude: float
    longitude: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Suggest closest matching city entries for the missing slugs listed in "
            "`data/missing.txt`."
        )
    )
    parser.add_argument(
        "--missing-path",
        type=Path,
        default=DEFAULT_MISSING_PATH,
        help="Path to the missing-city report (default: data/missing.txt).",
    )
    parser.add_argument(
        "--factories-path",
        type=Path,
        default=DEFAULT_FACTORIES_PATH,
        help="Path to the factories YAML file with coordinates (default: data/eu_factories.yaml).",
    )
    parser.add_argument(
        "--cities-path",
        type=Path,
        default=DEFAULT_CITIES_PATH,
        help="Path to the cities registry YAML file (default: data/cities.yaml).",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=3,
        help="Number of closest matches to show for each missing slug (default: 3).",
    )
    parser.add_argument(
        "--country-filter",
        action="store_true",
        help="Restrict candidate matches to cities sharing the same country slug.",
    )
    return parser.parse_args()


def parse_missing(path: Path) -> List[MissingEntry]:
    if not path.exists():
        raise SystemExit(f"Missing report not found: {path}")

    entries: List[MissingEntry] = []
    seen: set[str] = set()

    with path.open("r", encoding="utf-8") as fp:
        for raw_line in fp:
            line = raw_line.strip()
            if "slug=" not in line:
                continue
            try:
                _, remainder = line.split("slug=", 1)
                slug, remainder = remainder.split(", manufacturer=", 1)
                manufacturer, remainder = remainder.split(", raw_city=", 1)
                raw_city, remainder = remainder.split(", country=", 1)
            except ValueError:
                print(f"[WARN] Unable to parse line: {raw_line.rstrip()}", file=sys.stderr)
                continue

            slug = slug.strip()
            manufacturer = manufacturer.strip()
            raw_city = raw_city.strip()
            country = remainder.strip()

            # Drop surrounding quotes (keeps inner apostrophes intact)
            if raw_city.startswith("'") and raw_city.endswith("'"):
                raw_city = raw_city[1:-1]
            if country.startswith("'") and country.endswith("'"):
                country = country[1:-1]

            if slug not in seen:
                seen.add(slug)
                entries.append(MissingEntry(slug, manufacturer, raw_city, country))

    return entries


def to_float(value: object) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    # Factories file stores decimals using commas.
    text = text.replace(",", ".")
    try:
        return float(text)
    except ValueError:
        return None


def load_factories(path: Path) -> Mapping[str, FactoryLocation]:
    if not path.exists():
        raise SystemExit(f"Factories file not found: {path}")

    with path.open("r", encoding="utf-8") as fp:
        try:
            data = yaml.safe_load(fp)
        except yaml.YAMLError as exc:
            raise SystemExit(f"Failed to parse factories YAML: {exc}") from exc

    if not isinstance(data, list):
        raise SystemExit("Expected factories YAML to be a list.")

    coordinates: Dict[str, Tuple[float, float]] = {}
    duplicates: MutableMapping[str, List[Tuple[float, float]]] = defaultdict(list)

    for entry in data:
        if not isinstance(entry, dict):
            continue
        city_slug = entry.get("city")
        if not isinstance(city_slug, str):
            continue
        lat = to_float(entry.get("latitude"))
        lon = to_float(entry.get("longitude"))
        if lat is None or lon is None:
            continue
        duplicates[city_slug].append((lat, lon))

    for slug, coords in duplicates.items():
        if not coords:
            continue
        avg_lat = sum(lat for lat, _ in coords) / len(coords)
        avg_lon = sum(lon for _, lon in coords) / len(coords)
        coordinates[slug] = (avg_lat, avg_lon)

    return {slug: FactoryLocation(lat, lon) for slug, (lat, lon) in coordinates.items()}


def load_cities(path: Path) -> List[CityEntry]:
    if not path.exists():
        raise SystemExit(f"Cities registry not found: {path}")

    # Manual parsing keeps memory usage reasonable even for large files.
    entries: List[CityEntry] = []
    current_slug: Optional[str] = None
    current_city: Optional[str] = None
    current_country: Optional[str] = None
    current_lat: Optional[float] = None
    current_lon: Optional[float] = None

    def flush() -> None:
        nonlocal current_slug, current_city, current_country, current_lat, current_lon
        if (
            current_slug
            and current_city
            and current_country
            and current_lat is not None
            and current_lon is not None
        ):
            entries.append(
                CityEntry(
                    slug=current_slug,
                    city=current_city,
                    country_slug=current_country,
                    latitude=current_lat,
                    longitude=current_lon,
                )
            )
        current_slug = None
        current_city = None
        current_country = None
        current_lat = None
        current_lon = None

    with path.open("r", encoding="utf-8") as fp:
        for raw_line in fp:
            line = raw_line.rstrip("\n")
            stripped = line.strip()
            if stripped.startswith("- slug:"):
                flush()
                current_slug = stripped.split(":", 1)[1].strip()
                continue

            if current_slug is None:
                continue

            if stripped.startswith("city:"):
                current_city = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("latitude:"):
                current_lat = to_float(stripped.split(":", 1)[1])
            elif stripped.startswith("longitude:"):
                current_lon = to_float(stripped.split(":", 1)[1])
            elif stripped.startswith("country_slug:"):
                current_country = stripped.split(":", 1)[1].strip()

        flush()

    return entries


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Radius of the Earth in kilometers.
    radius = 6371.0

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)

    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius * c


def find_matches(
    missing: Sequence[MissingEntry],
    factories: Mapping[str, FactoryLocation],
    cities: Sequence[CityEntry],
    top: int,
    restrict_country: bool,
) -> Mapping[str, List[Tuple[CityEntry, float]]]:
    results: Dict[str, List[Tuple[CityEntry, float]]] = {}

    cities_by_country: MutableMapping[str, List[CityEntry]] = defaultdict(list)
    if restrict_country:
        for entry in cities:
            cities_by_country[entry.country_slug].append(entry)

    for item in missing:
        factory_coords = factories.get(item.slug)
        if not factory_coords:
            continue

        candidates: Iterable[CityEntry]
        if restrict_country:
            # The cities registry uses lowercase hyphenated country slugs.
            country_slug = re.sub(r"[^a-z0-9]+", "-", item.country.lower()).strip("-")
            candidates = cities_by_country.get(country_slug, [])
        else:
            candidates = cities

        scored: List[Tuple[CityEntry, float]] = []
        for entry in candidates:
            distance = haversine(
                factory_coords.latitude,
                factory_coords.longitude,
                entry.latitude,
                entry.longitude,
            )
            scored.append((entry, distance))

        scored.sort(key=lambda item_: item_[1])
        results[item.slug] = scored[:top]

    return results


def format_result(item: MissingEntry, matches: Sequence[Tuple[CityEntry, float]]) -> str:
    header = (
        f"{item.slug} "
        f"(raw_city='{item.raw_city}', country='{item.country}', manufacturer='{item.manufacturer}')"
    )

    if not matches:
        return header + "\n  No candidate matches found."

    lines = [header]
    for rank, (entry, distance) in enumerate(matches, start=1):
        lines.append(
            f"  {rank}. {entry.slug} ({entry.city}, {entry.country_slug}) — {distance:.1f} km"
        )
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    missing_entries = parse_missing(args.missing_path)
    factories = load_factories(args.factories_path)
    cities = load_cities(args.cities_path)

    matches = find_matches(
        missing_entries,
        factories,
        cities,
        top=max(1, args.top),
        restrict_country=args.country_filter,
    )

    for item in missing_entries:
        suggestion_block = format_result(item, matches.get(item.slug, []))
        print(suggestion_block)
        print()


if __name__ == "__main__":
    main()


