# SignalK Authentication

## Overview

SignalK servers can require authentication for data access and write operations. This is controlled by the `security.json` file in the `.signalk` directory.

## Security Configuration File

Location: `~/.signalk/security.json`

### Key Fields

| Field | Purpose |
|-------|---------|
| `allow_readonly` | Allow unauthenticated read access to data |
| `secretKey` | Server-specific key for signing JWT tokens |
| `users` | Admin users for web UI authentication |
| `devices` | Registered devices with their tokens |
| `acls` | Access Control Lists (can cause issues - see below) |

### Minimal Working Configuration

```json
{
  "allow_readonly": true,
  "expiration": "NEVER",
  "secretKey": "<unique-per-server>",
  "users": [...],
  "devices": [...],
  "acls": []
}
```

## Device Authentication

### How It Works

1. Device requests access token from server
2. Server generates JWT with `{"device": "deviceId"}` payload
3. Device stores token and sends it with WebSocket connections
4. Server validates token signature using its `secretKey`

### WebSocket Authentication

Devices authenticate by sending the token in the HTTP header during WebSocket upgrade:

```
Authorization: Bearer <jwt-token>
```

### Token Validation

Tokens are server-specific because each server has a unique `secretKey`. A token from server A will not work on server B.

## Common Authentication Problems

### "Needs Authentication" Despite Valid Token

**Symptom**: Device shows "Connected" in its logs, but:
- Dashboard shows "needs authentication"
- TX counter stuck at 1, RX=0
- No data appears in SignalK

**Root Cause**: ACLs defined in `security.json`

Even when ACLs appear permissive (allowing read/write/put for "any"), they can block WebSocket authentication for devices. The `shouldAllowWrite()` function in SignalK's token security module evaluates ACLs in ways that may reject valid device tokens.

**Diagnosis**:
```bash
# Check if ACLs are defined
cat ~/.signalk/security.json | grep -A 20 '"acls"'
```

Problematic configuration (ACLs defined):
```json
{
  "acls": [
    {
      "context": "vessels.self",
      "resources": [{
        "paths": ["*"],
        "permissions": [
          {"subject": "any", "permission": "read"},
          {"subject": "any", "permission": "write"},
          {"subject": "any", "permission": "put"}
        ]
      }]
    }
  ]
}
```

**Fix**: Remove all ACLs from `security.json`:

```json
{
  "acls": []
}
```

Then restart SignalK:
```bash
sudo systemctl restart signalk
```

### Token From Wrong Server

**Symptom**: Device worked on Server A, moved to Server B, now fails.

**Cause**: Each server has a unique `secretKey`. Tokens are not portable between servers.

**Fix**: Generate a new token on the target server:
1. Go to Security → Access Requests in admin UI
2. Restart device to trigger new token request
3. Approve the request

### Device Not Sending Authorization Header

**Symptom**: Server logs show `401 Unauthorized` or no auth attempt.

**Diagnosis**: Check device code sends the header correctly:
```cpp
// SensESP example
String auth_header = String("Authorization: Bearer ") + auth_token_ + "\r\n";
config.headers = auth_header.c_str();
```

**Test with Python**:
```python
import asyncio
import websockets

async def test():
    uri = "ws://server:3000/signalk/v1/stream?subscribe=none"
    headers = {"Authorization": f"Bearer {token}"}
    async with websockets.connect(uri, additional_headers=headers) as ws:
        print(await ws.recv())

asyncio.run(test())
```

## Verifying Authentication

### Check Device Registration

```bash
cat ~/.signalk/security.json | jq '.devices'
```

### Test Token Validity

```bash
# Should return 426 (upgrade required) not 401 (unauthorized)
curl -I -H "Authorization: Bearer <token>" \
  http://server:3000/signalk/v1/stream
```

### Monitor WebSocket Connections

In SignalK admin UI: Security → Active Tokens shows authenticated connections.

## Best Practices

1. **Keep ACLs empty** (`"acls": []`) unless you have specific access control requirements
2. **Don't share tokens** between devices - each device should have its own
3. **Set `allow_readonly: true`** for most installations to allow unauthenticated read access
4. **Tokens don't expire** when `"expiration": "NEVER"` is set
5. **Back up security.json** before making changes - it contains the secretKey needed to validate existing tokens
