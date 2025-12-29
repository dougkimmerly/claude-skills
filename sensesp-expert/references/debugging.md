# SensESP Debugging

## Serial Monitor

```bash
# Start monitor
pio device monitor

# With exception decoder
pio device monitor --filter esp32_exception_decoder

# Specific port
pio device monitor -p /dev/ttyUSB0
```

## Logging Levels

Set in `platformio.ini`:

```ini
build_flags = -D CORE_DEBUG_LEVEL=ARDUHAL_LOG_LEVEL_DEBUG
```

| Level | Value | Shows |
|-------|-------|-------|
| NONE | 0 | Nothing |
| ERROR | 1 | Errors only |
| WARN | 2 | + Warnings |
| INFO | 3 | + Info |
| DEBUG | 4 | + Debug |
| VERBOSE | 5 | Everything |

## Logging in Code

```cpp
// ESP-IDF style (recommended)
ESP_LOGE("TAG", "Error: %s", message);
ESP_LOGW("TAG", "Warning: %d", code);
ESP_LOGI("TAG", "Info: %.2f", value);
ESP_LOGD("TAG", "Debug details");
ESP_LOGV("TAG", "Verbose trace");

// SensESP style
debugE("Error message");
debugW("Warning message");
debugI("Info message");
debugD("Debug message");

// Quick Serial.printf
Serial.printf("[CHAIN] len=%.2f state=%d\n", length, state);
```

## Configuration Web UI

Access at: `http://[hostname].local/`

- View current values
- Adjust transform parameters
- Reset configuration
- Restart device

## SignalK Verification

Check if data reaching SignalK:

```bash
# REST API
curl http://192.168.1.100:3000/signalk/v1/api/vessels/self/navigation/anchor/rodeDeployed

# WebSocket stream
wscat -c ws://192.168.1.100:3000/signalk/v1/stream?subscribe=all
```

## Common Issues

### WiFi Won't Connect

- ESP32 only supports **2.4GHz** (no 5GHz)
- Check SSID/password spelling
- Try hardcoding credentials for testing
- Check router isn't blocking new devices

### SignalK Connection Failed

- Verify IP address and port (usually 3000)
- Check SignalK server is running
- Verify no authentication required (or configure token)
- Check firewall isn't blocking

### Sensor Not Reading

- Check wiring and power
- Verify GPIO pin is correct and safe to use
- Add pull-up/pull-down resistors if needed
- Check ADC2 pins don't work with WiFi

### Values Not Appearing in SignalK

- Verify SK path format (dot notation)
- Check SignalK server logs
- Use Serial.printf to confirm values are being sent
- Check ChangeFilter isn't blocking unchanged values

### Boot Loops / Crashes

- Check GPIO pins (avoid boot-sensitive pins)
- Look for `delay()` calls - use ReactESP instead
- Check for null pointer dereferences
- Use exception decoder in monitor

### Memory Issues

```cpp
// Check free heap
Serial.printf("Free heap: %d\n", ESP.getFreeHeap());

// Check minimum free heap (water mark)
Serial.printf("Min heap: %d\n", ESP.getMinFreeHeap());
```

## Reset Configuration

If device is in bad state:

1. Erase flash: `pio run -t erase`
2. Re-upload: `pio run -t upload`
3. Reconfigure WiFi via captive portal

## Factory Reset via Serial

```cpp
// Add to main.cpp for emergency reset
if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    if (cmd == "reset") {
        // Clear preferences
        nvs_flash_erase();
        ESP.restart();
    }
}
```

## Useful Serial Commands

```cpp
void handleSerialCommands() {
    if (Serial.available()) {
        String cmd = Serial.readStringUntil('\n');
        cmd.trim();
        
        if (cmd == "status") {
            Serial.printf("Chain: %.2f m\n", chainLength);
            Serial.printf("State: %d\n", state);
            Serial.printf("Heap: %d\n", ESP.getFreeHeap());
        } else if (cmd == "restart") {
            ESP.restart();
        } else if (cmd == "wifi") {
            Serial.printf("IP: %s\n", WiFi.localIP().toString().c_str());
            Serial.printf("RSSI: %d dBm\n", WiFi.RSSI());
        }
    }
}
```
