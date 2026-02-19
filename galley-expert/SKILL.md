---
name: galley-expert
description: Galley Meal Planner development expertise for offline-first PWA meal planning on cruising sailboats. Use when developing features, fixing bugs, or extending the Galley app — recipe management, meal planning, inventory sync, ingredient matching, Google Sheets integration, recipe scanning/import, or frontend views. Covers Express/PostgreSQL backend, vanilla JS SPA frontend, Docker deployment, and offline-first patterns.
triggers:
  - galley
  - meal planner
  - recipe
  - meal planning
  - inventory
  - food
  - boat galley
  - grocery
  - shopping list
---

# Galley Expert

Offline-first PWA meal planner for cruising sailboats. Node.js/Express backend with PostgreSQL, vanilla JS frontend, Docker deployment.

## Quick Reference

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js 18+ |
| Server | Express 4.21 |
| Database | PostgreSQL (dk400, schema: galley) |
| Frontend | Vanilla JS SPA (no framework) |
| Styling | Custom CSS (Tailwind-inspired) |
| Container | Docker (Alpine Node 20) |
| Port | 3122 |
| Access | Tailscale VPN (no auth layer) |

### Project Structure

```
src/
├── app.js                  # Express server entry point
├── db/
│   ├── index.js            # PostgreSQL pool + query helpers
│   └── schema-postgres.sql # Full schema with seed data
├── models/
│   ├── recipe.js           # Recipe DAL + ingredient matching
│   ├── inventory.js        # Inventory DAL + Sheets sync
│   └── meal.js             # Meal DAL
├── routes/
│   ├── recipes.js          # Recipe CRUD + search + matching
│   ├── inventory.js        # Inventory + Google Sheets sync
│   ├── meals.js            # Meal planning + calendar
│   └── scans.js            # Recipe scan upload
├── services/
│   ├── sheets.js           # Google Sheets API client
│   ├── recipeImport.js     # URL/crawler recipe import
│   ├── recipeParser.js     # OCR/extraction parsing
│   └── pdfSplitter.js      # PDF handling
└── middleware/
    └── errors.js           # Error handling chain
public/
├── index.html              # PWA entry point
├── manifest.json           # PWA manifest
├── sw.js                   # Service worker
├── css/styles.css          # All styling
└── js/
    ├── app.js              # Main app logic + hash router
    ├── api.js              # Fetch-based API client
    └── views.js            # View rendering (all views)
```

### Database Query Interface

All DB operations are async. Use the normalized helper:

```javascript
// SELECT multiple rows
const recipes = await db.all('SELECT * FROM galley.recipes WHERE $1 = ANY(tags)', [tag]);

// SELECT single row
const recipe = await db.get('SELECT * FROM galley.recipes WHERE id = $1', [id]);

// INSERT/UPDATE/DELETE
const result = await db.run('INSERT INTO galley.recipes (name) VALUES ($1)', [name]);

// Transaction
await db.transaction(async () => {
  await db.run('INSERT INTO galley.meals ...', [...]);
  await db.run('INSERT INTO galley.meal_recipes ...', [...]);
});
```

### JSON Fields

These columns store JSON strings — stringify on write, parse on read:

| Table | Column | Format |
|-------|--------|--------|
| recipes | ingredients | `[{"name":"flour","amount":"2","unit":"cups"}]` |
| recipes | instructions | `["Step 1...", "Step 2..."]` |
| recipes | tags | `["dinner","one-pot","quick"]` |
| ingredients | common_substitutes | `["item1","item2"]` |

### Boat-Specific Flags

Recipes have boolean flags for galley constraints:

| Flag | Meaning |
|------|---------|
| one_pot | Single pot/pan only |
| no_oven | No oven required |
| pressure_cooker | Uses pressure cooker |
| microwave | Uses microwave |

### Frontend Routing (Hash-based SPA)

| Route | View | File |
|-------|------|------|
| `#/` | Recipe list | views.js |
| `#/meals` | Meal planning + calendar | views.js |
| `#/inventory` | Inventory with sync | views.js |
| `#/settings` | App configuration | views.js |

### Key API Endpoints

```
GET    /api/health
GET    /api/recipes                    # ?search, ?tag, ?minRating, ?onePot, ?noOven
GET    /api/recipes/:id
POST   /api/recipes
PUT    /api/recipes/:id
DELETE /api/recipes/:id
POST   /api/recipes/:id/made           # Increment times_made
GET    /api/recipes/match?ingredients=  # Find by available ingredients

GET    /api/inventory                   # ?category, ?location
POST   /api/inventory
PUT    /api/inventory/:id
POST   /api/inventory/sync              # Trigger Google Sheets sync
GET    /api/inventory/stats

GET    /api/meals                       # ?status, ?date, ?upcoming
POST   /api/meals
PUT    /api/meals/:id
POST   /api/meals/:id/recipes/:recipeId # Add recipe to meal
POST   /api/meals/:id/made              # Mark meal completed

POST   /api/scans/upload                # Upload recipe image/PDF
```

### Ingredient Matching Algorithm

The fuzzy matcher normalizes both inventory and recipe ingredients:
1. Lowercase and trim
2. Strip prefixes: canned, fresh, dried, frozen, etc.
3. Handle "Category - Item" format (reverses to "Item")
4. Substring match with 3+ character threshold
5. Returns: `have` (in inventory), `missing`, `substitutable`

### Inventory Locations (Google Sheets)

| Code | Meaning | Access Color |
|------|---------|-------------|
| Act | Active/daily use | Green |
| Foot | Foot locker | Amber |
| Loc1-6 | Storage lockers | Amber/Red |
| Cellar | Deep storage | Red |

### Error Handling Pattern

All routes follow:
```javascript
router.get('/endpoint', async (req, res, next) => {
  try {
    // ... logic
    res.json(result);
  } catch (err) {
    next(err);  // Passes to middleware chain
  }
});
```

Middleware chain: errorLogger → databaseErrorHandler → validationErrorHandler → fallbackErrorHandler

### Development Commands

| Command | Purpose |
|---------|---------|
| `npm install` | Install dependencies |
| `npm run dev` | Dev server with auto-reload |
| `npm start` | Production server |
| `npm run db:reset` | Reset database (fresh seed) |
| `npm run test:e2e` | Playwright E2E tests |
| `npm run lint` | ESLint check |

### Deployment (Two-Repo Pattern)

```bash
# 1. Push source code
git push

# 2. On docker-server (192.168.20.19)
ssh doug@192.168.20.19
cd /home/doug/dkSRC/apps/galley-meal-planner && git pull
cd /opt/docker-server/galley && docker compose up -d --build
```

### Critical Rules

1. **Offline-first always** — no external API calls in core paths
2. **JSON fields** — stringify/parse ingredients, instructions, tags
3. **Async everywhere** — all DB and route handlers use async/await
4. **Parameterized queries** — never interpolate SQL, use $1, $2, etc.
5. **Schema prefix** — all tables use `galley.` schema prefix in queries
6. **Update INFRASTRUCTURE.md** — when deployment changes
7. **Follow style guide** — `.claude/context/style-guide.md` for UI patterns

## Detailed References

- **[references/database.md](references/database.md)** — Complete schema, all 11 tables, indexes, seed data, JSON field formats
- **[references/api.md](references/api.md)** — Full API endpoint documentation with request/response examples
- **[references/frontend.md](references/frontend.md)** — SPA architecture, views, components, styling patterns, PWA setup
- **[references/patterns.md](references/patterns.md)** — Code patterns for models, routes, services, error handling, testing
- **[references/deployment.md](references/deployment.md)** — Docker setup, two-repo architecture, environment config, volumes
- **[references/domain.md](references/domain.md)** — Boat galley domain knowledge, substitutions, storage, meal planning context

## Key Documentation

| Resource | Location |
|----------|----------|
| Main CLAUDE.md | `galley-meal-planner/CLAUDE.md` |
| API Reference | `.claude/context/api-reference.md` |
| Architecture | `.claude/context/architecture.md` |
| Database Docs | `.claude/context/database.md` |
| Style Guide | `.claude/context/style-guide.md` |
| Roadmap | `.claude/context/roadmap.md` |
| Infrastructure | `INFRASTRUCTURE.md` |
