#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_FILE="${ROOT_DIR}/data/cities.yaml"
OUTPUT_FILE="${ROOT_DIR}/supabase/seeds/cities.sql"

if [[ ! -f "${DATA_FILE}" ]]; then
  echo "Missing data file: ${DATA_FILE}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to generate the seed file." >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

python3 - "${DATA_FILE}" "${OUTPUT_FILE}" <<'PY'
import sys
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Optional

try:
    import yaml  # type: ignore
except ModuleNotFoundError as exc:
    sys.stderr.write(
        "PyYAML is required to generate the cities seed.\n"
        "Install it with `pip install pyyaml` and re-run the script.\n"
    )
    raise SystemExit(1) from exc

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

if not input_path.exists():
    raise SystemExit(f"Input file not found: {input_path}")

raw_data = input_path.read_text(encoding="utf-8")
data = yaml.safe_load(raw_data)

if not isinstance(data, list):
    raise SystemExit("Expected a top-level YAML sequence of city objects.")

country_columns = [
    "slug",
    "name",
    "iso_3166_1_alpha_2",
    "iso_3166_1_alpha_3",
    "iso_3166_1_numeric",
    "capital",
    "region",
    "subregion",
    "population",
    "area_km2",
    "latitude",
    "longitude",
]

city_columns = [
    "slug",
    "city",
    "city_ascii",
    "latitude",
    "longitude",
    "admin_name",
    "capital",
    "population",
    "source_id",
    "country_slug",
]

allowed_capitals = {"primary", "admin", "minor", "none"}


def sanitize_string(value: str) -> str:
    return value.replace("'", "''")


def format_value(value, column: str) -> str:
    if value is None:
        return "NULL"

    if isinstance(value, str):
        trimmed = value.strip()
        if trimmed == "":
            return "NULL"
        return f"'{sanitize_string(trimmed)}'"

    if column in {"latitude", "longitude", "area_km2"}:
        try:
            decimal_value = Decimal(str(value))
        except InvalidOperation as exc:
            raise SystemExit(f"Invalid {column} value '{value}'") from exc
        precision = ".6f" if column != "area_km2" else ".2f"
        return format(decimal_value, precision)

    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"

    return str(value)


def resolve_country_slug(item: dict) -> Optional[str]:
    slug = item.get("country_slug")
    if slug:
        return slug
    country = item.get("country")
    if isinstance(country, dict):
        return country.get("slug")
    return None


def merge_country_record(existing: dict, new_data: dict) -> dict:
    merged = dict(existing)
    for key, value in new_data.items():
        if merged.get(key) in (None, "", []):
            merged[key] = value
    return merged


timestamp = datetime.now(tz=timezone.utc).isoformat()

countries: dict[str, dict] = {}
city_rows: dict[str, dict] = {}

for idx, item in enumerate(data):
    if not isinstance(item, dict):
        continue

    record = dict(item)
    country_slug = resolve_country_slug(record)
    if not country_slug:
        raise SystemExit(
            f"Missing country slug for city record at index {idx} with slug '{record.get('slug')}'."
        )

    country_data = record.get("country") or {}
    countries.setdefault(
        country_slug,
        {
            "slug": country_slug,
            "name": country_data.get("name"),
            "iso_3166_1_alpha_2": country_data.get("iso2"),
            "iso_3166_1_alpha_3": country_data.get("iso3"),
            "iso_3166_1_numeric": country_data.get("iso_numeric")
            if isinstance(country_data, dict)
            else None,
            "capital": country_data.get("capital")
            if isinstance(country_data, dict)
            else None,
            "region": country_data.get("region")
            if isinstance(country_data, dict)
            else None,
            "subregion": country_data.get("subregion")
            if isinstance(country_data, dict)
            else None,
            "population": country_data.get("population")
            if isinstance(country_data, dict)
            else None,
            "area_km2": country_data.get("area_km2")
            if isinstance(country_data, dict)
            else None,
            "latitude": country_data.get("latitude")
            if isinstance(country_data, dict)
            else None,
            "longitude": country_data.get("longitude")
            if isinstance(country_data, dict)
            else None,
        },
    )

    countries[country_slug] = merge_country_record(
        countries[country_slug],
        {
            "name": country_data.get("name"),
            "iso_3166_1_alpha_2": country_data.get("iso2"),
            "iso_3166_1_alpha_3": country_data.get("iso3"),
        },
    )

    record["country_slug"] = country_slug
    capital = record.get("capital")
    if capital is None or str(capital).strip() == "":
        capital = "none"
    capital = str(capital).strip().lower()
    if capital not in allowed_capitals:
        capital = "none"
    record["capital"] = capital

    missing = [
        key
        for key in ("slug", "city", "latitude", "longitude", "country_slug")
        if record.get(key) in (None, "", [])
    ]
    if missing:
        raise SystemExit(
            f"Missing required field(s) {missing} for record with slug '{record.get('slug')}'."
        )

    city_rows[record["slug"]] = record

if not countries:
    raise SystemExit("No countries could be derived from the YAML source.")

if not city_rows:
    raise SystemExit("No valid city records were found in the YAML source.")

for slug, country in countries.items():
    missing = [
        field
        for field in ("name", "iso_3166_1_alpha_2", "iso_3166_1_alpha_3")
        if country.get(field) in (None, "", [])
    ]
    if missing:
        raise SystemExit(
            f"Missing required country field(s) {missing} for country '{slug}'."
        )

with output_path.open("w", encoding="utf-8") as fh:
    fh.write("-- File generated by scripts/generate_cities_seed.sh\n")
    fh.write(f"-- Source: {input_path}\n")
    fh.write(f"-- Generated at: {timestamp}\n\n")
    fh.write("BEGIN;\n")
    fh.write("TRUNCATE TABLE public.cities RESTART IDENTITY CASCADE;\n")
    fh.write("TRUNCATE TABLE public.countries CASCADE;\n\n")

    fh.write(
        "INSERT INTO public.countries (slug, name, iso_3166_1_alpha_2, iso_3166_1_alpha_3, iso_3166_1_numeric, capital, region, subregion, population, area_km2, latitude, longitude)\n"
    )
    fh.write("VALUES\n")

    for idx, country in enumerate(sorted(countries.values(), key=lambda c: c["slug"])):
        formatted_values = ", ".join(
            format_value(country.get(column), column) for column in country_columns
        )
        prefix = "  " if idx == 0 else ", "
        fh.write(f"{prefix}({formatted_values})\n")

    fh.write(
        "ON CONFLICT (slug) DO UPDATE SET\n"
        "  name = EXCLUDED.name,\n"
        "  iso_3166_1_alpha_2 = EXCLUDED.iso_3166_1_alpha_2,\n"
        "  iso_3166_1_alpha_3 = EXCLUDED.iso_3166_1_alpha_3,\n"
        "  iso_3166_1_numeric = EXCLUDED.iso_3166_1_numeric,\n"
        "  capital = EXCLUDED.capital,\n"
        "  region = EXCLUDED.region,\n"
        "  subregion = EXCLUDED.subregion,\n"
        "  population = EXCLUDED.population,\n"
        "  area_km2 = EXCLUDED.area_km2,\n"
        "  latitude = EXCLUDED.latitude,\n"
        "  longitude = EXCLUDED.longitude,\n"
        "  updated_at = now();\n\n"
    )

    fh.write(
        "INSERT INTO public.cities (slug, city, city_ascii, latitude, longitude, admin_name, capital, population, source_id, country_slug)\n"
    )
    fh.write("VALUES\n")

    for idx, record in enumerate(sorted(city_rows.values(), key=lambda c: c["slug"])):
        formatted_values = ", ".join(
            format_value(record.get(column), column) for column in city_columns
        )
        prefix = "  " if idx == 0 else ", "
        fh.write(f"{prefix}({formatted_values})\n")

    fh.write(
        "ON CONFLICT (slug) DO UPDATE SET\n"
        "  city = EXCLUDED.city,\n"
        "  city_ascii = EXCLUDED.city_ascii,\n"
        "  latitude = EXCLUDED.latitude,\n"
        "  longitude = EXCLUDED.longitude,\n"
        "  admin_name = EXCLUDED.admin_name,\n"
        "  capital = EXCLUDED.capital,\n"
        "  population = EXCLUDED.population,\n"
        "  source_id = EXCLUDED.source_id,\n"
        "  country_slug = EXCLUDED.country_slug,\n"
        "  updated_at = now();\n\n"
    )
    fh.write("COMMIT;\n")

print(
    f"Wrote {len(countries)} countries and {len(city_rows)} cities to {output_path}"
)
PY

echo "Seed written to ${OUTPUT_FILE}"

