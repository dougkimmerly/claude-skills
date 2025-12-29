# Control4 Troubleshooting

## Connection Issues

### Composer HE Can't Connect

**Symptoms:** "Could not connect to Director"

**Solutions:**
1. Verify PC and controller on same network
2. Check controller IP (System Manager)
3. Ping controller: `ping <controller-ip>`
4. Verify OS versions match
5. Try restarting Composer HE
6. Power cycle controller (last resort)

### Remote Showing "Waiting for Network"

**SR-250/260 Reset:**
1. Remove batteries
2. Hold Red 4 button + 0 button
3. Insert batteries while holding
4. Wait for lights to fade in/out
5. Re-identify in Composer

**Alternative sequence:** Room Off, #, *, 1, 3, 4, 1, 3

### Navigator Not Connecting

Touch screens/tablets:
1. Verify WiFi connection
2. Check for Director address
3. Restart Navigator app
4. Verify controller is online
5. Re-add Navigator in Composer (dealer)

## Zigbee Issues

### Device Not Responding

1. **Check power** - Switch/dimmer has power?
2. **Visual indicator** - LED status?
3. **9-9-9 Reset** - Tap top 9×, bottom 9×, top 9×
4. **Re-identify** - Connections → Network (Composer Pro)
5. **Move closer** - Mesh signal strength?

### Mesh-Wide Problems (After Power Outage)

**Symptoms:** Multiple devices offline, remotes not working

**Solutions:**
1. Wait 5-10 minutes for mesh to self-heal
2. Power cycle mesh controller
3. Restart Zserver (Composer Pro)
4. Check WiFi interference (2.4 GHz band)
5. Rebuild mesh (dealer required)

### Poor Zigbee Signal

**Diagnosis (Composer Pro):**
- Zigbee Health tab
- Check signal strength per device
- Look for high failure rates (>50/hour)

**Solutions:**
- Add powered devices (routers) to fill gaps
- Relocate mesh controller
- Check for interference sources
- Change Zigbee channel (dealer)

## Audio/Amplifier Issues

### No Sound

1. **Check source** - Is music playing at source?
2. **Check routing** - Correct input selected for zone?
3. **Check volume** - Zone not muted? Volume up?
4. **Check speaker wires** - Connections tight?
5. **Check amp front panel** - Signal indicators?

### Amplifier Not on Network

1. Verify Ethernet connected
2. Check front panel network status
3. Try static IP (front panel Config → Network)
4. Power cycle amplifier
5. Check network switch port

### Audio Quality Issues

**Clipping (CLIP LED lit):**
- Reduce input gain
- Lower source volume
- Check for cable issues

**Hum/Buzz:**
- Ground loop - try ground lift
- Check cable shielding
- Separate audio/power cables

## Programming Problems

### Scene Not Executing

1. **Test manually** - Does device respond to direct command?
2. **Check event** - Is trigger firing? (add debug action)
3. **Check conditions** - Are IF statements blocking?
4. **Check timing** - Delays causing issues?
5. **Verify scene** - Correct devices/levels?

### Button Not Working

1. **Test button** - Does LED change?
2. **Check binding** - Button bound to scene/action?
3. **Check programming** - Event has actions?
4. **Try different tap** - Single vs double vs hold

### Scheduler Not Firing

1. **Verify schedule** - Correct time/days?
2. **Check time zone** - Project settings correct?
3. **Check date range** - Start/stop dates valid?
4. **Controller clock** - Accurate time? (NTP?)

## App/Interface Issues

### Control4 App Slow

1. Force close and restart app
2. Clear app cache
3. Check WiFi signal
4. Verify controller not overloaded
5. Reduce Navigator refresh rate

### Favorites Not Showing

1. Refresh Navigators (Composer: File → Refresh Navigators)
2. Re-sync app (close/reopen)
3. Check room visibility settings

### Media Not Appearing

1. Re-scan media (Composer HE Media view)
2. Verify network share accessible
3. Check supported formats (MP3, FLAC, etc.)
4. Lookup service available?

## When to Call Your Dealer

**Dealer required for:**
- Adding new devices
- Installing drivers
- Zigbee mesh rebuild
- OS upgrades
- System design changes
- Connection/binding changes
- Replacing failed controller

**Try first yourself:**
- Power cycling
- Device resets (9-9-9)
- Programming changes (Composer HE)
- Media management
- Scene creation/editing
- Troubleshooting with this guide

## Diagnostic Commands

### Network Testing

```bash
# Ping controller
ping 192.168.20.43

# Check open ports
nmap -p 22,80,443,5020,5021,9000 192.168.20.43

# Telnet to amp debug
telnet 192.168.20.41
```

### Controller SSH (if enabled)

```bash
ssh root@<controller-ip>
# Default password varies by model/OS
```

## Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "Waiting for network" | Zigbee disconnected | Reset device |
| "Could not connect to Director" | Composer can't reach controller | Check network/versions |
| "No Navigators found" | App can't find controller | Check WiFi/controller IP |
| "Device offline" | Communication lost | Check power/Zigbee/network |
