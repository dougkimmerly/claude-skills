# Doug's Control4 System

> **System Age:** ~20 years (one of the longest-running C4 installations)
> **Last Updated:** [Pending user input]

## Network Inventory

From homelab network scan (192.168.20.0/24):

| IP | Device | Model | Firmware | Notes |
|----|--------|-------|----------|-------|
| .41 | 8-Channel Amp | C4-8AMP1-B | 03.24.45 | 4-zone matrix, telnet debug console |
| .42 | 16-Channel Amp | C4-16AMP3-B | 03.26.52 | 8-zone matrix, telnet debug console |
| .43 | Main Controller | TBD | TBD | Primary brain, most ports |
| .44 | Unknown | WattBox? | — | Telnet login (dealer creds) |
| .45 | Control4 Device | TBD | — | No open ports |
| .181 | Control4 Device | TBD | — | TBD |
| .190 | I/O Extender | TBD | — | SSH (Dropbear), SMB |

## Amplifier Configuration

### C4-8AMP1-B (4-Zone Matrix) - 192.168.20.41

- **Specs:** 60W @ 8Ω, 120W @ 4Ω per channel
- **Inputs:** 4 analog + 2 digital
- **Outputs:** 4 stereo speaker zones
- **Features:** Full matrix switching, parametric EQ
- **Debug:** Telnet passive console (logs activity, no commands)

### C4-16AMP3-B (8-Zone Matrix) - 192.168.20.42

- **Specs:** 120W @ 8Ω, 220W @ 4Ω per channel
- **Inputs:** 8 analog
- **Outputs:** 8 stereo speaker zones
- **Features:** Full matrix switching, parametric EQ, volume limiting
- **Debug:** Telnet passive console

## Audio Zones

| Zone | Amplifier | Room | Notes |
|------|-----------|------|-------|
| TBD | TBD | TBD | [Awaiting user input] |

## Lighting

| Location | Device Type | Notes |
|----------|-------------|-------|
| TBD | TBD | [Awaiting user input] |

## Keypads

| Location | Model | Buttons | Programming |
|----------|-------|---------|-------------|
| TBD | TBD | TBD | [Awaiting user input] |

## Scenes

| Scene Name | Trigger | Actions |
|------------|---------|----------|
| TBD | TBD | [Awaiting user input] |

## Integrations

### Current

- TBD

### Planned/Potential

- Home Assistant integration (native C4 component or Chowmain driver)
- MQTT bridge via Berto drivers

## System Notes

[Space for user documentation about system behavior, quirks, dealer info, etc.]

## Dealer Information

- **Original Installer:** TBD
- **Current Dealer:** TBD
- **OS Version:** TBD
- **4Sight Status:** TBD
- **Composer HE License:** TBD
