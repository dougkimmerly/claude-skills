# Database Reference

PostgreSQL database on dk400 homelab server. Schema: `galley`. All queries must use the `galley.` prefix.

## Connection

```
Host: postgres-homelab
Port: 5432
Database: dk400
Schema: galley
User: galley
```

Pool configured in `src/db/index.js` with connection pooling (max 20).

## Tables

### recipes (Primary)

The core table. Stores everything about a recipe.

```sql
CREATE TABLE galley.recipes (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  ingredients TEXT,          -- JSON array of {name, amount, unit}
  instructions TEXT,         -- JSON array of step strings
  tags TEXT,                 -- JSON array of tag strings
  source_url TEXT,
  source_name TEXT,
  source_image_path TEXT,
  prep_time INTEGER,         -- minutes
  cook_time INTEGER,         -- minutes
  total_time INTEGER,        -- minutes
  servings INTEGER DEFAULT 4,
  one_pot BOOLEAN DEFAULT FALSE,
  no_oven BOOLEAN DEFAULT FALSE,
  pressure_cooker BOOLEAN DEFAULT FALSE,
  microwave BOOLEAN DEFAULT FALSE,
  user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),
  times_made INTEGER DEFAULT 0,
  last_made TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:** name, user_rating, last_made

### ingredients

Master ingredient list for normalization and matching.

```sql
CREATE TABLE galley.ingredients (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  category TEXT,              -- produce, protein, dairy, pantry, spice, etc.
  common_substitutes TEXT,    -- JSON array
  shelf_life_days INTEGER,
  storage TEXT                -- fridge, pantry, freezer
);
```

### substitutions

Pre-loaded from "The Boat Galley Cookbook". Used by ingredient matching.

```sql
CREATE TABLE galley.substitutions (
  id SERIAL PRIMARY KEY,
  original_ingredient TEXT NOT NULL,
  substitute TEXT NOT NULL,
  ratio TEXT,                 -- e.g. "1:1", "2 tbsp per cup"
  notes TEXT,
  quality TEXT DEFAULT 'good' -- exact, good, passable, emergency
);
```

**Seed data:** ~20 common substitutions (butter↔oil, milk↔powdered, eggs↔flax, etc.)

### inventory_cache

Local cache of Google Sheets inventory data. Enables offline access.

```sql
CREATE TABLE galley.inventory_cache (
  id SERIAL PRIMARY KEY,
  item_name TEXT NOT NULL,
  quantity REAL,
  unit TEXT,
  category TEXT,              -- canned, dry, produce, protein, etc.
  location TEXT,              -- Act, Foot, Loc1-6, Cellar
  expiry_date DATE,
  sheet_row_id TEXT,          -- Maps back to Sheets row
  last_synced TIMESTAMP,
  sync_status TEXT DEFAULT 'synced'  -- synced, pending, conflict
);
```

### meal_log

History of meals actually prepared.

```sql
CREATE TABLE galley.meal_log (
  id SERIAL PRIMARY KEY,
  date DATE NOT NULL,
  meal_type TEXT,             -- breakfast, lunch, dinner, snack
  recipe_id INTEGER REFERENCES galley.recipes(id),
  recipe_name TEXT,           -- Denormalized for offline access
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  notes TEXT,
  location TEXT,              -- GPS or anchorage name
  weather TEXT
);
```

### sync_queue

Offline changes pending synchronization.

```sql
CREATE TABLE galley.sync_queue (
  id SERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id INTEGER,
  operation TEXT NOT NULL,    -- insert, update, delete
  data TEXT,                  -- JSON of the change
  status TEXT DEFAULT 'pending',  -- pending, in_progress, completed, failed
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP
);
```

### settings

Key-value configuration store.

```sql
CREATE TABLE galley.settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Default keys:** default_servings, sheets_sync_enabled, theme, last_full_sync

### meals

Planned meals (the planning entity).

```sql
CREATE TABLE galley.meals (
  id SERIAL PRIMARY KEY,
  name TEXT,
  meal_type TEXT,             -- breakfast, lunch, dinner, snack
  diners INTEGER DEFAULT 2,
  scheduled_date DATE,
  status TEXT DEFAULT 'planned',  -- planned, made, skipped
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### meal_recipes (Junction)

Links meals to recipes with optional serving overrides.

```sql
CREATE TABLE galley.meal_recipes (
  id SERIAL PRIMARY KEY,
  meal_id INTEGER REFERENCES galley.meals(id) ON DELETE CASCADE,
  recipe_id INTEGER REFERENCES galley.recipes(id),
  servings_override INTEGER,
  sort_order INTEGER DEFAULT 0
);
```

### imported_files

Tracks imported files to prevent duplicate imports.

```sql
CREATE TABLE galley.imported_files (
  id SERIAL PRIMARY KEY,
  filename TEXT NOT NULL UNIQUE,
  imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### deleted_recipes

Tracks permanently deleted recipes to prevent re-import.

```sql
CREATE TABLE galley.deleted_recipes (
  id SERIAL PRIMARY KEY,
  recipe_name TEXT NOT NULL,
  source_url TEXT,
  deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## JSON Field Formats

### recipes.ingredients
```json
[
  {"name": "all-purpose flour", "amount": "2", "unit": "cups"},
  {"name": "butter", "amount": "1/2", "unit": "cup"},
  {"name": "salt", "amount": "1", "unit": "tsp"}
]
```

### recipes.instructions
```json
[
  "Preheat oven to 350F",
  "Mix dry ingredients in a large bowl",
  "Add wet ingredients and stir until combined"
]
```

### recipes.tags
```json
["dinner", "one-pot", "quick", "mexican"]
```

## Query Patterns

### Parameterized Queries (PostgreSQL style)
```javascript
// Use $1, $2, etc. — NEVER string interpolation
await db.all('SELECT * FROM galley.recipes WHERE name ILIKE $1', [`%${search}%`]);
```

### Safe ORDER BY
```javascript
// Whitelist sort columns — never use user input directly
const VALID_SORTS = ['name', 'created_at', 'user_rating', 'times_made'];
const sortBy = VALID_SORTS.includes(req.query.sortBy) ? req.query.sortBy : 'name';
```

### Transaction Pattern
```javascript
await db.transaction(async () => {
  const meal = await db.run(
    'INSERT INTO galley.meals (name, meal_type) VALUES ($1, $2) RETURNING id',
    [name, type]
  );
  await db.run(
    'INSERT INTO galley.meal_recipes (meal_id, recipe_id) VALUES ($1, $2)',
    [meal.id, recipeId]
  );
});
```
