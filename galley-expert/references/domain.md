# Domain Knowledge: Boat Galley Meal Planning

Context for understanding the problem domain and user needs.

## The User

A cruising sailor living aboard a sailboat. Meals are prepared in a small galley (boat kitchen) with limited:
- **Counter space**: Usually 2-3 square feet
- **Stove**: Often 2-burner propane, may have small oven
- **Refrigeration**: 12V fridge, limited freezer or none
- **Water**: Finite freshwater tank, conservation matters
- **Power**: Solar/wind/engine charging, limited AC power
- **Storage**: Distributed across lockers, bilge, lazarette
- **Provisioning**: May be weeks between grocery access

## Why This App Exists

1. **Inventory tracking**: Know what's on board across 10+ storage locations
2. **Recipe matching**: "What can I cook with what I have?"
3. **Substitution awareness**: No store nearby — what can replace missing ingredients?
4. **Meal planning**: Plan ahead when provisioning is possible
5. **Shopping lists**: Know exactly what to buy in port
6. **Offline-first**: Cell/WiFi connectivity is unreliable at sea or in remote anchorages

## Storage Locations

Boats have unconventional storage. The app tracks where food is physically stored:

| Location | Description | Access Difficulty |
|----------|-------------|-------------------|
| Act | Active/daily use galley area | Easy (green) |
| Foot | Foot locker near galley | Moderate (amber) |
| Loc1 | Storage locker 1 | Moderate (amber) |
| Loc2 | Storage locker 2 | Moderate (amber) |
| Loc3 | Storage locker 3 | Hard (amber) |
| Loc4 | Storage locker 4 | Hard (red) |
| Loc5 | Storage locker 5 | Hard (red) |
| Loc6 | Storage locker 6 | Hard (red) |
| Cellar | Deep storage/bilge | Very hard (red) |

**"Gather list"**: When preparing a recipe, the app shows which ingredients are in which locations, so the cook can make one trip to each locker rather than opening them repeatedly (often requires moving heavy items or disassembling berths).

## Boat-Specific Recipe Constraints

### One-Pot (one_pot)
Essential for boats with limited wash water and counter space. The recipe uses only one cooking vessel.

### No Oven (no_oven)
Many boats lack ovens or the oven is too small/impractical while underway. These recipes use stovetop only.

### Pressure Cooker (pressure_cooker)
Popular on boats: saves propane, cooks faster, works in rough seas with proper gimbal setup.

### Microwave (microwave)
Only available when connected to shore power or running a generator. Marks recipes that require one.

## Substitutions

Based on "The Boat Galley Cookbook" by Carolyn Shearlock — the definitive resource for boat cooking.

Common substitution categories:
- **Dairy**: Powdered milk, evaporated milk, coconut milk
- **Eggs**: Flax meal, banana, applesauce, commercial replacer
- **Fresh herbs**: Dried herbs (1/3 the amount)
- **Butter**: Oil, coconut oil, margarine
- **Cream**: Evaporated milk, coconut cream
- **Sour cream**: Yogurt, cream cheese thinned with milk
- **Bread crumbs**: Crushed crackers, oats, tortilla chips

Quality levels:
- **Exact**: Indistinguishable from original
- **Good**: Slightly different but works well
- **Passable**: Noticeable difference, still edible
- **Emergency**: Last resort, significantly different

## Google Sheets Integration

The inventory source-of-truth is a Google Sheet maintained by the boat owner. The sheet has columns for:
- Item name
- Quantity and unit
- Category (canned, dry, produce, protein, dairy, condiment, etc.)
- Storage location (Act, Foot, Loc1-6, Cellar)
- Expiry date

The app syncs from this sheet to enable offline access and recipe-inventory matching. The sheet is also used for provisioning planning (adding items to buy).

## Meal Types

| Type | Typical Timing |
|------|---------------|
| Breakfast | 0700-0900 |
| Lunch | 1200-1400 |
| Dinner | 1700-1900 |
| Snack | Anytime |

Passage meals (underway at sea) tend to be simpler — one-pot, no-oven, easy to eat with one hand.

## Recipe Sources

1. **The Boat Galley Cookbook** — Primary reference
2. **theboatgalley.com** — Website with 115+ crawled recipes
3. **Personal recipes** — Manually entered
4. **Scanned recipes** — Physical cookbook pages photographed and OCR'd via n8n/Claude Vision pipeline

## Key Metrics Tracked

- **Times made**: How often a recipe has been prepared
- **Last made**: When it was last cooked (avoid repetition)
- **User rating**: 1-5 stars personal preference
- **Weather/location**: Context for meal log (what worked in rough seas vs calm anchorage)
