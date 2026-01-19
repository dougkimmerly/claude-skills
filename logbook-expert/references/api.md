# Logbook REST API

Base URL: `/plugins/signalk-logbook`

## Authentication

The API uses SignalK JWT authentication. Include the token in requests:

```bash
curl -H "Authorization: Bearer <token>" http://server/plugins/signalk-logbook/logs
```

Or use cookies if authenticated via SignalK web UI.

## Endpoints

### List Available Dates

```
GET /logs
```

**Response:**
```json
{
  "dates": ["2024-01-15", "2024-01-14", "2024-01-13"]
}
```

### Get Entries for Date

```
GET /logs/{date}
```

**Example:**
```bash
curl http://192.168.22.16/plugins/signalk-logbook/logs/2024-01-15
```

**Response:**
```json
[
  {
    "datetime": "2024-01-15T08:30:00.000Z",
    "text": "Departed marina",
    "category": "navigation",
    "author": "doug",
    "position": {
      "latitude": 49.123,
      "longitude": -123.456
    },
    "speed": { "sog": 5.2 }
  },
  {
    "datetime": "2024-01-15T09:00:00.000Z",
    "text": "Hourly log",
    "author": "auto"
  }
]
```

### Get Single Entry

```
GET /logs/{date}/{datetime}
```

**Example:**
```bash
curl http://192.168.22.16/plugins/signalk-logbook/logs/2024-01-15/2024-01-15T08:30:00.000Z
```

### Create Entry

```
POST /logs
Content-Type: application/json
```

**Request Body:**
```json
{
  "text": "Departed marina, heading south",
  "category": "navigation",
  "ago": 0,
  "observations": {
    "seaState": 2,
    "cloudCoverage": 3,
    "visibility": 7
  }
}
```

**Parameters:**
| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Entry description (required) |
| `category` | string | navigation, engine, radio, maintenance |
| `ago` | number | Minutes to backdate (0-15) |
| `observations` | object | Manual weather observations |
| `position` | object | Override position (lat/lon) |

**Response:** Created entry with all auto-populated fields

**Example:**
```bash
curl -X POST http://192.168.22.16/plugins/signalk-logbook/logs \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Sighted whale pod off starboard",
    "category": "navigation",
    "ago": 5
  }'
```

### Update Entry

```
PUT /logs/{date}/{datetime}
Content-Type: application/json
```

**Request Body:** Complete entry object with modifications

**Example:**
```bash
curl -X PUT http://192.168.22.16/plugins/signalk-logbook/logs/2024-01-15/2024-01-15T08:30:00.000Z \
  -H "Content-Type: application/json" \
  -d '{
    "datetime": "2024-01-15T08:30:00.000Z",
    "text": "Departed marina - UPDATED",
    "category": "navigation",
    "author": "doug"
  }'
```

### Delete Entry

```
DELETE /logs/{date}/{datetime}
```

**Example:**
```bash
curl -X DELETE http://192.168.22.16/plugins/signalk-logbook/logs/2024-01-15/2024-01-15T08:30:00.000Z
```

**Response:** 200 OK on success

## Node-RED Integration

### Read Today's Entries

```json
{
  "id": "http-request",
  "type": "http request",
  "method": "GET",
  "url": "http://localhost/plugins/signalk-logbook/logs/{{payload.date}}",
  "ret": "obj"
}
```

### Create Entry from Node-RED

```json
{
  "id": "http-request",
  "type": "http request",
  "method": "POST",
  "url": "http://localhost/plugins/signalk-logbook/logs",
  "ret": "obj",
  "headers": {
    "Content-Type": "application/json"
  }
}
```

**Function node to prepare payload:**
```javascript
msg.payload = {
  text: msg.payload.message || "Automatic entry from Node-RED",
  category: "navigation",
  ago: 0
};
return msg;
```

## OpenAPI Specification

Full API specification available at:
- `schema/openapi.yaml` (source)
- `schema/openapi.json` (generated)

## Error Responses

| Status | Meaning |
|--------|---------|
| 400 | Invalid entry data (validation failed) |
| 401 | Authentication required |
| 404 | Entry or date not found |
| 500 | Server error |

**Error Response Format:**
```json
{
  "error": "Validation failed",
  "message": "Missing required field: text"
}
```

## CORS

The API inherits SignalK server CORS settings. For external applications, ensure SignalK is configured to allow your origin.

## Rate Limiting

No explicit rate limiting. However, avoid creating entries more frequently than once per minute to prevent log bloat.
