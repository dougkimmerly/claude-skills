# SKipper Layouts Reference

## Layout Hierarchy

```
Page
└── Layout (Grid, Stack, or Group)
    └── Controls or nested Layouts
```

Layouts can be nested to create complex arrangements.

---

## Grid Layout

Structured rows and columns with proportional sizing.

### Properties

- **Rows**: Number and relative size of each row
- **Columns**: Number and relative size of each column
- **Auto rotate**: Adaptive layout for orientation changes

### Size Proportions

Sizes are relative, not absolute. Examples:

```
Columns: 1, 2, 1 (total = 4)
- Column 1: 25% width (1/4)
- Column 2: 50% width (2/4)  
- Column 3: 25% width (1/4)

Rows: 1, 1, 2 (total = 4)
- Row 1: 25% height
- Row 2: 25% height
- Row 3: 50% height
```

### Common Grid Patterns

**2x2 Equal:**
```
Rows: 1, 1
Columns: 1, 1
```

**Header + Content:**
```
Rows: 1, 3
Columns: 1
```

**Sidebar + Main:**
```
Rows: 1
Columns: 1, 3
```

**Dashboard:**
```
Rows: 1, 2, 1
Columns: 1, 2, 1
```

### Nesting Grids

Each cell in a Grid can contain another Grid, Stack, or Group.

```
Main Grid (2x2)
├── Cell [0,0]: 3x1 Grid (for header items)
├── Cell [0,1]: Compass Control
├── Cell [1,0]: Stack (for scrolling list)
└── Cell [1,1]: Wind Gauge Control
```

---

## Stack Layout

Scrollable list of controls (vertical or horizontal).

### Properties

- **Orientation**: Vertical (default) or Horizontal
- **Scrollbar**: Appears automatically when content exceeds space

### Use Cases

- Long lists of values that won't fit on screen
- Multiple similar items (e.g., all battery banks)
- Variable-length content

### Stack Behavior

- Controls stack in order added
- Each control takes minimum needed height/width
- Scrollbar appears if content overflows
- Good for TitleValue or HorizontalBar controls

---

## Group Layout

**Important:** Groups can ONLY be placed inside a Stack.

A titled container with grid-like arrangement.

### Properties

- **Title**: Displayed at top of group
- **Icon**: Optional icon next to title
- **Columns**: Number of columns in the group
- **Font Size**: Title font size

### Behavior

- Controls wrap to next row when column count exceeded
- Controls auto-size to fill available width
- If group doesn't fit vertically, Stack provides scrollbar

### Example

```
Stack
├── Group: "House Batteries" (3 columns)
│   ├── TitleValue: Voltage
│   ├── TitleValue: Current
│   ├── TitleValue: SOC
│   └── TitleValue: Temperature (wraps to row 2)
└── Group: "Engine" (2 columns)
    ├── TitleValue: RPM
    └── TitleValue: Temp
```

---

## Layout Tips

### For Different Devices

**Phone (Portrait):**
- Use 1-2 column grids
- Rely on Stacks for scrolling
- Limit to 4-6 controls visible at once

**Tablet:**
- 2-3 column grids work well
- Can show 8-12 controls
- Consider landscape vs portrait

**Desktop/Large Display:**
- Complex multi-column grids
- Can show 16+ controls
- Use nested grids for organization

### Page Visibility

SKipper allows setting page visibility per device type:
- Mobile only
- Tablet only  
- Desktop only
- All devices

Create different pages optimized for each device.

### Design Process

1. Sketch layout on paper first
2. Identify square vs rectangular controls needed
3. Plan grid proportions to accommodate control shapes
4. Use Stacks when content length varies
5. Use Groups to organize related data

---

## Layout Control Icons

In edit mode:
- **Light green icon** = Layout control (Grid, Stack, Group)
- Click to edit layout properties
- Located in upper-left of layout area
- Multiple layouts show icons offset to avoid overlap
