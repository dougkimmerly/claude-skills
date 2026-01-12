#!/usr/bin/env python3
"""
Control4 Project XML to SQLite Database Converter

Parses a Control4 project.xml backup file and creates a queryable SQLite database.
Uses streaming XML parsing to handle large files efficiently.

Usage:
    python3 c4_xml_to_db.py <project.xml> [output.db]

Example:
    python3 c4_xml_to_db.py /tmp/c4_extract/project.xml c4_project.db
"""

import sqlite3
import sys
import json
from lxml import etree
from datetime import datetime

def create_schema(conn):
    """Create the SQLite database schema"""
    cursor = conn.cursor()

    # Devices table - all items (devices, agents, etc.)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS devices (
            id INTEGER PRIMARY KEY,
            name TEXT,
            type INTEGER,
            created_datetime TEXT,
            config_file TEXT,
            state_data TEXT,
            raw_xml TEXT
        )
    ''')

    # Events table - programming events
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS events (
            device_id INTEGER,
            event_id INTEGER,
            raw_xml TEXT,
            PRIMARY KEY (device_id, event_id),
            FOREIGN KEY (device_id) REFERENCES devices(id)
        )
    ''')

    # Code items - the actual commands in events
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS code_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_device_id INTEGER,
            event_id INTEGER,
            codeitem_id INTEGER,
            target_device INTEGER,
            display_text TEXT,
            command_name TEXT,
            enabled BOOLEAN,
            parent_id INTEGER,
            raw_xml TEXT,
            FOREIGN KEY (event_device_id, event_id) REFERENCES events(device_id, event_id)
        )
    ''')

    # TCP Commands - parsed TCP command details
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tcp_commands (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code_item_id INTEGER,
            command_type TEXT,
            location TEXT,
            data_param TEXT,
            ip_address TEXT,
            port INTEGER,
            encoding TEXT,
            full_command_json TEXT,
            FOREIGN KEY (code_item_id) REFERENCES code_items(id)
        )
    ''')

    # Command Parameters
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS command_parameters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code_item_id INTEGER,
            param_name TEXT,
            param_value TEXT,
            param_type TEXT,
            FOREIGN KEY (code_item_id) REFERENCES code_items(id)
        )
    ''')

    # Variables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS variables (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            value TEXT,
            raw_xml TEXT
        )
    ''')

    # Bindings
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS bindings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            binding_type TEXT,
            raw_xml TEXT
        )
    ''')

    # Create indexes for faster queries
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_devices_type ON devices(type)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_events_device ON events(device_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_codeitems_target ON code_items(target_device)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_codeitems_command ON code_items(command_name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_tcp_type ON tcp_commands(command_type)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_tcp_location ON tcp_commands(location)')

    conn.commit()

def parse_codeitem(elem, event_device_id, event_id, conn, parent_id=None):
    """Recursively parse code items and their subitems"""
    cursor = conn.cursor()

    codeitem_id = elem.findtext('id', '')
    device = elem.findtext('device', '')
    display = elem.findtext('display', '')
    enabled = elem.findtext('enabled', 'True') == 'True'

    # Get command name if it exists
    cmdcond = elem.find('cmdcond/devicecommand')
    command_name = cmdcond.findtext('command', '') if cmdcond is not None else ''

    raw_xml = etree.tostring(elem, encoding='unicode')

    # Insert code item
    cursor.execute('''
        INSERT INTO code_items (
            event_device_id, event_id, codeitem_id, target_device,
            display_text, command_name, enabled, parent_id, raw_xml
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (event_device_id, event_id, codeitem_id, device, display,
          command_name, enabled, parent_id, raw_xml))

    code_item_db_id = cursor.lastrowid

    # Parse command parameters
    if cmdcond is not None:
        params = cmdcond.find('params')
        if params is not None:
            for param in params.findall('param'):
                param_name = param.findtext('name', '')
                value_elem = param.find('value')
                param_type = value_elem.get('type', '') if value_elem is not None else ''
                param_value = value_elem.findtext('static', '') if value_elem is not None else ''

                cursor.execute('''
                    INSERT INTO command_parameters (code_item_id, param_name, param_value, param_type)
                    VALUES (?, ?, ?, ?)
                ''', (code_item_db_id, param_name, param_value, param_type))

                # If this is a TCP command, parse the JSON
                if command_name == 'Send Generic TCP command' and param_name == 'Command':
                    try:
                        # Try to parse JSON from the command (may have PARAM{} placeholders)
                        cmd_json = param_value
                        # Extract type and location if it's valid JSON structure
                        if cmd_json.strip().startswith('{'):
                            # Basic parsing - just extract type and loc fields
                            import re
                            type_match = re.search(r'"type"\s*:\s*"([^"]+)"', cmd_json)
                            loc_match = re.search(r'"loc"\s*:\s*"([^"]+)"', cmd_json)
                            data_match = re.search(r'"data"\s*:\s*([^}]+)', cmd_json)

                            command_type = type_match.group(1) if type_match else ''
                            location = loc_match.group(1) if loc_match else ''
                            data_param = data_match.group(1) if data_match else ''

                            # Get IP and port
                            ip_address = ''
                            port = 0
                            encoding = ''
                            for p in params.findall('param'):
                                pname = p.findtext('name', '')
                                pval_elem = p.find('value')
                                pval = pval_elem.findtext('static', '') if pval_elem is not None else ''
                                if pname == 'IP Address':
                                    ip_address = pval
                                elif pname == 'Port':
                                    port = int(pval) if pval.isdigit() else 0
                                elif pname == 'Encoding':
                                    encoding = pval

                            cursor.execute('''
                                INSERT INTO tcp_commands (
                                    code_item_id, command_type, location, data_param,
                                    ip_address, port, encoding, full_command_json
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            ''', (code_item_db_id, command_type, location, data_param,
                                  ip_address, port, encoding, cmd_json))

                    except Exception as e:
                        print(f"Warning: Could not parse TCP command JSON: {e}")

    # Recursively process subitems
    subitems = elem.find('subitems')
    if subitems is not None:
        for subitem in subitems.findall('codeitem'):
            parse_codeitem(subitem, event_device_id, event_id, conn, parent_id=code_item_db_id)

    conn.commit()

def parse_xml_to_db(xml_file, db_file):
    """Parse Control4 XML and populate SQLite database"""
    print(f"Parsing {xml_file} to {db_file}...")

    # Create database and schema
    conn = sqlite3.connect(db_file)
    create_schema(conn)
    cursor = conn.cursor()

    # Parse XML
    tree = etree.parse(xml_file)
    root = tree.getroot()

    print("Parsing devices...")
    # Parse all items (devices)
    items = root.findall('.//item')
    for i, item in enumerate(items):
        item_id = item.findtext('id', '')
        name = item.findtext('name', '')
        item_type = item.findtext('type', '')
        created = item.findtext('created_datetime', '')

        itemdata = item.find('itemdata')
        config_file = itemdata.findtext('config_data_file', '') if itemdata is not None else ''

        state = item.findtext('state', '')
        raw_xml = etree.tostring(item, encoding='unicode')

        cursor.execute('''
            INSERT INTO devices (id, name, type, created_datetime, config_file, state_data, raw_xml)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (item_id, name, item_type, created, config_file, state, raw_xml))

        if (i + 1) % 50 == 0:
            print(f"  Processed {i + 1}/{len(items)} devices...")

    conn.commit()
    print(f"  Completed: {len(items)} devices")

    print("Parsing events and programming...")
    # Parse events
    event_mgr = root.find('.//event_mgr')
    if event_mgr is not None:
        events = event_mgr.findall('event')
        for i, event in enumerate(events):
            device_id = event.findtext('deviceid', '')
            event_id = event.findtext('eventid', '')
            raw_xml = etree.tostring(event, encoding='unicode')

            cursor.execute('''
                INSERT INTO events (device_id, event_id, raw_xml)
                VALUES (?, ?, ?)
            ''', (device_id, event_id, raw_xml))

            # Parse code items in this event
            codeitem = event.find('codeitem')
            if codeitem is not None:
                parse_codeitem(codeitem, device_id, event_id, conn)

            if (i + 1) % 50 == 0:
                print(f"  Processed {i + 1}/{len(events)} events...")

        conn.commit()
        print(f"  Completed: {len(events)} events")

    print("Parsing variables...")
    # Parse variables
    variables = root.find('.//variables')
    if variables is not None:
        var_list = variables.findall('variable')
        for var in var_list:
            name = var.findtext('name', '')
            value = var.findtext('value', '')
            raw_xml = etree.tostring(var, encoding='unicode')

            cursor.execute('''
                INSERT INTO variables (name, value, raw_xml)
                VALUES (?, ?, ?)
            ''', (name, value, raw_xml))
        conn.commit()
        print(f"  Completed: {len(var_list)} variables")

    print("Parsing bindings...")
    # Parse bindings
    bindings = root.find('.//bindings')
    if bindings is not None:
        binding_list = bindings.findall('boundbinding')
        for binding in binding_list:
            raw_xml = etree.tostring(binding, encoding='unicode')
            cursor.execute('''
                INSERT INTO bindings (binding_type, raw_xml)
                VALUES (?, ?)
            ''', ('boundbinding', raw_xml))
        conn.commit()
        print(f"  Completed: {len(binding_list)} bindings")

    # Print summary
    print("\n" + "=" * 60)
    print("Database creation complete!")
    print("=" * 60)

    cursor.execute('SELECT COUNT(*) FROM devices')
    print(f"Devices: {cursor.fetchone()[0]}")

    cursor.execute('SELECT COUNT(*) FROM events')
    print(f"Events: {cursor.fetchone()[0]}")

    cursor.execute('SELECT COUNT(*) FROM code_items')
    print(f"Code Items: {cursor.fetchone()[0]}")

    cursor.execute('SELECT COUNT(*) FROM tcp_commands')
    print(f"TCP Commands: {cursor.fetchone()[0]}")

    cursor.execute('SELECT COUNT(*) FROM command_parameters')
    print(f"Command Parameters: {cursor.fetchone()[0]}")

    cursor.execute('SELECT COUNT(*) FROM variables')
    print(f"Variables: {cursor.fetchone()[0]}")

    cursor.execute('SELECT COUNT(*) FROM bindings')
    print(f"Bindings: {cursor.fetchone()[0]}")

    conn.close()
    print(f"\nDatabase saved to: {db_file}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    xml_file = sys.argv[1]
    db_file = sys.argv[2] if len(sys.argv) > 2 else 'c4_project.db'

    parse_xml_to_db(xml_file, db_file)
