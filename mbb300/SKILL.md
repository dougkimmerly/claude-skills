---
name: mbb300
description: Maretron MBB300C vessel monitoring black box
triggers:
  - mbb300
  - maretron
  - n2k
  - nmea 2000
  - vessel monitoring
location: project
---

# Maretron MBB300C - Vessel Monitoring Black Box

**CRITICAL: READ ONLY - DO NOT MODIFY ANYTHING ON THIS DEVICE**

This is proprietary Maretron hardware with licensed software. Any changes could break functionality that requires specialized support to fix. The device requires a license key to operate.

## Device Overview

| Property | Value |
|----------|-------|
| Model | Maretron MBB300C |
| IP Address | 192.168.22.23 (DHCP) |
| MAC Address | 18:9b:a5:15:b1:4d |
| Hostname | N2K-ANALYZER-3 (approx.) |
| Vessel | Distant Shores II |
| OS | Ubuntu 12.04.2 LTS (Precise) 32-bit |
| Kernel | Linux 3.5.0-37-generic i686 |
| Disk | 7.4GB (56% used) |
| RAM | ~2GB |

## Access

```bash
# SSH access (created for Doug)
sshpass -p 'transport' ssh doug@192.168.22.23

# Original owner account
# User: n2kowner
# Password: unknown (do not attempt brute force)
```

**TeamViewer** is also installed for remote access (runs under Wine).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Maretron MBB300C (192.168.22.23)                 │
├─────────────────────────────────────────────────────────────────────┤
│  Hardware:                                                          │
│    └── Maretron USBCAN (serial 1871063) → /dev/ttyACM1             │
│                                                                     │
│  Software Stack:                                                    │
│    ├── N2KView (Adobe AIR application)                             │
│    ├── IPG100_0.elf (CAN bus 0 gateway) → ports 6543, 6544         │
│    ├── IPG100_1.elf (CAN bus 1 gateway) → ports 6553, 6554         │
│    ├── usbcan_socket.elf (USB-CAN interface)                       │
│    ├── N2KAnalyzer (Windows app via Wine)                          │
│    └── TeamViewer (remote access via Wine)                         │
│                                                                     │
│  NMEA 2000 Data Ports:                                              │
│    ├── 6543, 6544 (IPG100 channel 0)                               │
│    ├── 6553, 6554 (IPG100 channel 1)                               │
│    └── 65500, 65501 (N2KAnalyzer)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Listening Ports

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH (OpenSSH 5.9) | TCP |
| 631 | CUPS (printing) | TCP |
| 5939 | TeamViewer (localhost only) | TCP |
| 6543 | IPG100 channel 0 data | TCP |
| 6544 | IPG100 channel 0 data | TCP |
| 6553 | IPG100 channel 1 data | TCP |
| 6554 | IPG100 channel 1 data | TCP |
| 65500 | N2KAnalyzer data | TCP |
| 65501 | N2KAnalyzer data | TCP |

## Key Files and Directories

| Path | Purpose |
|------|---------|
| `/home/n2kowner/IPG/` | IPG100 gateway executables and scripts |
| `/home/n2kowner/IPG/IPG100.elf` | Main NMEA 2000 gateway binary |
| `/home/n2kowner/IPG/usbcan_socket.elf` | USB-CAN interface |
| `/home/n2kowner/IPG/authorize` | License authorization tool |
| `/home/n2kowner/IPG/eeprom_*.hex` | EEPROM images for CAN interfaces |
| `/home/n2kowner/n2k/` | N2KView configuration |
| `/home/n2kowner/n2k/DSII/` | Vessel-specific config (Distant Shores II) |
| `/home/n2kowner/n2k/DSII/DSII.n2k` | Main N2KView configuration file |
| `/home/n2kowner/N2KAnalyzer.cfg` | N2KAnalyzer configuration |
| `/home/n2kowner/.wine/` | Wine prefix for Windows apps |

## Running Processes

The system runs several screen sessions under `n2kowner`:

```
SCREEN -dmS usbcan /home/n2kowner/IPG/loop_usbcan.sh
SCREEN -dmS IPG100_0 /home/n2kowner/IPG/loop_IPG.sh 0
SCREEN -dmS IPG100_1 /home/n2kowner/IPG/loop_IPG.sh 1
```

The IPG100 processes auto-restart on crash (exit code 99 = intentional shutdown).

## Licensed Features

From `terminal.xml`:
- Alerts: enabled
- Device Control: enabled
- Fuel Management: enabled
- Video: enabled

## Unit Settings

| Measurement | Unit |
|-------------|------|
| Heading | Magnetic |
| Depth | Feet |
| Distance | Nautical miles |
| Boat Speed | Knots |
| Wind Speed | Knots |
| Temperature | Fahrenheit |
| Atmospheric Pressure | inHg |
| Fluid Pressure | PSI |
| Volume | Gallons |
| Time Format | 24-Hour |

## Telemetric Data Points

The system tracks:
- Lat/Long position
- Course Over Ground (COG)
- Speed Over Ground (SOG)
- Date/Time
- CAN bus status (2 channels)

## Important Notes

1. **OpenSSH 5.9** - Too old for ed25519 keys. Use RSA or password auth.

2. **No web interface** - All management is via N2KView desktop application or TeamViewer remote access.

3. **License Key Required** - The `authorize` binary handles licensing. Do not modify.

4. **tmpfs for logs** - `/var/log` and `/var/tmp` are tmpfs (RAM disks). Logs don't persist across reboots.

5. **Two CAN buses** - The device has two independent NMEA 2000 interfaces (channels 0 and 1), possibly for redundancy or separate networks.

## Diagnostic Commands (READ ONLY)

```bash
# Check system status
sshpass -p 'transport' ssh doug@192.168.22.23 "uptime && free -m && df -h"

# Check IPG100 processes
sshpass -p 'transport' ssh doug@192.168.22.23 "ps aux | grep -E 'IPG100|usbcan' | grep -v grep"

# Check listening ports
sshpass -p 'transport' ssh doug@192.168.22.23 "netstat -tln"

# Check USB devices (USBCAN)
sshpass -p 'transport' ssh doug@192.168.22.23 "lsusb"

# Check kernel messages for CAN
sshpass -p 'transport' ssh doug@192.168.22.23 "dmesg | grep -i 'maretron\|can' | tail -20"

# View alert history
sshpass -p 'transport' ssh doug@192.168.22.23 "cat /home/n2kowner/n2k/AlertHistory.xml"
```

## Recovery (If Needed)

**WARNING: Only attempt recovery with Maretron support guidance.**

According to the user, there's a key sequence during boot to access the command line directly. This was walked through by a Maretron technician.

If the system needs restart:
```bash
# Reboot (requires root or sudo)
sudo reboot
```

## Network Configuration

The device uses DHCP on eth0 with IPv4LL (zeroconf) fallback:

```
/etc/network/interfaces:
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
auto eth0:1
iface eth0:1 inet ipv4ll
```

## Integration Possibilities

The TCP ports (6543, 6544, 6553, 6554, 65500, 65501) stream NMEA 2000 data in Maretron's proprietary format. This could potentially be:
- Logged for historical analysis
- Converted to standard NMEA 0183 or SignalK
- Displayed on other dashboards

**But first**: Understand the data format and test carefully without modifying the MBB300.

## Credentials

Store in Bitwarden:
- Service: mbb300 (Maretron MBB300C)
- Host: 192.168.22.23
- Username: doug
- Password: transport
- Notes: Read-only access for monitoring. Do not modify system.

## Related

- Maretron N2KView documentation
- NMEA 2000 protocol (CAN bus based)
- IPG100 (IP Gateway 100) - Maretron's NMEA 2000 to Ethernet gateway

---

**REMEMBER: This is a critical vessel monitoring system. Look but don't touch.**
