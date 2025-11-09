#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_FILE="${ROOT_DIR}/data/factories.yaml"
OUTPUT_FILE="${ROOT_DIR}/supabase/seeds/factories.sql"

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
from typing import Any, Optional

try:
    import yaml  # type: ignore
except ModuleNotFoundError as exc:
    sys.stderr.write(
        "PyYAML is required to generate the factories seed.\n"
        "Install it with `pip install pyyaml` and re-run the script.\n"
    )
    raise SystemExit(1) from exc

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

if not input_path.exists():
    raise SystemExit(f"Input file not found: {input_path}")

raw_data = input_path.read_text(encoding="utf-8")
data: Any = yaml.safe_load(raw_data)

if not isinstance(data, list):
    raise SystemExit("Expected a top-level YAML sequence of factory records.")

# Minimal required fields. Other fields are optional and default to NULL.
required_fields = (
    "slug",
    "city",
    "manufacturer",
    "latitude",
    "longitude",
)

columns = [
    "slug",
    "city_slug",
    "manufacturer",
    "focus",
    "brand",
    "address",
    "rank",
    "selection",
    "latitude",
    "longitude",
]


def sanitize_string(value: str) -> str:
    return value.replace("'", "''")


def clean_optional_string(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
def clean_optional_list(value: Any) -> Optional[list[str]]:
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        cleaned = [str(item).strip() for item in value if str(item).strip()]
        return cleaned or None
    if isinstance(value, str):
        text = value.strip()
        return [text] if text else None
    raise SystemExit(f"Unsupported type {type(value)!r} for list field: {value!r}")




def ensure_required_string(
    entry: dict[str, Any], field: str, idx: int
) -> str:
    raw = entry.get(field)
    if raw is None:
        raise SystemExit(
            f"Missing required field '{field}' for record at index {idx}."
        )
    text = str(raw).strip()
    if text == "":
        raise SystemExit(
            f"Field '{field}' cannot be blank for record at index {idx}."
        )
    return text


def normalize_decimal(value: Any, column: str) -> Decimal:
    if isinstance(value, Decimal):
        return value
    if isinstance(value, (int, float)):
        return Decimal(str(value))
    if isinstance(value, str):
        normalized = value.strip().replace(",", ".")
        if not normalized:
            raise SystemExit(f"Empty {column} value encountered.")
        try:
            return Decimal(normalized)
        except InvalidOperation as exc:
            raise SystemExit(f"Invalid {column} value '{value}'") from exc
    raise SystemExit(f"Unsupported type {type(value)!r} for {column}: {value!r}")


def format_decimal(value: Any, column: str) -> str:
    decimal_value = normalize_decimal(value, column)
    return format(decimal_value, ".6f")


def format_text_array(value: Any, column: str) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (list, tuple)):
        cleaned = [str(item).strip() for item in value if str(item).strip()]
        if not cleaned:
            return "ARRAY[]::text[]"
        elements = ", ".join(f"'{sanitize_string(element)}'" for element in cleaned)
        return f"ARRAY[{elements}]"
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return "NULL"
        return f"ARRAY['{sanitize_string(text)}']"
    raise SystemExit(f"Unsupported type {type(value)!r} for array field '{column}': {value!r}")


def format_rank(value: Any) -> str:
    if value is None:
        return "NULL"
    text_value = str(value).strip()
    if text_value == "":
        return "NULL"
    if isinstance(value, bool):
        raise SystemExit("Rank must be numeric, not boolean.")
    if isinstance(value, (int, str, float, Decimal)):
        try:
            integer = int(text_value)
        except ValueError as exc:
            raise SystemExit(f"Rank must be an integer. Got '{value}'.") from exc
        if integer < 0:
            raise SystemExit(f"Rank cannot be negative. Got '{value}'.")
        return str(integer)
    raise SystemExit(f"Unsupported rank type {type(value)!r}: {value!r}")


def format_value(column: str, value: Any) -> str:
    if column in {"latitude", "longitude"}:
        return format_decimal(value, column)
    if column == "rank":
        return format_rank(value)
    if column in {"focus", "brand"}:
        return format_text_array(value, column)
    if value is None:
        return "NULL"
    if isinstance(value, str):
        trimmed = value.strip()
        if trimmed == "":
            return "NULL"
        return f"'{sanitize_string(trimmed)}'"
    return f"'{sanitize_string(str(value))}'"


records: dict[str, dict[str, Any]] = {}
duplicate_slugs: set[str] = set()

for idx, item in enumerate(data):
    if not isinstance(item, dict):
        raise SystemExit(f"Entry at index {idx} is not a mapping.")

    slug = str(item["slug"]).strip()
    if slug in records:
        duplicate_slugs.add(slug)

    for field in required_fields[1:]:
        # Validate presence of required fields beyond slug.
        ensure_required_string(item, field, idx)

    latitude = item.get("latitude")
    longitude = item.get("longitude")
    if latitude is None or str(latitude).strip() == "":
        raise SystemExit(f"Latitude is required for record at index {idx}.")
    if longitude is None or str(longitude).strip() == "":
        raise SystemExit(f"Longitude is required for record at index {idx}.")

    record = {
        "slug": slug,
        "city_slug": ensure_required_string(item, "city", idx),
        "manufacturer": ensure_required_string(item, "manufacturer", idx),
        "focus": clean_optional_list(item.get("focus")),
        "brand": clean_optional_list(item.get("brand")),
        "address": clean_optional_string(item.get("address")),
        "rank": item.get("rank"),
        "selection": clean_optional_string(item.get("selection")),
        "latitude": item.get("latitude"),
        "longitude": item.get("longitude"),
    }

    records[slug] = record

if not records:
    raise SystemExit("No valid factory records were found in the YAML source.")

timestamp = datetime.now(tz=timezone.utc).isoformat()
sorted_records = [records[key] for key in sorted(records.keys())]

with output_path.open("w", encoding="utf-8") as fh:
    fh.write("-- Seed: factories\n")
    fh.write("-- File generated by scripts/generate_factories_seed.sh\n")
    fh.write(f"-- Source: {input_path}\n")
    fh.write(f"-- Generated at: {timestamp}\n\n")

    fh.write("BEGIN;\n")
    fh.write("TRUNCATE TABLE public.factories RESTART IDENTITY CASCADE;\n\n")

    fh.write(
        "INSERT INTO public.factories (slug, city_slug, manufacturer, focus, brand, address, rank, selection, latitude, longitude)\n"
        "VALUES\n"
    )

    for idx, record in enumerate(sorted_records):
        formatted_values = ", ".join(
            format_value(column, record.get(column)) for column in columns
        )
        prefix = "  " if idx == 0 else ", "
        fh.write(f"{prefix}({formatted_values})\n")

    fh.write(
        "ON CONFLICT (slug) DO UPDATE SET\n"
        "  city_slug = EXCLUDED.city_slug,\n"
        "  manufacturer = EXCLUDED.manufacturer,\n"
        "  focus = EXCLUDED.focus,\n"
        "  brand = EXCLUDED.brand,\n"
        "  address = EXCLUDED.address,\n"
        "  rank = EXCLUDED.rank,\n"
        "  selection = EXCLUDED.selection,\n"
        "  latitude = EXCLUDED.latitude,\n"
        "  longitude = EXCLUDED.longitude,\n"
        "  updated_at = now();\n\n"
    )

    fh.write("COMMIT;\n")

if duplicate_slugs:
    sys.stderr.write(
        f"Warning: encountered {len(duplicate_slugs)} duplicate slug(s); "
        "later entries override earlier ones.\n"
    )

print(f"Wrote {len(sorted_records)} factory records to {output_path}")
PY

echo "Seed written to ${OUTPUT_FILE}"


