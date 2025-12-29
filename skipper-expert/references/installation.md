# SKipper Installation Reference

## iOS / iPadOS

1. Open App Store
2. Search "SKipper App"
3. Install
4. Requires iOS 15.0 or later

---

## Android

1. Open Google Play Store
2. Search "SKipper"
3. Install

---

## Linux (Debian/Raspbian)

### Add Repository

```bash
curl -1sLf 'https://docs.skipperapp.net/install-skipper.sh' | sudo -E bash
```

### Install

```bash
sudo apt update
sudo apt install skipper
```

### Launch

Find in: Main Menu → Accessories → SKipper App

Or command line: `skipper`

### Uninstall

```bash
rm /etc/apt/sources.list.d/skipper-skipperapp.list
apt-get clean
rm -rf /var/lib/apt/lists/*
apt-get update
apt remove skipper
```

---

## Linux DRM/FrameBuffer (No X Window)

For dedicated displays without desktop environment.

**Advantages:**
- Faster startup
- Always fullscreen
- Lower resource usage
- Ideal for touchscreen dashboards

**Requirements:**
- Direct Rendering Manager (DRM) support
- Or FrameBuffer support

See: https://docs.skipperapp.net/desktop-arguments/#skipper-on-linux-with-drmframe-buffer

---

## Windows

1. Download installer from https://www.skipperapp.net/
2. Run installer
3. Follow standard Windows installation

---

## macOS (ARM)

1. Open App Store
2. Search "SKipper App"
3. Install
4. Requires ARM-based Mac (M1/M2/M3)

---

## Web Browser

**Demo:** http://play.skipperapp.net/

**Requirements:**
- WebAssembly (WASM) support
- Modern browser (Chrome, Firefox, Safari, Edge)

**Limitations:**
- No mDNS discovery (must enter server manually)
- First load may be slow

---

## First Run / Onboarding

### Step 1: Units

Select metric or imperial.
- Default based on device locale
- Can change per-control later

### Step 2: Find Server

**Automatic (mDNS):**
- SKipper searches local network
- Server appears in list if mDNS enabled
- Select your server

**Manual:**
- Click "Type address"
- Enter: `http://your_server_ip:port/`
- Click "Connect to server"

### Step 3: Authorization

1. Click "Request Authorization"
2. Open SignalK Admin UI (button provided)
3. Go to Security → Access Requests
4. Find SKipper request
5. Set Authentication Timeout to "NEVER"
6. Approve with Admin permissions

### Step 4: Load Pages (Optional)

If you have existing pages stored on server:
- SKipper will prompt to load them
- Or start fresh and load later from Settings

---

## Desktop Command Line Arguments

**Position and size:**
```bash
skipper -location x,y,width,height
```

**Example:**
```bash
skipper -location 0,0,1920,1080
```

**Use for:**
- Multi-monitor setups
- Specific screen placement
- Kiosk mode configurations

---

## Server Requirements

**SignalK Server:**
- Version 1.x or 2.x
- Security enabled (for authentication)
- mDNS enabled (optional, for discovery)

**Network:**
- SKipper device on same network as SignalK
- Or port forwarding for remote access
- WebSocket support required

**Plugins (recommended):**
- signalk-anchoralarm (for anchor control)
- signalk-autopilot (for autopilot control)
- Any PUT-capable plugins for device control
