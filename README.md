# pattayapilot

## Events API

Public JSON API serving event data from the Pattaya Pilot events calendar.

**Endpoint:** `https://pattayapilot.com/api/v1/events/index.json`

No authentication required.

### Example

```bash
curl https://pattayapilot.com/api/v1/events/index.json
```

### Response format

```json
{
  "meta": {
    "version": "1.0.0",
    "generated_at": "2026-04-09T05:26:04Z",
    "source": "elfsight",
    "total_events": 159
  },
  "event_types": [
    { "id": "pool-party", "name": "Pool Party" }
  ],
  "venues": [
    { "id": "buzzin-lounge", "name": "Buzzin Lounge", "directions_url": "https://maps.app.goo.gl/..." }
  ],
  "events": [
    {
      "id": "uuid",
      "title": "Event Name",
      "date": "2025-07-29",
      "start_time": "16:00",
      "end_time": "20:00",
      "is_all_day": false,
      "timezone": "Asia/Bangkok",
      "event_type": "Food Special",
      "event_type_id": "food-special",
      "venue": "Free Willy",
      "venue_id": "free-willy",
      "directions_url": "https://maps.app.goo.gl/...",
      "image_url": "https://files.elfsightcdn.com/...",
      "description": "Plain text description",
      "color": "rgb(17, 85, 178)",
      "button_link": "https://...",
      "button_text": "Directions",
      "recurring": true,
      "recurrence_rule": "weekly:tuesday",
      "repeat_ends": "never",
      "repeat_ends_date": null,
      "tags": ["Free Willy"]
    }
  ]
}
```

### Regenerating the events JSON

The events data is sourced from the Elfsight calendar widget. To regenerate:

```bash
./scripts/generate-events.sh
```

This fetches live data from the Elfsight public API, transforms it, and writes `api/v1/events/index.json`. Then commit and push the updated file.

**Requirements:** `curl` and `python3` (no additional packages needed).