# PlatformIO Configuration

## Basic platformio.ini

```ini
[env:esp32]
platform = espressif32
board = esp32dev
framework = arduino
lib_deps =
    SignalK/SensESP @ ^3.0.0
monitor_speed = 115200
upload_speed = 921600
board_build.partitions = min_spiffs.csv
```

## Common Options

```ini
[env:esp32]
platform = espressif32
board = esp32dev
framework = arduino

# Dependencies
lib_deps =
    SignalK/SensESP @ ^3.0.0
    # Additional libraries as needed

# Serial
monitor_speed = 115200
upload_speed = 921600
monitor_filters = esp32_exception_decoder

# Partitions (more app space, less SPIFFS)
board_build.partitions = min_spiffs.csv

# Debug level (0=none, 5=verbose)
build_flags = 
    -D CORE_DEBUG_LEVEL=ARDUHAL_LOG_LEVEL_DEBUG
    -D LED_BUILTIN=2

# OTA update
upload_protocol = espota
upload_port = 192.168.1.100
```

## Build Commands

```bash
# Build
pio run

# Build and upload
pio run -t upload

# Serial monitor
pio device monitor

# Clean build
pio run -t clean

# List connected devices
pio device list

# Build for specific environment
pio run -e esp32

# Upload via OTA
pio run -t upload --upload-port 192.168.1.100
```

## ESP32 GPIO Reference

### Safe GPIO Pins

| GPIO | Function | Notes |
|------|----------|-------|
| 32, 33 | ADC1 + Touch | Safe for analog |
| 34, 35, 36, 39 | ADC1 | Input only, no pull-up |
| 25, 26, 27 | ADC2 + DAC | Can conflict with WiFi |
| 21, 22 | I2C | Default SDA, SCL |
| 16, 17 | UART2 | RX2, TX2 |
| 4 | GPIO | Common for 1-Wire |
| 13, 14, 15 | GPIO | Safe general purpose |

### Avoid These GPIO

| GPIO | Reason |
|------|--------|
| 0 | Boot mode (pull LOW = flash) |
| 2 | Boot mode + onboard LED |
| 5 | Boot mode (strapping pin) |
| 6-11 | Connected to flash memory |
| 12 | Boot mode (strapping pin) |
| 15 | Boot mode (debug output) |

### ADC Notes

- **ADC1** (GPIO 32-39): Works with WiFi
- **ADC2** (GPIO 0, 2, 4, 12-15, 25-27): **Cannot use while WiFi active!**
- Resolution: 12-bit (0-4095)
- Range: 0-3.3V

## Multiple Environments

```ini
[env:esp32]
platform = espressif32
board = esp32dev
framework = arduino
lib_deps = SignalK/SensESP @ ^3.0.0

[env:esp32-debug]
extends = env:esp32
build_flags = -D CORE_DEBUG_LEVEL=5

[env:esp32-production]
extends = env:esp32
build_flags = -D CORE_DEBUG_LEVEL=0
upload_protocol = espota
```

## WiFi Configuration

### First Boot (Captive Portal)

1. ESP creates AP: "Configure [hostname]"
2. Connect to AP with phone/laptop
3. Open 192.168.4.1
4. Enter WiFi credentials + SignalK server
5. ESP reboots and connects

### Hardcoded (Development)

```cpp
SensESPAppBuilder builder;
sensesp_app = builder
  .set_hostname("my-sensor")
  .set_wifi("SSID", "password")
  .set_sk_server("192.168.1.100", 3000)
  .get_app();
```

## OTA Updates

```ini
# In platformio.ini
upload_protocol = espota
upload_port = my-sensor.local  # or IP address
```

```bash
# Upload via OTA
pio run -t upload
```

## Partition Schemes

| Scheme | App | SPIFFS | OTA |
|--------|-----|--------|-----|
| default.csv | 1.2MB | 1.5MB | Yes |
| min_spiffs.csv | 1.9MB | 128KB | Yes |
| no_ota.csv | 2MB | 2MB | No |
| huge_app.csv | 3MB | 1MB | No |

For SensESP, `min_spiffs.csv` is usually best (more code space).
