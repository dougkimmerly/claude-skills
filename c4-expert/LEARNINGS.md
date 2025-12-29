# C4 Expert Skill Learnings

> Session learnings for continuous improvement of this skill.

## 2025-12-29 - Initial Creation

### Sources Researched

- Control4 official documentation (docs.control4.com)
- C4 Forums (c4forums.com) - community troubleshooting
- AVS Forum threads on Control4
- DriverCentral and Chowmain driver documentation
- Home Assistant integration docs
- GitHub repos: Berto drivers, Web2Way driver, HA components

### Key Insights

1. **Dealer Lock-in Reality**
   - Homeowners can do ~90% of programming with Composer HE
   - Cannot add devices, drivers, or modify connections
   - When>>Then provides basic automations without HE
   - Community has developed workarounds (remote dealers at lower rates)

2. **Zigbee Mesh Critical**
   - Most C4 devices use Zigbee (not WiFi or Z-Wave)
   - Mesh health determines system reliability
   - 9-9-9 reset sequence for switches/dimmers
   - Power outages can disrupt mesh (self-heals in 5-10 min)

3. **Integration Options**
   - Home Assistant native component (OS 3.0+, limited)
   - Chowmain drivers (commercial, comprehensive)
   - Berto drivers (free, MQTT-based)
   - Web2Way driver enables REST API access

4. **Doug's System Notes**
   - ~20 year old installation (impressive longevity)
   - C4-8AMP1-B and C4-16AMP3-B amplifiers present
   - Telnet debug available on amps (passive logging)
   - Network: 192.168.20.41-45, .181, .190

### Gaps to Fill

- Doug's specific room/zone layout
- Current OS version
- Keypad locations and programming
- Integration points with homelab
- Scene definitions and usage patterns
- Any existing Composer HE license

### Future Improvements

- Add specific programming examples from Doug's system
- Document successful integrations
- Add n8n workflow patterns for C4 automation
- Integration with homelab monitoring
