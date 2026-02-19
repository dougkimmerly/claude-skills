# API Reference

Base URL: `http://192.168.20.19:3122/api` (production) or `http://localhost:3122/api` (development)

All responses are JSON. Errors return `{ "error": "message", "status": code }`.

## Health

### GET /api/health

Returns server status, memory usage, database connectivity, uptime.

```json
{
  "status": "ok",
  "uptime": 86400,
  "memory": { "heapUsed": 45000000 },
  "database": { "status": "connected" }
}
```

## Recipes

### GET /api/recipes

List recipes with optional filtering.

| Param | Type | Description |
|-------|------|-------------|
| search | string | Search name and description (ILIKE) |
| tag | string | Filter by tag |
| minRating | int | Minimum user_rating (1-5) |
| onePot | bool | Filter one_pot recipes |
| noOven | bool | Filter no_oven recipes |
| sortBy | string | name, created_at, user_rating, times_made |
| sortOrder | string | asc, desc |
| limit | int | Max results (default 500) |
| offset | int | Pagination offset |

### GET /api/recipes/:id

Single recipe with all fields. JSON fields returned parsed.

### POST /api/recipes

Create recipe. Body: `{ name, description, ingredients, instructions, tags, ... }`

Required: `name`

### PUT /api/recipes/:id

Partial update. Only send fields to change.

### DELETE /api/recipes/:id

Soft-deletes by adding to deleted_recipes table, then removes from recipes.

### POST /api/recipes/:id/made

Records that recipe was made. Increments `times_made`, sets `last_made` to now.

Optional body: `{ rating, notes }`

### GET /api/recipes/match

Find recipes by available ingredients.

| Param | Type | Description |
|-------|------|-------------|
| ingredients | string | Comma-separated ingredient names |
| maxMissing | int | Max missing ingredients allowed (default 5) |

Returns recipes sorted by match quality with `have`, `missing`, `substitutable` arrays.

## Inventory

### GET /api/inventory

List inventory items.

| Param | Type | Description |
|-------|------|-------------|
| category | string | Filter by category |
| location | string | Filter by storage location |

### POST /api/inventory

Create item. Body: `{ item_name, quantity, unit, category, location }`

### PUT /api/inventory/:id

Update item. Partial updates supported.

### DELETE /api/inventory/:id

Remove item from local cache.

### GET /api/inventory/search?q=term

Search inventory by item name.

### GET /api/inventory/stats

Returns: `{ total, byCategory: {...}, byLocation: {...} }`

### POST /api/inventory/check

Check ingredient availability against inventory.

Body: `{ ingredients: ["flour", "butter", "eggs"] }`

Returns per-ingredient: `{ status: "have"|"missing"|"substitutable", location, substitute }`

## Google Sheets Sync

### GET /api/inventory/sync/status

Check if sync is configured and last sync time.

### GET /api/inventory/sync/settings

Current sheet ID, range, sync interval.

### PUT /api/inventory/sync/settings

Configure sync. Body: `{ sheetId, sheetRange }`

### POST /api/inventory/sync

Trigger manual sync from Google Sheets. Fetches sheet data, parses categories/locations, upserts inventory_cache.

### GET /api/inventory/sync/test

Test Google Sheets connection without syncing data.

## Meals

### GET /api/meals

List meals with filtering.

| Param | Type | Description |
|-------|------|-------------|
| status | string | planned, made, skipped |
| date | string | Specific date (YYYY-MM-DD) |
| upcoming | bool | Only future meals |

### GET /api/meals/:id

Single meal with associated recipes (joined via meal_recipes).

### POST /api/meals

Create meal. Body: `{ name, meal_type, diners, scheduled_date, notes }`

### PUT /api/meals/:id

Update meal details.

### DELETE /api/meals/:id

Delete meal (cascades to meal_recipes).

### POST /api/meals/:id/recipes/:recipeId

Add recipe to meal. Optional body: `{ servings_override, sort_order }`

### POST /api/meals/:id/made

Mark meal as completed. Updates status to 'made', creates meal_log entries.

## Scans

### POST /api/scans/upload

Upload recipe scan image or PDF. Uses multer for file handling.

- Content-Type: multipart/form-data
- Field: `file` (image/pdf)
- Returns: `{ id, filename, status: "uploaded" }`

Triggers n8n workflow for OCR processing (async).
