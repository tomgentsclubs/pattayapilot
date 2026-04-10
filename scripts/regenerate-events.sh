#!/usr/bin/env bash
#
# Fetches event data from the Elfsight widget API and generates
# the static JSON API file at api/v1/events/index.json
#
# Usage:
#   ./scripts/generate-events.sh
#
# Requirements:
#   - curl
#   - python3 (ships with macOS / most Linux distros)
#
# The Elfsight boot API is public and unauthenticated — it serves
# the same data the calendar widget loads on the events page.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/api/v1/events/index.json"

WIDGET_ID="a420d7b3-7429-492e-b394-3f772b3d23b3"
BOOT_URL="https://core.service.elfsight.com/p/boot/?page=https%3A%2F%2Fpattayapilot.com%2Fevents%2F&w=${WIDGET_ID}"

echo "Fetching events from Elfsight API..."
RAW_JSON=$(curl -s "$BOOT_URL")

echo "Transforming data..."
mkdir -p "$(dirname "$OUTPUT_FILE")"

TEMP_FILE=$(mktemp)
echo "$RAW_JSON" > "$TEMP_FILE"

python3 - "$TEMP_FILE" "$OUTPUT_FILE" << 'PYTHON_SCRIPT'
import json
import sys
import re
from datetime import datetime, timezone

with open(sys.argv[1]) as f:
    raw = json.load(f)
output_path = sys.argv[2]

widget_data = list(raw["data"]["widgets"].values())[0]["data"]["settings"]

events_raw = widget_data["events"]
event_types = {t["id"]: t for t in widget_data.get("eventTypes", [])}
locations = {l["id"]: l for l in widget_data.get("locations", [])}

def strip_html(html):
    """Remove HTML tags and decode common entities."""
    if not html:
        return ""
    text = re.sub(r'<[^>]+>', ' ', html)
    text = text.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    text = text.replace('&quot;', '"').replace('&#39;', "'").replace('&nbsp;', ' ')
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def build_recurrence_rule(event):
    """Convert Elfsight repeat fields to a human-readable recurrence rule."""
    period = event.get("repeatPeriod", "noRepeat")
    if period == "noRepeat":
        return None

    if period == "weeklyOn":
        days = event.get("repeatWeeklyOnDays", [])
        day_map = {"mo": "monday", "tu": "tuesday", "we": "wednesday",
                   "th": "thursday", "fr": "friday", "sa": "saturday", "su": "sunday"}
        day_names = [day_map.get(d, d) for d in days]
        return f"weekly:{','.join(day_names)}" if day_names else "weekly"

    if period == "daily":
        interval = event.get("repeatInterval", 1)
        return f"daily:{interval}" if interval > 1 else "daily"

    if period == "lastDayInMonth":
        return "monthly:last_day"

    if period == "custom":
        interval = event.get("repeatInterval", 1)
        freq = event.get("repeatFrequency", "daily")
        return f"custom:{freq}:{interval}"

    return period

def extract_directions_url(description):
    """Pull Google Maps URL from description HTML if present."""
    if not description:
        return None
    match = re.search(r'https://maps\.app\.goo\.gl/[^\s<"]+', description)
    if match:
        return match.group(0)
    match = re.search(r'https://(?:www\.)?google\.com/maps[^\s<"]+', description)
    if match:
        return match.group(0)
    return None

def transform_event(event):
    """Transform a single Elfsight event into API format."""
    # Skip hidden events
    if event.get("visible") is False:
        return None

    # eventType and location are arrays of IDs
    et_ids = event.get("eventType", [])
    if isinstance(et_ids, list):
        et_id = et_ids[0] if et_ids else None
    else:
        et_id = et_ids
    et = event_types.get(et_id, {}) if et_id else {}

    loc_ids = event.get("location", [])
    if isinstance(loc_ids, list):
        loc_id = loc_ids[0] if loc_ids else None
    else:
        loc_id = loc_ids
    loc = locations.get(loc_id, {}) if loc_id else {}

    start = event.get("start", {})
    end = event.get("end", {})
    description_html = event.get("description", "")
    recurring = event.get("repeatPeriod", "noRepeat") != "noRepeat"

    return {
        "id": event["id"],
        "title": event.get("name", ""),
        "date": start.get("date"),
        "start_time": start.get("time"),
        "end_time": end.get("time"),
        "is_all_day": event.get("isAllDay", False),
        "timezone": event.get("timeZone", "Asia/Bangkok"),
        "event_type": et.get("name", ""),
        "event_type_id": et.get("filterID", ""),
        "venue": loc.get("name", ""),
        "venue_id": loc.get("filterID", ""),
        "directions_url": loc.get("website") or extract_directions_url(description_html) or None,
        "image_url": event.get("image", {}).get("url") if isinstance(event.get("image"), dict) else event.get("image") or None,
        "description": strip_html(description_html),
        "color": event.get("color") or None,
        "button_link": event["buttonLink"].get("value") or event["buttonLink"].get("rawValue") if isinstance(event.get("buttonLink"), dict) else event.get("buttonLink") or None,
        "button_text": event.get("buttonText") or None,
        "recurring": recurring,
        "recurrence_rule": build_recurrence_rule(event) if recurring else None,
        "repeat_ends": event.get("repeatEnds") if recurring else None,
        "repeat_ends_date": event.get("repeatEndsDate") if recurring else None,
        "tags": [t.get("tagName", t) if isinstance(t, dict) else t for t in event.get("tags", [])],
    }

# Transform all events, filtering out hidden ones
transformed = []
for event in events_raw:
    result = transform_event(event)
    if result is not None:
        transformed.append(result)

# Sort by date, then start_time
transformed.sort(key=lambda e: (e.get("date") or "", e.get("start_time") or ""))

# Build location and event_type lookup tables for the response
locations_list = [
    {
        "id": loc["filterID"],
        "name": loc["name"],
        "directions_url": loc.get("website") or None,
    }
    for loc in widget_data.get("locations", [])
]

event_types_list = [
    {
        "id": et["filterID"],
        "name": et["name"],
    }
    for et in widget_data.get("eventTypes", [])
]

output = {
    "meta": {
        "version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "elfsight",
        "total_events": len(transformed),
    },
    "event_types": event_types_list,
    "venues": locations_list,
    "events": transformed,
}

with open(output_path, "w") as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f"Generated {len(transformed)} events (skipped {len(events_raw) - len(transformed)} hidden)")
print(f"Event types: {len(event_types_list)}")
print(f"Venues: {len(locations_list)}")
PYTHON_SCRIPT

echo "Written to $OUTPUT_FILE"
echo "Done!"
