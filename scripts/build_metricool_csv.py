"""Build a Metricool import CSV from the Dört. content calendar.

The Metricool template is downloaded from Calendar, Import CSV, Download
template. This script keeps that column order and only fills the post rows.

    python scripts/build_metricool_csv.py --template marketing/social/metricool_template.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONTENT = ROOT / "marketing" / "social" / "30_day_content_calendar.csv"
DEFAULT_TEMPLATE = ROOT / "marketing" / "social" / "metricool_template.csv"
DEFAULT_MANIFEST = ROOT / "public" / "social" / "2026-10" / "index.json"
DEFAULT_OUTPUT = ROOT / "marketing" / "social" / "Dort_Metricool_30_Gun_READY.csv"

OFF_NETWORKS = (
    "Facebook",
    "Twitter/X",
    "LinkedIn",
    "GBP",
    "Pinterest",
    "YouTube",
    "Threads",
    "Bluesky",
)


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise SystemExit(f"CSV başlığı yok: {path}")
        headers = list(reader.fieldnames)
        rows = []
        for row in reader:
            if row and any((value or "").strip() for value in row.values()):
                rows.append(row)
        return headers, rows


def column_index(headers: list[str], name: str) -> int | None:
    for index, header in enumerate(headers):
        if header.strip() == name:
            return index
    return None


def require_column(headers: list[str], name: str) -> int:
    index = column_index(headers, name)
    if index is None:
        raise SystemExit(f"Metricool şablonunda '{name}' sütunu yok.")
    return index


def load_manifest(path: Path) -> dict[int, str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list) or len(payload) != 30:
        raise SystemExit("index.json tam 30 gün içermeli.")
    urls: dict[int, str] = {}
    for item in payload:
        day = int(item["day"])
        filename = str(item["filename"])
        public_url = str(item["publicUrl"])
        expected_name = f"day{day:02d}.jpg"
        expected_url = f"https://dortapp.com/social/2026-10/{expected_name}"
        if filename != expected_name or public_url != expected_url:
            raise SystemExit(f"Gün {day} manifest adresi beklenen biçime uymuyor.")
        urls[day] = public_url
    if set(urls) != set(range(1, 31)):
        raise SystemExit("index.json günleri 1-30 aralığını karşılamıyor.")
    return urls


def post_text(row: dict[str, str]) -> str:
    long_caption = (row.get("uzun_caption") or "").strip()
    short_caption = (row.get("kisa_caption") or "").strip()
    call_to_action = (row.get("cta") or "").strip()
    hashtags = (row.get("hashtag_seti") or "").strip()
    body = long_caption or short_caption
    parts = [part for part in (body, call_to_action, hashtags) if part]
    return "\n\n".join(parts)


def content_by_day(rows: list[dict[str, str]]) -> dict[int, dict[str, str]]:
    by_day: dict[int, dict[str, str]] = {}
    for row in rows:
        raw_day = (row.get("gun") or "").strip()
        if not raw_day:
            continue
        by_day[int(raw_day)] = row
    if set(by_day) != set(range(1, 31)):
        raise SystemExit("İçerik CSV'si 1-30 günlerinin tamamını içermeli.")
    return by_day


def build_rows(
    headers: list[str],
    posts: dict[int, dict[str, str]],
    urls: dict[int, str],
) -> list[list[str]]:
    text_index = require_column(headers, "Text")
    picture_index = require_column(headers, "Picture Url 1")
    instagram_index = require_column(headers, "Instagram")
    tiktok_index = require_column(headers, "TikTok")
    twitter_index = require_column(headers, "Twitter/X")
    draft_index = require_column(headers, "Draft")
    instagram_type_index = column_index(headers, "Instagram Post Type")
    off_indexes = [
        index
        for name in OFF_NETWORKS
        if (index := column_index(headers, name)) is not None
    ]

    output: list[list[str]] = []
    for day in range(1, 31):
        row = [""] * len(headers)
        row[text_index] = post_text(posts[day])
        row[picture_index] = urls[day]
        row[instagram_index] = "TRUE"
        row[tiktok_index] = "TRUE"
        row[twitter_index] = "FALSE"
        row[draft_index] = "FALSE"
        for index in off_indexes:
            row[index] = "FALSE"
        if instagram_type_index is not None:
            row[instagram_type_index] = "POST"
        output.append(row)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Dört. Metricool CSV hazırlar.")
    parser.add_argument("--content", type=Path, default=DEFAULT_CONTENT)
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    if not args.template.is_file():
        raise SystemExit(
            "Metricool şablonu yok. Calendar > Import CSV > Download template "
            f"dosyasını şuraya koyun: {args.template}"
        )

    headers, _template_rows = read_csv(args.template)
    _content_headers, content_rows = read_csv(args.content)
    urls = load_manifest(args.manifest)
    ready_rows = build_rows(headers, content_by_day(content_rows), urls)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(headers)
        writer.writerows(ready_rows)
    print(args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
