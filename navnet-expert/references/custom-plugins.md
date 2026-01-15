# Custom Plugin Management on NavNet

## Overview

Custom/modified plugins are stored in `/mnt/usb/src/` and symlinked into SignalK's `node_modules` directory. This approach:
- Preserves custom changes across npm updates
- Keeps plugins under version control (git)
- Allows easy switching between custom and upstream versions

## Current Custom Plugins

| Plugin | Custom Location | Symlink Name |
|--------|-----------------|--------------|
| openweather-signalk | `/mnt/usb/src/signalk-openweather-plugin` | `openweather-signalk` |

## Setting Up a Custom Plugin

### 1. Clone/Copy to Custom Location

```bash
# Clone from git
cd /mnt/usb/src
git clone https://github.com/example/signalk-some-plugin.git

# Or copy existing plugin
cp -r /home/doug/.signalk/node_modules/some-plugin /mnt/usb/src/
cd /mnt/usb/src/some-plugin
git init  # Optional: track changes
```

### 2. Remove npm Version and Create Symlink

```bash
# Remove npm-installed version
rm -rf /home/doug/.signalk/node_modules/some-plugin

# Create symlink
ln -s /mnt/usb/src/some-plugin /home/doug/.signalk/node_modules/some-plugin

# Remove from package.json so npm won't reinstall it
cd /home/doug/.signalk
grep -v '"some-plugin"' package.json > tmp.json && mv tmp.json package.json
```

### 3. Bump Version to Prevent "Update Available"

Check the latest npm version and set yours higher:

```bash
# Check npm registry version
npm view some-plugin version
# Output: 1.0.2

# Edit your custom plugin's package.json
# Change: "version": "1.0.0"
# To:     "version": "1.1.0-custom"
```

The `-custom` suffix:
- Clearly indicates this is a modified fork
- Semver considers `1.1.0-custom` higher than `1.0.2`
- SignalK UI won't show it as needing updates

### 4. Add to Restore Script

Edit `/home/doug/.signalk/restore-plugin-symlinks.sh`:

```bash
# some-plugin -> custom version
if [ ! -L /home/doug/.signalk/node_modules/some-plugin ]; then
    rm -rf /home/doug/.signalk/node_modules/some-plugin 2>/dev/null
    ln -s /mnt/usb/src/some-plugin /home/doug/.signalk/node_modules/some-plugin
    echo "✓ some-plugin symlinked"
else
    echo "✓ some-plugin already symlinked"
fi
```

## Restore Script

Location: `/home/doug/.signalk/restore-plugin-symlinks.sh`

Run after any npm operations (install, update, App Store changes):

```bash
/home/doug/.signalk/restore-plugin-symlinks.sh && sudo systemctl restart signalk
```

### Current Restore Script Contents

```bash
#!/bin/bash
# Restore custom plugin symlinks after npm install/update

echo "Restoring custom plugin symlinks..."

# openweather-signalk -> custom version
if [ ! -L /home/doug/.signalk/node_modules/openweather-signalk ]; then
    rm -rf /home/doug/.signalk/node_modules/openweather-signalk 2>/dev/null
    ln -s /mnt/usb/src/signalk-openweather-plugin /home/doug/.signalk/node_modules/openweather-signalk
    echo "✓ openweather-signalk symlinked"
else
    echo "✓ openweather-signalk already symlinked"
fi

echo "Done. Restart SignalK: sudo systemctl restart signalk"
```

## Updating Custom Plugins

### Pulling Upstream Changes

```bash
cd /mnt/usb/src/signalk-openweather-plugin
git fetch origin
git log HEAD..origin/main --oneline  # See what's new

# If you want upstream changes:
git merge origin/main
# Resolve any conflicts with your customizations
```

### Tracking Your Changes

```bash
cd /mnt/usb/src/signalk-openweather-plugin
git status
git diff
git log --oneline -10
```

## Troubleshooting

### Plugin Not Loading After npm Update

npm removed your symlink. Run the restore script:

```bash
/home/doug/.signalk/restore-plugin-symlinks.sh
sudo systemctl restart signalk
```

### Plugin Shows as Needing Update

Your custom version number is lower than npm. Bump it:

```bash
# Check npm version
npm view plugin-name version

# Edit package.json in your custom plugin
# Set version higher than npm (e.g., add -custom suffix)
```

### Changes Not Taking Effect

Restart SignalK after modifying plugin code:

```bash
sudo systemctl restart signalk
```

### Symlink Exists But Plugin Not Working

Check the symlink target exists:

```bash
ls -la /home/doug/.signalk/node_modules/openweather-signalk
# Should show -> /mnt/usb/src/signalk-openweather-plugin

ls /mnt/usb/src/signalk-openweather-plugin/
# Should show plugin files (index.js, package.json, etc.)
```

## Best Practices

1. **Version control**: Keep custom plugins in git repos
2. **Document changes**: Note what you modified and why
3. **Use -custom suffix**: Makes version intent clear
4. **Test after updates**: Always verify after npm operations
5. **Backup restore script**: Keep a copy outside .signalk
