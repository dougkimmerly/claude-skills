# Control4 Database Query System

**Last Updated:** 2026-01-12

## Overview

This system converts Control4 project.xml backup files into a queryable SQLite database, making it easy to search for devices, programming, TCP commands, and other project information.

## Benefits

- **Fast Queries**: Find any device, command, or programming in milliseconds
- **No File Size Issues**: Handles large 3.3MB+ XML files without problems
- **Structured Data**: All project data organized in relational tables
- **Easy Updates**: Rebuild the database from a new backup in seconds

## Components

### 1. c4_xml_to_db.py - XML to SQLite Parser

Converts a Control4 project.xml file to a SQLite database.

**Usage:**
```bash
cd ~/Programming/dkSRC/infrastructure/claude-skills/c4-expert/tools
python3 c4_xml_to_db.py <project.xml> [output.db]
```

**Example:**
```bash
python3 c4_xml_to_db.py /tmp/c4_extract/project.xml c4_project.db
```

**What it does:**
- Parses devices, events, programming, variables, and bindings
- Extracts TCP command details and parameters
- Creates indexed tables for fast searches
- Takes about 5-10 seconds to process a typical project

### 2. c4query - Query Tool

Command-line tool to search the database.

**Usage:**
```bash
cd ~/Programming/dkSRC/infrastructure/claude-skills/c4-expert/tools
./c4query [options]
```

## Common Queries

### Show Database Statistics
```bash
./c4query --stats
```

Displays:
- Total devices, events, code items, TCP commands
- Device type breakdown
- Devices with most programming events

### List All TCP Commands
```bash
./c4query --tcp-commands
```

Shows all TCP commands organized by type with their locations and targets.

### Find Specific TCP Command Type
```bash
./c4query --tcp-type snowStart
./c4query --tcp-type pumpStart
./c4query --tcp-type tempChange
```

### Find TCP Commands by Location
```bash
./c4query --tcp-location drivewayNorth
./c4query --tcp-location Master
```

### Show Device Details and Programming
```bash
./c4query --device 1108          # Generic TCP Device
./c4query --device 367           # Driveway North Heater
```

Shows:
- Device name, type, configuration
- All programming events
- Code items and commands
- TCP command details with JSON payloads

### Search Devices by Name
```bash
./c4query --device-name "Thermostat"
./c4query --device-name "Keypad"
./c4query --device-name "TCP"
```

### List All Devices
```bash
./c4query --list-devices
```

### Find Code Items by Command Name
```bash
./c4query --command-name "StartTimer"
./c4query --command-name "Send Generic TCP"
```

## Database Schema

### devices
- Device details: ID, name, type, configuration
- Links to events and programming

### events
- Programming events for each device
- Contains event ID and raw XML

### code_items
- Individual commands within events
- Hierarchical structure (parent/child)
- Links to target devices

### tcp_commands
- Parsed TCP command details
- Type, location, IP, port, encoding
- Full JSON command payload

### command_parameters
- All command parameters
- Name, value, type

### variables
- System variables

### bindings
- Device bindings

## Updating the Database

When you create a new Control4 backup:

1. **Export backup from Composer Pro**
   - File → Backup Project
   - Save as project_YYYYMMDD.c4p

2. **Extract the XML**
   ```bash
   mkdir -p /tmp/c4_extract
   cd /tmp/c4_extract
   unzip ~/path/to/project_20260112.c4p
   ```

3. **Rebuild the database**
   ```bash
   cd ~/Programming/dkSRC/infrastructure/claude-skills/c4-expert/tools
   python3 c4_xml_to_db.py /tmp/c4_extract/project.xml c4_project.db
   ```

The database file is created in the tools directory and c4query automatically uses it.

## Integration with c4-expert Skill

The c4-expert skill can now use these tools to:
- Answer questions about devices and programming
- Find where specific TCP commands are triggered
- Show programming context for any command
- Search for devices by name or function

## Example Workflows

### Find All Programming for a TCP Command Type

```bash
# 1. Find all snowStart commands
./c4query --tcp-type snowStart

# Output shows:
# - Location: drivewayNorth
# - Device Event: 367/2
# - JSON payload

# 2. Show full programming for that device
./c4query --device 367

# Output shows:
# - Event 1: Stop timer, send snowStop
# - Event 2: Start timer, send snowStart
```

### Find Where a Device is Used in Programming

```bash
# Search for device 1108 (Generic TCP Device)
./c4query --device 1108

# Shows all 19 events that use this device
# Each event shows the trigger and full command
```

### Recreate a TCP Command

```bash
# 1. Find the command
./c4query --tcp-type fullTempResponse

# 2. See all locations and parameter mappings
# Output shows exact JSON with PARAM{device,param} references

# 3. Look up what device 781 is
./c4query --device 781

# Output: Basement Thermostat
```

## Performance

- **Parse time**: 5-10 seconds for typical project (494 devices, 560 events)
- **Query time**: < 100ms for any query
- **Database size**: ~5-10MB (much smaller than 3.3MB XML due to compression)
- **Memory usage**: Minimal - uses streaming XML parser

## Troubleshooting

### Database file not found
```bash
# Make sure you've created the database first:
python3 c4_xml_to_db.py /tmp/c4_extract/project.xml c4_project.db

# Or specify the database location:
./c4query --db /path/to/database.db --stats
```

### Permission denied on c4query
```bash
chmod +x c4query
```

### lxml module not found
```bash
pip3 install lxml
```

## Advanced: Direct SQL Queries

You can also query the database directly with sqlite3:

```bash
cd ~/Programming/dkSRC/infrastructure/claude-skills/c4-expert/tools
sqlite3 c4_project.db

-- Find all TCP command types
SELECT DISTINCT command_type FROM tcp_commands ORDER BY command_type;

-- Count events per device
SELECT d.name, COUNT(e.event_id) as event_count
FROM devices d
LEFT JOIN events e ON d.id = e.device_id
GROUP BY d.id
ORDER BY event_count DESC;

-- Find all programming using a specific device
SELECT d1.name as trigger_device, c.display_text, d2.name as target_device
FROM code_items c
JOIN events e ON c.event_device_id = e.device_id AND c.event_id = e.event_id
JOIN devices d1 ON e.device_id = d1.id
LEFT JOIN devices d2 ON c.target_device = d2.id
WHERE c.target_device = 1108;
```

## Files

- `tools/c4_xml_to_db.py` - XML parser script
- `tools/c4query` - Query tool
- `tools/c4_project.db` - SQLite database (created by parser)
- `references/signalk-tcp-commands.md` - TCP command reference
- `references/c4-database-system.md` - This document

## Related Documentation

- [SignalK TCP Commands Reference](./signalk-tcp-commands.md)
- Control4 Composer Pro Documentation
- [lxml Documentation](https://lxml.de/)
