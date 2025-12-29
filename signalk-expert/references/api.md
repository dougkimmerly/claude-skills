# SignalK APIs

## Server Endpoints

| Endpoint | Purpose |
|----------|---------|
| `http://host:3000` | Web UI |
| `http://host:3000/admin` | Admin panel |
| `http://host:3000/signalk` | API discovery |
| `http://host:3000/signalk/v1/api/` | REST API root |
| `ws://host:3000/signalk/v1/stream` | WebSocket stream |

## REST API

### Get Full State

```bash
curl http://localhost:3000/signalk/v1/api/
```

### Get Specific Path

```bash
curl http://localhost:3000/signalk/v1/api/vessels/self/navigation/speedOverGround
```

Response:
```json
{
  "value": 3.5,
  "timestamp": "2025-12-02T10:30:00.000Z",
  "$source": "gps.GP"
}
```

### PUT Command

```bash
curl -X PUT http://localhost:3000/signalk/v1/api/vessels/self/navigation/anchor/setAnchor \
  -H "Content-Type: application/json" \
  -d '{"value": {"latitude": 43.65, "longitude": 7.02, "depth": 15}}'
```

Response:
```json
{
  "state": "COMPLETED",
  "statusCode": 200
}
```

## WebSocket API

### Connect with Auto-Subscribe

```javascript
const ws = new WebSocket('ws://localhost:3000/signalk/v1/stream?subscribe=self');
```

### Connect without Subscribe

```javascript
const ws = new WebSocket('ws://localhost:3000/signalk/v1/stream?subscribe=none');
```

### Subscribe Message

```javascript
ws.send(JSON.stringify({
  context: 'vessels.self',
  subscribe: [
    {
      path: 'navigation.speedOverGround',
      period: 1000,      // Update interval ms
      policy: 'ideal'    // or 'instant', 'fixed'
    },
    {
      path: 'navigation.position',
      period: 1000
    }
  ]
}));
```

### Subscription Policies

| Policy | Behavior |
|--------|---------|
| `instant` | Send immediately on change |
| `ideal` | Send at period, skip if unchanged |
| `fixed` | Send at fixed period always |

### Unsubscribe

```javascript
// Unsubscribe from specific path
ws.send(JSON.stringify({
  context: 'vessels.self',
  unsubscribe: [{ path: 'navigation.speedOverGround' }]
}));

// Unsubscribe from all
ws.send(JSON.stringify({
  context: '*',
  unsubscribe: [{ path: '*' }]
}));
```

### Send Delta via WebSocket

```javascript
ws.send(JSON.stringify({
  context: 'vessels.self',
  updates: [{
    source: { label: 'my-client' },
    values: [
      { path: 'navigation.speedOverGround', value: 3.5 }
    ]
  }]
}));
```

## Authentication

### Get Token

```bash
curl -X POST http://localhost:3000/signalk/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'
```

### Use Token

```bash
curl http://localhost:3000/signalk/v1/api/ \
  -H "Authorization: Bearer <token>"
```

WebSocket:
```javascript
const ws = new WebSocket('ws://localhost:3000/signalk/v1/stream?token=<token>');
```
