# Control4 Integrations

## Home Assistant Integration

### Native HA Component (OS 3.0+)

Built into Home Assistant since 0.114:

**Supported:**
- Lights (on/off/dimming)
- Room Media (source, volume)
- Climate devices

**Requirements:**
- Controller on OS 3.0+
- Same local network (no 4Sight support)
- Static IP or DHCP reservation for controller
- customer.control4.com credentials

**Setup:**
1. Settings → Devices & Services → Add Integration
2. Search "Control4"
3. Enter controller IP
4. Enter my.control4.com credentials
5. Configure scan interval (avoid <10 seconds)

**Configuration Options:**
- Scan interval: How often HA polls C4 (balance responsiveness vs controller load)

### Chowmain Home Assistant Driver

Commercial driver ($) for Control4:
- Auto-discovery of HA entities
- Binary sensors support
- Push notifications from HA to C4
- Custom command calls
- Bidirectional control

**Features:**
- One-click setup from C4 side
- No HA configuration required
- Works with all HA integrations (2700+)

## MQTT Integration (Berto Drivers)

Free community drivers: https://github.com/scruzals/Berto

### Berto_MQTTBridge

Connects C4 to MQTT broker:
- Send/receive IoT messages
- Works with: Sonoff, Tasmota, HomeKit Bridge
- No internet required

### Berto_HomeAssistant

Direct HA integration via MQTT:
- Alternative to native component
- Works on older C4 OS versions

### Other Berto Drivers

| Driver | Purpose |
|--------|----------|
| Berto_LifxBridge | Local LIFX control |
| Berto_SkyQ | Sky Q box control |
| Berto_Kodi | Kodi media player |
| Berto_Mail | SMTP email notifications |

## Third-Party Driver Sources

### DriverCentral

https://drivercentral.io

- Largest driver marketplace
- Quality tested
- License management
- Free trials available

**Popular Drivers:**
- Enhanced Scheduler (user-editable schedules)
- Enhanced Lighting Interface (RGB/CCT)
- Voice scene improvements
- Device-specific drivers

### Chowmain Software

https://chowmain.software

- Professional quality
- Home Assistant integration
- Unifi Intercom integration
- Many specialized drivers

### Blackwire Designs

- Lutron integration
- Custom development
- Complex system solutions

## Voice Control

### Amazon Alexa

**Setup:**
1. customer.control4.com → Voice Control
2. Enable functions for voice
3. Link Alexa skill to C4 account
4. Discover devices in Alexa app

**Commands:**
- "Alexa, turn on [light/room]"
- "Alexa, set [room] to 50%"
- "Alexa, [scene name]"

**Limitations:**
- Scene names must be unique
- Some complex actions not supported
- Requires 4Sight subscription

### Google Home

Similar setup via customer.control4.com

### Apple HomeKit

Requires third-party driver (Berto HomeKit Bridge or similar)

## Web2Way Driver (API Access)

GitHub: https://github.com/itsfrosty/control4-2way-web-driver

Exposes REST API for device control:
- Port 9000 on controller
- Used by Home Assistant custom components
- Enables DIY integrations

**Endpoints:**
```
GET http://<controller>:9000/device/<proxy_id>/state
POST http://<controller>:9000/device/<proxy_id>/command
```

**Finding proxy_id:**
- Composer Pro only (hover over device in tree)
- Or trial-and-error from known device IDs

## IP Control

### Direct TCP

Some C4 devices accept TCP commands:
- Amplifiers (limited)
- Controllers (restricted)

### Serial Control

Controller serial ports for:
- AV receivers
- Disc changers
- Projectors
- Custom devices

## Integration Best Practices

### Latency

- Native C4: Fastest (Zigbee/direct)
- Web2Way/REST: ~100-500ms
- MQTT: Variable based on broker
- Home Assistant: Depends on scan interval

### Reliability

1. Prefer local integrations over cloud
2. Use static IPs for all devices
3. Monitor integration health
4. Have fallback (C4 app always works)

### Security

- C4 controllers on isolated VLAN if possible
- MQTT broker with authentication
- Don't expose Web2Way to internet
- Regular password changes
