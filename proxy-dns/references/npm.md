# Nginx Proxy Manager (NPM) Reference

## Infrastructure

| Item | Value |
|------|-------|
| Host | Docker Server (192.168.20.19) |
| Container | `nginx-proxy-manager` |
| Admin UI | http://192.168.20.19:81 |
| HTTP Port | 80 |
| HTTPS Port | 443 |
| API Base | http://192.168.20.19:81/api |

## Authentication

### Get Token

```bash
NPM_TOKEN=$(curl -s -X POST "http://192.168.20.19:81/api/tokens" \
  -H "Content-Type: application/json" \
  -d '{"identity":"EMAIL","secret":"PASSWORD"}' | jq -r '.token')
```

### Token Header

All API requests require:
```
Authorization: Bearer $NPM_TOKEN
```

### Token Expiry

Tokens expire after some time. Re-authenticate if you get 401 errors.

## API Endpoints

### Proxy Hosts

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/nginx/proxy-hosts` | List all proxy hosts |
| GET | `/api/nginx/proxy-hosts/{id}` | Get specific proxy host |
| POST | `/api/nginx/proxy-hosts` | Create proxy host |
| PUT | `/api/nginx/proxy-hosts/{id}` | Update proxy host |
| DELETE | `/api/nginx/proxy-hosts/{id}` | Delete proxy host |

### Certificates

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/nginx/certificates` | List certificates |
| POST | `/api/nginx/certificates` | Create certificate |

## List Proxy Hosts

```bash
curl -s "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" | jq '.[] | {id, domain_names, forward_host, forward_port}'
```

Full details:
```bash
curl -s "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" | jq '.'
```

## Create Proxy Host

### Basic (No SSL)

```bash
curl -s -X POST "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["service.kbl55.com"],
    "forward_scheme": "http",
    "forward_host": "192.168.20.XX",
    "forward_port": 8080,
    "access_list_id": 0,
    "certificate_id": 0,
    "ssl_forced": false,
    "http2_support": false,
    "block_exploits": true,
    "allow_websocket_upgrade": true,
    "caching_enabled": false,
    "locations": [],
    "meta": {
      "letsencrypt_agree": false,
      "dns_challenge": false
    }
  }'
```

### With SSL (Existing Certificate)

```bash
curl -s -X POST "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["service.kbl55.com"],
    "forward_scheme": "http",
    "forward_host": "192.168.20.XX",
    "forward_port": 8080,
    "certificate_id": CERT_ID,
    "ssl_forced": true,
    "http2_support": true,
    "block_exploits": true,
    "allow_websocket_upgrade": true
  }'
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `domain_names` | array | List of domains (usually one) |
| `forward_scheme` | string | `http` or `https` |
| `forward_host` | string | Upstream IP or hostname |
| `forward_port` | integer | Upstream port |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `certificate_id` | integer | 0 | SSL cert ID (0 = none) |
| `ssl_forced` | boolean | false | Redirect HTTP to HTTPS |
| `http2_support` | boolean | false | Enable HTTP/2 |
| `block_exploits` | boolean | true | Block common exploits |
| `allow_websocket_upgrade` | boolean | true | Allow WebSocket |
| `caching_enabled` | boolean | false | Enable caching |
| `access_list_id` | integer | 0 | Access list (0 = public) |
| `advanced_config` | string | "" | Custom nginx config |

## Update Proxy Host

```bash
curl -s -X PUT "http://192.168.20.19:81/api/nginx/proxy-hosts/{id}" \
  -H "Authorization: Bearer $NPM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain_names": ["service.kbl55.com"],
    "forward_scheme": "http",
    "forward_host": "192.168.20.XX",
    "forward_port": 8080,
    "block_exploits": true,
    "allow_websocket_upgrade": true
  }'
```

## Delete Proxy Host

```bash
curl -s -X DELETE "http://192.168.20.19:81/api/nginx/proxy-hosts/{id}" \
  -H "Authorization: Bearer $NPM_TOKEN"
```

## List Certificates

```bash
curl -s "http://192.168.20.19:81/api/nginx/certificates" \
  -H "Authorization: Bearer $NPM_TOKEN" | jq '.[] | {id, nice_name, domain_names, expires_on}'
```

## Common Patterns

### Internal Service (HTTP only)

For services only accessed internally:

```json
{
  "domain_names": ["service.kbl55.com"],
  "forward_scheme": "http",
  "forward_host": "192.168.20.XX",
  "forward_port": 8080,
  "certificate_id": 0,
  "ssl_forced": false,
  "block_exploits": true,
  "allow_websocket_upgrade": true
}
```

### WebSocket Service

For services using WebSockets (n8n, Home Assistant, etc.):

```json
{
  "domain_names": ["service.kbl55.com"],
  "forward_scheme": "http",
  "forward_host": "192.168.20.XX",
  "forward_port": 8080,
  "allow_websocket_upgrade": true,
  "http2_support": false
}
```

### HTTPS Upstream

For services that require HTTPS backend:

```json
{
  "forward_scheme": "https",
  "forward_host": "192.168.20.XX",
  "forward_port": 443
}
```

## Troubleshooting

### 502 Bad Gateway

- Upstream service not running
- Wrong IP or port
- Firewall blocking connection
- Service bound to localhost only

Check upstream:
```bash
curl -s -o /dev/null -w '%{http_code}' http://192.168.20.XX:PORT
```

### 504 Gateway Timeout

- Upstream service too slow
- Network issues

### 401 Unauthorized (API)

Token expired. Re-authenticate.

### SSL Certificate Issues

- Check certificate expiry
- Verify domain DNS resolves
- For Let's Encrypt, domain must be publicly accessible

## Finding Proxy Host ID

```bash
# List all with IDs
curl -s "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" | jq '.[] | {id, domain_names}'

# Find specific domain
curl -s "http://192.168.20.19:81/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $NPM_TOKEN" | jq '.[] | select(.domain_names[] | contains("service")) | {id, domain_names}'
```
