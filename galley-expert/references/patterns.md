# Code Patterns

Conventions and patterns used throughout the Galley codebase for consistency.

## Model Pattern

Models are the data access layer. Each model exports async functions that use the `db` helper.

```javascript
// src/models/recipe.js — typical model structure
const db = require('../db');

async function getAllRecipes(filters = {}) {
  let sql = 'SELECT * FROM galley.recipes WHERE 1=1';
  const params = [];
  let paramIndex = 1;

  if (filters.search) {
    sql += ` AND (name ILIKE $${paramIndex} OR description ILIKE $${paramIndex})`;
    params.push(`%${filters.search}%`);
    paramIndex++;
  }

  if (filters.tag) {
    sql += ` AND tags::text ILIKE $${paramIndex}`;
    params.push(`%${filters.tag}%`);
    paramIndex++;
  }

  // Whitelist sort columns
  const VALID_SORTS = ['name', 'created_at', 'user_rating', 'times_made'];
  const sortBy = VALID_SORTS.includes(filters.sortBy) ? filters.sortBy : 'name';
  sql += ` ORDER BY ${sortBy} ${filters.sortOrder === 'desc' ? 'DESC' : 'ASC'}`;

  return db.all(sql, params);
}

module.exports = { getAllRecipes, getRecipeById, createRecipe, ... };
```

### Key Model Conventions
- Always use parameterized queries (`$1`, `$2`)
- Whitelist sort/filter columns before inserting into SQL
- Parse JSON fields on read: `recipe.ingredients = JSON.parse(recipe.ingredients)`
- Stringify JSON fields on write: `JSON.stringify(ingredients)`
- Return plain objects, not database cursors
- Handle `RETURNING id` for inserts

## Route Pattern

Routes handle HTTP, validate input, call models, return JSON.

```javascript
// src/routes/recipes.js — typical route structure
const express = require('express');
const router = express.Router();
const Recipe = require('../models/recipe');

router.get('/', async (req, res, next) => {
  try {
    const { search, tag, minRating, sortBy, sortOrder, limit, offset } = req.query;
    const recipes = await Recipe.getAllRecipes({
      search, tag, minRating,
      sortBy, sortOrder,
      limit: parseInt(limit) || 500,
      offset: parseInt(offset) || 0
    });
    res.json(recipes);
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { name, ingredients, instructions, tags, ...rest } = req.body;
    if (!name) return res.status(400).json({ error: 'Name is required' });

    const recipe = await Recipe.createRecipe({
      name, ingredients, instructions, tags, ...rest
    });
    res.status(201).json(recipe);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
```

### Key Route Conventions
- Always wrap in try/catch with `next(err)`
- Validate required fields, return 400 for bad input
- Parse query params with defaults
- Use appropriate HTTP status codes (200, 201, 204, 400, 404, 500)
- Mount at `/api/<resource>` in app.js

## Service Pattern

Services handle external integrations and complex business logic.

```javascript
// src/services/sheets.js — external service pattern
class SheetsService {
  constructor() {
    this.auth = null;
    this.sheets = null;
  }

  async initialize() {
    // Load credentials, authenticate
  }

  async fetchInventory(sheetId, range) {
    // Call Google Sheets API
    // Parse response into normalized format
    // Return clean data objects
  }

  async syncToLocal(sheetData) {
    // Upsert into inventory_cache
    // Track sync status
  }
}

module.exports = new SheetsService();
```

## Error Handling Chain

Middleware in `src/middleware/errors.js` processes errors in order:

```javascript
// 1. Log all errors
function errorLogger(err, req, res, next) {
  console.error(`[${new Date().toISOString()}] ${err.message}`, {
    path: req.path, method: req.method, stack: err.stack
  });
  next(err);
}

// 2. Database-specific errors
function databaseErrorHandler(err, req, res, next) {
  if (err.code === '23505') {  // Unique violation
    return res.status(409).json({ error: 'Duplicate entry' });
  }
  if (err.code === '23503') {  // FK violation
    return res.status(400).json({ error: 'Referenced record not found' });
  }
  next(err);
}

// 3. Validation errors
function validationErrorHandler(err, req, res, next) { ... }

// 4. Fallback (500)
function fallbackErrorHandler(err, req, res, next) {
  res.status(500).json({ error: 'Internal server error' });
}
```

## Frontend View Pattern

Views render HTML strings and attach event listeners.

```javascript
// public/js/views.js — typical view
function renderRecipesView() {
  const container = document.getElementById('main-content');
  container.innerHTML = `
    <div class="search-bar">...</div>
    <div class="filter-chips">...</div>
    <div id="recipe-grid" class="grid">
      ${recipes.map(r => renderRecipeCard(r)).join('')}
    </div>
  `;

  // Attach event listeners after render
  container.querySelectorAll('.recipe-card').forEach(card => {
    card.addEventListener('click', () => showRecipeDetail(card.dataset.id));
  });
}

function renderRecipeCard(recipe) {
  const tags = JSON.parse(recipe.tags || '[]');
  return `
    <div class="recipe-card" data-id="${recipe.id}">
      <h3>${escapeHtml(recipe.name)}</h3>
      <div class="tags">${tags.map(t => `<span class="tag">${t}</span>`).join('')}</div>
      <div class="meta">
        ${recipe.one_pot ? '<span class="flag">One Pot</span>' : ''}
        ${recipe.user_rating ? `<span class="rating">${'★'.repeat(recipe.user_rating)}</span>` : ''}
      </div>
    </div>
  `;
}
```

### Key Frontend Conventions
- Render with template literals (innerHTML)
- Always escape user content with `escapeHtml()`
- Attach listeners after DOM insertion
- Use `data-*` attributes for element metadata
- API calls through `api.js` client, never raw fetch
- Show toast notifications for user feedback

## Adding a New Feature Checklist

1. **Database**: Add table/columns to `schema-postgres.sql`
2. **Model**: Create/extend model in `src/models/`
3. **Routes**: Add endpoints in `src/routes/`, mount in `app.js`
4. **Frontend view**: Add rendering in `views.js`
5. **API client**: Add methods in `public/js/api.js`
6. **Router**: Add hash route in `public/js/app.js`
7. **Tests**: Add E2E tests if applicable
8. **Docs**: Update `.claude/context/api-reference.md`
