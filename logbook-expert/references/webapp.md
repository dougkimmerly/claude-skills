# Logbook Webapp Components

The webapp is built with React and Reactstrap, bundled with Webpack Module Federation for embedding in SignalK dashboards.

## Component Hierarchy

```
AppPanel.jsx (main container)
├── Metadata.jsx (right panel)
│   ├── CrewEditor.jsx (modal)
│   ├── SailEditor.jsx (modal)
│   └── FilterEditor.jsx (modal)
├── Timeline.jsx (tab)
│   └── EntryDetails.jsx
├── Logbook.jsx (tab)
│   └── EntryDetails.jsx
├── Map.jsx (tab)
├── EntryEditor.jsx (modal)
└── EntryViewer.jsx (modal)
    └── EntryDetails.jsx
```

## AppPanel.jsx - Main Container

**State:**
```javascript
{
  entries: [],           // All log entries
  activeTab: 'timeline', // timeline | logbook | map
  daysToShow: 7,         // Filter range
  timezone: 'UTC',       // Display timezone
  authenticated: false,  // Login state
  crewNames: [],         // Known crew
  sails: {}              // Sail inventory
}
```

**Data Fetching:**
```javascript
// Fetch logs every 5 minutes
useEffect(() => {
  fetchLogs();
  const interval = setInterval(fetchLogs, 300000);
  return () => clearInterval(interval);
}, [daysToShow]);

async function fetchLogs() {
  const response = await fetch('/plugins/signalk-logbook/logs');
  const { dates } = await response.json();
  // Fetch entries for each date within daysToShow
}
```

**Entry Operations:**
```javascript
saveEntry(entry)     // PUT - update existing
saveAddEntry(entry)  // POST - create new
deleteEntry(entry)   // DELETE - remove
```

## Timeline.jsx - Card View

Displays entries in reverse chronological order (newest first).

**Features:**
- Reactstrap Card components
- Color-coded by category
- Click to edit
- Grouped by date headers

```jsx
{entries.map(entry => (
  <Card key={entry.datetime} onClick={() => editEntry(entry)}>
    <CardHeader>
      <Badge color={categoryColor(entry.category)}>
        {entry.category}
      </Badge>
      <span>{formatTime(entry.datetime)}</span>
      <span>{entry.author}</span>
    </CardHeader>
    <CardBody>
      <EntryDetails entry={entry} />
    </CardBody>
  </Card>
))}
```

## Logbook.jsx - Table View

Sortable table with all entry fields.

**Columns:**
- Time
- Course (COG)
- Speed (SOG)
- Weather (wind speed/direction)
- Barometer
- Position (lat/lon)
- Fix type (GPS source)
- Log (distance)
- Engine hours
- Author
- Remarks (text)

**Features:**
- Sortable columns
- Click row to edit
- Add entry button

## Map.jsx - Geographic View

Uses Pigeon Maps for rendering.

**Features:**
- Vessel track as polyline
- Entry markers (color-coded by category)
- Auto-fit bounds to entries
- Click marker to view/edit entry

```jsx
import { Map, Marker, Overlay } from 'pigeon-maps';

// Filter entries with position data
const mappableEntries = entries.filter(e => e.position);

// Calculate bounds
const bounds = calculateBounds(mappableEntries);

<Map center={bounds.center} zoom={bounds.zoom}>
  {/* Track line */}
  <Overlay>
    <svg><polyline points={trackPoints} /></svg>
  </Overlay>

  {/* Entry markers */}
  {mappableEntries.map(entry => (
    <Marker
      key={entry.datetime}
      anchor={[entry.position.latitude, entry.position.longitude]}
      color={categoryColor(entry.category)}
      onClick={() => viewEntry(entry)}
    />
  ))}
</Map>
```

**Marker Colors:**
- Blue: Navigation entries
- Red: Engine entries
- Teal: Radio entries
- Gray: Maintenance

## EntryEditor.jsx - Create/Edit Modal

**Form Fields:**
```jsx
<Form>
  <FormGroup>
    <Label>Remarks</Label>
    <Input type="textarea" value={text} />
  </FormGroup>

  <FormGroup>
    <Label>Category</Label>
    <Input type="select" value={category}>
      <option value="navigation">Navigation</option>
      <option value="engine">Engine</option>
      <option value="radio">Radio</option>
      <option value="maintenance">Maintenance</option>
    </Input>
  </FormGroup>

  {/* Conditional fields based on category */}
  {category === 'radio' && (
    <FormGroup>
      <Label>VHF Channel</Label>
      <Input type="number" value={vhf} />
    </FormGroup>
  )}

  {/* Observations accordion */}
  <Accordion>
    <AccordionItem title="Observations">
      <SeaStateSelector value={seaState} />
      <CloudCoverageSelector value={cloudCoverage} />
      <VisibilitySelector value={visibility} />
    </AccordionItem>
  </Accordion>
</Form>
```

## EntryDetails.jsx - Formatted Display

Renders entry data in human-readable format.

**Displayed Fields:**
- Text with category badge
- Position (formatted lat/lon + source)
- Speed (SOG in knots)
- Course/Heading (degrees)
- Wind (speed + direction)
- Sea state (WMO description)
- Cloud coverage (oktas with symbol)
- Visibility (fog scale description)
- Engine hours (if engine category)
- VHF channel (if radio category)

## Metadata.jsx - Config Panel

Right-side panel showing:
- Crew roster with edit button
- Active sails with reef/furl status
- Date range filter

**WebSocket Subscriptions:**
```javascript
// Real-time crew updates
subscribeToPath('communication.crewNames', (names) => {
  setCrewNames(names);
});

// Sail configuration changes
subscribeToPath('sails.inventory.*', (sails) => {
  setSails(sails);
});
```

## SailEditor.jsx - Sail Configuration

Modal for managing active sails.

**Features:**
- Sail cards (3 per row)
- Active/inactive toggle
- Reef selection (discrete reefs)
- Furl slider (continuous reefing)
- Display sail specs (area, material, wind range)

## CrewEditor.jsx - Crew Roster

**Features:**
- List of crew with remove button
- Add crew input field
- Saves to SignalK `communication.crewNames`

## FilterEditor.jsx - Date Range

Simple modal with days-to-show selector.

## Webpack Module Federation

The webapp is exposed as a federated module:

```javascript
// webpack.config.js
new ModuleFederationPlugin({
  name: 'signalkLogbook',
  filename: 'remoteEntry.js',
  exposes: {
    './AppPanel': './src/components/AppPanel.jsx'
  },
  shared: ['react', 'react-dom']
})
```

This allows embedding in other SignalK dashboards:
```javascript
// In another app
const LogbookPanel = React.lazy(() =>
  import('signalkLogbook/AppPanel')
);
```

## Styling

Uses Reactstrap (Bootstrap) classes. Custom CSS minimal.

Key classes:
- `.logbook-table` - Main table styling
- `.entry-card` - Timeline card styling
- `.category-badge` - Color-coded badges

## Extension Points

1. **Add new tabs:** Modify AppPanel.jsx tabs array
2. **Custom entry fields:** Extend EntryEditor.jsx form
3. **New visualizations:** Add component, wire to AppPanel
4. **Custom markers:** Modify Map.jsx marker rendering
5. **Additional metadata:** Extend Metadata.jsx subscriptions
