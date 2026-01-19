# Logbook Integration & Extension

## External Application Integration

### Node-RED Flows

**Read Today's Log:**
```
[inject] → [function: set date] → [http request GET] → [debug]
```

Function node:
```javascript
const today = new Date().toISOString().split('T')[0];
msg.url = `http://localhost/plugins/signalk-logbook/logs/${today}`;
return msg;
```

**Create Entry on Event:**
```
[signalk-subscribe] → [function: format entry] → [http request POST]
```

Function node:
```javascript
msg.payload = {
  text: `Alert: ${msg.payload.path} = ${msg.payload.value}`,
  category: 'navigation',
  ago: 0
};
msg.headers = { 'Content-Type': 'application/json' };
msg.url = 'http://localhost/plugins/signalk-logbook/logs';
return msg;
```

**Daily Summary Email:**
```
[cron: 18:00] → [http request GET] → [function: summarize] → [email]
```

### Shell Scripts

**Backup Logs to Git:**
```bash
#!/bin/bash
LOG_DIR=~/.signalk/plugin-config-data/signalk-logbook
BACKUP_REPO=~/logbook-backup

cd $LOG_DIR
cp *.yml $BACKUP_REPO/
cd $BACKUP_REPO
git add .
git commit -m "Logbook backup $(date +%Y-%m-%d)"
git push
```

**Export to CSV:**
```bash
#!/bin/bash
# Requires yq (YAML processor)
DATE=$1
FILE=~/.signalk/plugin-config-data/signalk-logbook/${DATE}.yml

echo "datetime,text,category,author,lat,lon,sog"
yq -r '.[] | [.datetime, .text, .category, .author, .position.latitude, .position.longitude, .speed.sog] | @csv' $FILE
```

### Python Integration

```python
import requests
import yaml
from datetime import date

BASE_URL = "http://192.168.22.16/plugins/signalk-logbook"

def get_entries(log_date=None):
    """Fetch entries for a date (default: today)"""
    if log_date is None:
        log_date = date.today().isoformat()
    response = requests.get(f"{BASE_URL}/logs/{log_date}")
    return response.json()

def create_entry(text, category="navigation", ago=0):
    """Create a new log entry"""
    payload = {
        "text": text,
        "category": category,
        "ago": ago
    }
    response = requests.post(
        f"{BASE_URL}/logs",
        json=payload,
        headers={"Content-Type": "application/json"}
    )
    return response.json()

# Example usage
entries = get_entries()
for entry in entries:
    print(f"{entry['datetime']}: {entry.get('text', 'No text')}")
```

## Backup Strategies

### DSIInav → CentralSK Backup (Active)

**Current Setup on DSIInav (192.168.22.16):**

| Item | Value |
|------|-------|
| Script | `/home/doug/.signalk/backup-logbook.sh` |
| Cron | Hourly (`0 * * * *`) |
| Source | `/home/doug/.signalk/plugin-config-data/signalk-logbook/*.yml` |
| Destination | `doug@192.168.20.19:/home/doug/backups/signalk-logbook/` |
| Behavior | Syncs only when 192.168.20.19 is reachable |

**Script:**
```bash
#!/bin/bash
# Backup logbook YAML files to 192.168.20.19
# Runs via cron - only syncs when .19 is reachable

LOGBOOK_DIR="/home/doug/.signalk/plugin-config-data/signalk-logbook"
BACKUP_HOST="192.168.20.19"
BACKUP_USER="doug"
BACKUP_DIR="/home/doug/backups/signalk-logbook"

# Check if backup host is reachable
if ! ping -c 1 -W 2 $BACKUP_HOST > /dev/null 2>&1; then
    exit 0  # Silent exit if not reachable
fi

# Ensure backup directory exists on remote
ssh -o ConnectTimeout=5 -o BatchMode=yes $BACKUP_USER@$BACKUP_HOST "mkdir -p $BACKUP_DIR" 2>/dev/null || exit 0

# Sync YAML files (only newer/missing)
rsync -az --ignore-existing $LOGBOOK_DIR/*.yml $BACKUP_USER@$BACKUP_HOST:$BACKUP_DIR/ 2>/dev/null
```

**Notes:**
- Uses `--ignore-existing` so historical logs are never overwritten
- Silent failure when backup host unreachable (different network segment)
- SSH key auth required between hosts (BatchMode=yes)

### Git-based Backup

The YAML format is ideal for version control:

```bash
# Initialize backup repo
cd ~/.signalk/plugin-config-data/signalk-logbook
git init
git add *.yml
git commit -m "Initial logbook backup"
git remote add origin git@github.com:user/logbook-backup.git
git push -u origin main
```

**Cron job for daily backup:**
```cron
0 23 * * * cd ~/.signalk/plugin-config-data/signalk-logbook && git add . && git commit -m "Auto backup $(date +\%Y-\%m-\%d)" && git push
```

### Cloud Sync

**Syncthing:** Add logbook directory to Syncthing for real-time sync across devices.

**Rclone to S3:**
```bash
rclone sync ~/.signalk/plugin-config-data/signalk-logbook s3:my-bucket/logbook/
```

## Custom Trigger Development

### Adding a New Trigger

Edit `plugin/triggers.js`:

```javascript
// Example: Log when anchor alarm triggers
function setupAnchorAlarmTrigger(app, log) {
  let alarmActive = false;

  app.subscriptionmanager.subscribe(
    {
      context: 'vessels.self',
      subscribe: [{
        path: 'notifications.navigation.anchor'
      }]
    },
    unsubscribes,
    (err) => { if (err) app.error(err); },
    (delta) => {
      const notification = delta.updates[0].values[0].value;
      const isAlarm = notification?.state === 'alarm';

      if (isAlarm && !alarmActive) {
        alarmActive = true;
        log.appendEntry(todayDate(), {
          datetime: new Date().toISOString(),
          text: `Anchor alarm triggered: ${notification.message}`,
          category: 'navigation',
          author: 'auto'
        });
      } else if (!isAlarm && alarmActive) {
        alarmActive = false;
        log.appendEntry(todayDate(), {
          datetime: new Date().toISOString(),
          text: 'Anchor alarm cleared',
          category: 'navigation',
          author: 'auto'
        });
      }
    }
  );
}
```

### Custom Entry Categories

To add categories beyond navigation/engine/radio/maintenance:

1. Update `schema/openapi.yaml`:
```yaml
EntryCategory:
  type: string
  enum:
    - navigation
    - engine
    - radio
    - maintenance
    - weather      # New
    - safety       # New
```

2. Update `src/components/EntryEditor.jsx`:
```jsx
<option value="weather">Weather</option>
<option value="safety">Safety</option>
```

3. Update `src/components/EntryDetails.jsx` for display styling.

## Extending the Webapp

### Adding a New Tab

1. Create component `src/components/MyTab.jsx`
2. Import in `AppPanel.jsx`
3. Add to tabs array:
```jsx
const tabs = [
  { id: 'timeline', label: 'Timeline', component: Timeline },
  { id: 'logbook', label: 'Logbook', component: Logbook },
  { id: 'map', label: 'Map', component: MapView },
  { id: 'mytab', label: 'My Tab', component: MyTab }  // New
];
```

### Custom Visualizations

**Chart.js Integration:**
```jsx
import { Line } from 'react-chartjs-2';

function SpeedChart({ entries }) {
  const data = {
    labels: entries.map(e => formatTime(e.datetime)),
    datasets: [{
      label: 'SOG (knots)',
      data: entries.map(e => e.speed?.sog || 0)
    }]
  };

  return <Line data={data} />;
}
```

### Adding Entry Fields

1. Update schema in `schema/openapi.yaml`
2. Add field to `EntryEditor.jsx` form
3. Add display to `EntryDetails.jsx`
4. Update `format.js` if unit conversion needed

## Related Plugin Integration

### signalk-autostate

Required for trip detection. Ensure it's installed and configured:
- Sets `navigation.state` based on speed/anchor/mooring
- Triggers trip start/end events

### sailsconfiguration

For sail tracking integration:
- Populates `sails.inventory.*`
- Enables reef/furl tracking in logbook

### signalk-autopilot

For autopilot state logging:
- Provides `steering.autopilot.mode`
- Enables autopilot change triggers

## Performance Considerations

- **Entry frequency:** Avoid more than 1 entry/minute
- **File size:** Daily files typically <100KB
- **Query performance:** Reading full day is fast; multi-day queries scale linearly
- **Buffer memory:** 15-minute buffer uses ~1MB RAM

## Troubleshooting

**Entries not appearing:**
1. Check plugin is enabled in SignalK admin
2. Verify file permissions on log directory
3. Check SignalK logs: `journalctl -u signalk | grep logbook`

**Automatic entries not triggering:**
1. Verify signalk-autostate is installed and running
2. Check `navigation.state` is being set
3. Review triggers.js conditions

**Webapp not loading:**
1. Clear browser cache
2. Check for JavaScript errors in console
3. Verify authentication token is valid
