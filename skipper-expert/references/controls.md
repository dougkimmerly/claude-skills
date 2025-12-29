# SKipper Controls Reference

## Content Controls

### TitleValue

Displays numeric value with optional title, units, and min/max statistics.

**Properties:**
- Title: Text label
- Value: Bound to SignalK path
- Units: Display units (auto-converted from SI)
- Appearance: Default, Compact, OneLine, WithStatistics
- Font sizes: Auto or manual
- Colors: Foreground, background

**Use for:** Speed, depth, temperature, voltage, any single numeric value.

### Label

Text display for static or dynamic content.

**Properties:**
- Text: Static or bound to SignalK path
- Font size, weight, color
- Word wrap enable/disable
- Horizontal/vertical alignment

**Converters commonly used:**
- Position to WGS-84 string
- Datetime to string
- JSON template

### HorizontalBar

**Properties:**
- Icon (optional)
- Title (optional, can hide)
- Value: Bound SignalK path
- Units (optional)
- Min/Max: Define range
- Stroke color: Can bind to zones
- Style: Default or Filled

**Use for:** Battery voltage, signal strength, any bounded value.

### VerticalBar

Same as HorizontalBar but vertical orientation.

**Use for:** Tank levels, vertical progress indicators.

### Compass

Classic compass display.

**Properties:**
- Course: Bound to heading path
- Title (optional)
- Shows magnetic or true heading

**Typical binding:** `navigation.headingMagnetic` or `navigation.headingTrue`

### Modern Compass

Advanced compass with multiple data points.

**Displays:**
- Course Over Ground
- Heading
- Wind Speed and Direction
- Next Waypoint Heading

**Use for:** Navigation displays requiring multiple directional data.

### Wind Gauge

Combined wind display.

**Shows:**
- True and apparent wind direction
- Heading
- COG
- Next waypoint
- Up to 5 customizable data boxes

### Analog Gauge

Classic needle gauge.

**Properties:**
- Title, units
- Min/max values
- Needle color
- Zone colors for arc segments

**Use for:** RPM, pressure, classic instrument look.

### Digital Gauge

Modern arc-style gauge.

**Properties:**
- Title, units, value
- Min/max points on arc
- Arc color tied to zones

### Liquid Gauge

Animated tank display.

**Properties:**
- Icon, title
- Min/max values
- Shape: Rectangular or Circular
- SignalK path binding

**Use for:** Fuel, water, holding tank levels.

### Graph (History)

Time-series chart.

**Data sources:**
- Direct from SignalK (recent data)
- InfluxDB v1 or v2 (historical data)

**Properties:**
- Up to 1024 data points
- Show/hide: statistics, labels, header, tooltips
- Zone lines displayed
- Min/Max/Avg lines

**Use for:** Temperature trends, voltage history, any data needing trend analysis.

### Vector Image

Programmable SVG graphics (v1.25+).

**Features:**
- Load custom SVG images
- Control visibility, color, rotation via Instructions
- Multiple images in single control

**Use for:** Custom boat diagrams, switch panels, animated indicators.

---

## Action Controls

### Button

**Click Actions:**

1. **Signal K PUT request**
   - Path: Any SignalK path
   - Value: true, false, number, string, toggle, or increment

2. **Navigate to Page**
   - Jump to any SKipper page

3. **OS Command** (Linux/Mac/Windows only)
   - Execute system command

4. **Open URL**
   - Open web page in browser

5. **Autopilot Control**
   - Actions: Engage, disengage, tack, adjust heading, set mode
   - Uses SignalK Autopilot API v2

6. **Anchor Alarm Control**
   - Lower anchor
   - Raise anchor  
   - Set radius

7. **SKipper Actions**
   - Toggle theme
   - Go to Home/Settings
   - Toggle icon bar
   - Load/Save UI
   - Run quick action

**Properties:**
- Icon
- Text
- Colors
- Font size
- Confirmation dialog (recommended for destructive actions)

### Toggle Button

For boolean paths (true/false/0/1/yes/no).

**Styles:**
- Default: Icon changes based on state
- Switch: Wall switch appearance
- Toggle with Text: Icon + text + toggle indicator

**Use for:** Lights, pumps, any on/off control.

---

## Control Sizing

Controls adapt to available space. Consider:

- **Square controls** (Compass, Gauges): Need roughly square space
- **Rectangular controls** (Bars, TitleValue): Flexible width/height
- **Phone screens**: Limit to 4-6 controls per page
- **Tablets**: 8-12 controls comfortable
- **Desktop**: Can handle 16+ controls

---

## Data Binding

Every data field has a "chain link" icon for binding.

**Binding process:**
1. Click chain icon
2. Click "Select Signal K binding"
3. Search/browse for path
4. Optionally set Converter
5. Optionally set Offset/Multiply

**Auto-suggestions:**
- SKipper suggests title and units based on SignalK metadata
- Units auto-convert from SI to metric/imperial based on settings
