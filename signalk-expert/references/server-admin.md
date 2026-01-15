# SignalK Server Administration

## Systemd Service Management

### Common Commands

```bash
# Check status
systemctl status signalk

# View logs
journalctl -u signalk -n 100
journalctl -u signalk -f  # Follow live

# Restart service
sudo systemctl restart signalk

# Reload after config changes
sudo systemctl daemon-reload && sudo systemctl restart signalk
```

### Service File Location

```
/etc/systemd/system/signalk.service           # Main service file
/etc/systemd/system/signalk.service.d/        # Override directory
/etc/systemd/system/signalk.service.d/override.conf  # Custom overrides
```

### Typical Service Configuration

```ini
[Service]
ExecStart=/home/user/.signalk/signalk-server
Restart=always
StandardOutput=syslog
StandardError=syslog
WorkingDirectory=/home/user/.signalk
User=signalk
Environment=NODE_ENV=production
Environment=RUN_FROM_SYSTEMD=true
```

### Override File Pattern

```ini
[Unit]
After=socketcan-interface.service

[Service]
Environment="NODE_OPTIONS=--require /home/user/.signalk/maxListeners.js"
Environment="PORT=80"
```

## Common Errors and Fixes

### Port 80 Permission Denied (EACCES)

**Symptom**: `Error: listen EACCES: permission denied 0.0.0.0:80`

**Cause**: Node.js needs capability to bind to ports below 1024.

**Fix**:
```bash
sudo setcap 'cap_net_bind_service=+ep' $(which node)
sudo systemctl restart signalk
```

**Note**: This capability is lost when Node.js is upgraded. Re-run after any Node.js update.

### MODULE_NOT_FOUND After Update

**Symptom**: `Cannot find module 'somefile.js'`

**Cause**: SignalK update changed file paths; systemd override references old paths.

**Fix**:
```bash
# Check the override file
cat /etc/systemd/system/signalk.service.d/override.conf

# Update paths to match current installation
sudo nano /etc/systemd/system/signalk.service.d/override.conf

# Reload and restart
sudo systemctl daemon-reload && sudo systemctl restart signalk
```

### Multiple Instances Running

**Symptom**: High CPU usage, permission errors on files, inconsistent behavior.

**Diagnosis**:
```bash
ps aux | grep -E 'signalk|node' | grep -v grep
```

Look for:
- Multiple `node` processes running signalk-server
- Processes owned by different users (root vs normal user)
- Processes started via `sudo` that shouldn't be

**Fix**:
```bash
# Identify the legitimate systemd process (matches ExecStart path)
systemctl status signalk

# Kill rogue processes (NOT the systemd one)
sudo kill <rogue-pid>

# If files were created by wrong user, fix ownership
sudo chown -R signalk:signalk /path/to/data/directory
```

### Permission Denied on Data Files

**Symptom**: `EACCES: permission denied` when writing logs or data files.

**Causes**:
1. Files created by root process, now accessed by normal user
2. Mount point permissions
3. Directory doesn't exist

**Fix**:
```bash
# Check ownership
ls -la /path/to/directory/

# Fix ownership to match service user
sudo chown -R signalk:signalk /path/to/directory/

# Verify service user
grep User /etc/systemd/system/signalk.service
```

### File Not Found on Delete (ENOENT unlink)

**Symptom**: `ENOENT: no such file or directory, unlink '/path/to/file'`

**Cause**: Log rotation or cleanup trying to delete already-removed files.

**Impact**: Usually harmless - just cleanup code being overly aggressive.

**Fix**: Generally ignore, or update cleanup logic to check existence first.

## CAN Bus / SocketCAN Setup

### Check CAN Interface

```bash
# List interfaces
ip link show type can

# Check socketcan service
systemctl status socketcan-interface

# View raw CAN traffic
candump can0
```

### Common CAN Issues

**No data appearing**:
1. Check physical connection and termination (120 ohms each end)
2. Verify interface is up: `ip link show can0`
3. Check SignalK Data Connections in admin UI

**Interface down after reboot**:
```bash
# Bring up manually
sudo ip link set can0 up type can bitrate 250000

# Or restart socketcan service
sudo systemctl restart socketcan-interface
```

## Plugin Management

### Plugin Locations

```
~/.signalk/node_modules/           # Installed plugins
~/.signalk/plugin-config-data/     # Plugin configurations
```

### Symlinked Custom Plugins

Custom plugins can be symlinked from external locations:

```bash
ln -s /path/to/my-plugin ~/.signalk/node_modules/my-plugin
```

**Important**: Symlinks are removed when installing/updating plugins via App Store. Create a restore script:

```bash
#!/bin/bash
# restore-plugin-symlinks.sh
ln -sf /mnt/plugins/my-plugin /home/user/.signalk/node_modules/my-plugin
ln -sf /mnt/plugins/other-plugin /home/user/.signalk/node_modules/other-plugin
```

Run after any plugin operations:
```bash
./restore-plugin-symlinks.sh && sudo systemctl restart signalk
```

### Plugin Not Appearing in Config UI

**Diagnosis**:
```bash
# Check if plugin is registered
curl -s "http://localhost:3000/signalk/v2/features" | jq '.plugins[] | {id, name, enabled}'

# Check plugin config
cat ~/.signalk/plugin-config-data/plugin-name.json

# Check logs for errors
journalctl -u signalk | grep -i plugin-name
```

**Common fixes**:
1. Ensure `enabled: true` in config file
2. Add required schema fields to config
3. Hard refresh browser (Ctrl+Shift+R)
4. Restart service

## Useful Diagnostic Commands

```bash
# Server version
curl -s http://localhost:3000/signalk | jq .

# List all data paths
curl -s http://localhost:3000/signalk/v1/api/vessels/self | jq 'keys'

# Check what ports are in use
ss -tlnp | grep node

# Memory usage
ps aux | grep signalk-server | awk '{print $6/1024 " MB"}'

# Check Node.js version
node --version
```

## Event Listener Warnings

**Symptom**: `MaxListenersExceededWarning: Possible EventEmitter memory leak`

**Fix**: Create a maxListeners.js file:

```javascript
// ~/.signalk/maxListeners.js
require('events').EventEmitter.defaultMaxListeners = 100;
```

Reference in systemd override:
```ini
Environment="NODE_OPTIONS=--require /home/user/.signalk/maxListeners.js"
```
