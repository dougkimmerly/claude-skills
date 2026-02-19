# Frontend Architecture

Single-page application using vanilla JavaScript with hash-based routing. No framework dependencies.

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `public/index.html` | Entry point, PWA meta tags, app shell |
| `public/css/styles.css` | All styling, responsive, high-contrast |
| `public/js/app.js` | ~3,900 | Main logic, router, event handlers |
| `public/js/api.js` | ~660 | Fetch-based API client with error handling |
| `public/js/views.js` | ~3,300 | All view rendering functions |
| `public/manifest.json` | PWA manifest for installability |
| `public/sw.js` | Service worker (app shell caching) |

## Hash Router

```javascript
// Route definitions in app.js
window.addEventListener('hashchange', () => {
  const hash = window.location.hash;
  if (hash === '#/meals') renderMealsView();
  else if (hash === '#/inventory') renderInventoryView();
  else if (hash === '#/settings') renderSettingsView();
  else renderRecipesView();  // Default: #/
});
```

## Views

### Recipe List (`#/`)
- Search bar with real-time filtering
- Filter chips: tags, boat flags, rating
- Sort controls: name, rating, times made, newest
- Recipe cards in responsive grid
- Click → recipe detail modal
- FAB for add new recipe

### Recipe Detail (Modal)
- Full recipe display with ingredients, instructions
- Ingredient location badges (from inventory matching)
- Gather list grouped by storage location
- "I Made This" button with rating
- Edit/delete actions

### Meals (`#/meals`)
- **List view**: All meals with status filters
- **Calendar view**: Month grid + week strip
- **Meal sidebar**: Collapsible panel for building meals
  - Add recipes from search
  - Scale servings (1-12 diners)
  - Combined gather list
  - Save/edit/duplicate/delete
- **Shopping list**: Aggregate ingredients by date range

### Inventory (`#/inventory`)
- Items grouped by storage location
- Color-coded access difficulty
- Sync status indicator + manual sync button
- Search within inventory
- Category/location filters

### Settings (`#/settings`)
- Google Sheets configuration (sheet ID, range)
- Theme selection
- Default servings

## API Client (api.js)

```javascript
// All methods return parsed JSON or throw
const api = {
  async getRecipes(params) { ... },
  async getRecipe(id) { ... },
  async createRecipe(data) { ... },
  async updateRecipe(id, data) { ... },
  async deleteRecipe(id) { ... },
  async markMade(id, data) { ... },
  async matchRecipes(ingredients) { ... },
  // ... inventory, meals, sync methods
};
```

Error handling: catches fetch errors, shows toast notifications.

## UI Components

### Modal Overlay
Full-screen overlay for detail views and forms. Uses `data-modal` attribute pattern.

### Toast Notifications
Temporary messages for success/error feedback. Auto-dismiss after 3 seconds.

### Bottom Navigation
Persistent navigation bar with icons for Recipes, Meals, Inventory, Settings. Active state indicator.

### Meal Sidebar
Slide-in panel from right side. Contains meal builder with recipe search, scaling, and gather list.

## Styling Patterns

### Color System

| Purpose | Color | Hex |
|---------|-------|-----|
| Easy access (inventory) | Green | #4ade80 |
| Medium access | Amber | #f59e0b |
| Hard access / missing | Red | #ef4444 |
| Neutral / default | Slate | #64748b |
| Primary action | Blue | #3b82f6 |
| Background | Dark slate | #1e293b |
| Card surface | Slightly lighter | #334155 |
| Text primary | White | #f8fafc |
| Text secondary | Light gray | #94a3b8 |

### Design Principles
- **Mobile-first**: Touch-friendly targets (44px minimum)
- **High contrast**: Readable in bright sunlight and dim cabin lighting
- **Information density**: Show key data at a glance (boat flag icons, rating stars, times made)
- **Offline indicators**: Visual status for sync state
- **No external fonts in critical path**: Fonts loaded async, system fallback

### Typography
- **Headings**: Libre Baskerville (serif)
- **Body**: Source Sans 3 (sans-serif)
- **Monospace**: System monospace for technical data

### Responsive Breakpoints
- Mobile: < 640px (single column, full-width cards)
- Tablet: 640-1024px (2-column grid)
- Desktop: > 1024px (3-column grid, sidebar visible)

## PWA Configuration

### manifest.json
- Name: Galley Meal Planner
- Short name: Galley
- Start URL: /
- Display: standalone
- Theme color: #1e293b
- Background: #0f172a

### Service Worker (sw.js)
- App shell caching strategy
- Cache-first for static assets
- Network-first for API calls
- Offline fallback page
