---
name: sensesp-expert
description: SensESP development expertise for ESP32/ESP8266 sensors with SignalK integration. Use when developing SensESP firmware (C++/PlatformIO), creating sensor pipelines (producers, transforms, consumers), connecting to SignalK servers, working with ESP32 GPIO, or debugging embedded sensor code. Covers ReactESP async patterns, WiFi configuration, and hardware interfacing.
---

# SensESP Expert

Expertise for developing ESP32/ESP8266 sensors that publish to SignalK.

## Quick Reference

### Project Structure

```
my-sensor/
├── platformio.ini      # Build config, dependencies
├── src/
│   └── main.cpp        # Application code
├── include/            # Header files
└── data/               # SPIFFS (web UI)
```

### Basic Application

```cpp
#include <Arduino.h>
#include "sensesp_app_builder.h"
#include "sensesp/sensors/analog_input.h"
#include "sensesp/transforms/linear.h"

using namespace sensesp;

SensESPApp* sensesp_app;

void setup() {
  SensESPAppBuilder builder;
  sensesp_app = builder
    .set_hostname("my-sensor")
    .set_sk_server("192.168.1.100", 3000)
    .get_app();

  // Sensor pipeline: Producer -> Transform -> Consumer
  auto* input = new AnalogInput(36, 1000);  // GPIO36, 1s interval

  input
    ->connect_to(new Linear(1.0, 0.0, "/transforms/cal"))
    ->connect_to(new SKOutputFloat("environment.outside.temperature"));

  sensesp_app->start();
}

void loop() {
  sensesp_app->tick();
}
```

### Core Pipeline Pattern

```
Producer → Transform → Transform → Consumer
   ↓           ↓           ↓          ↓
Sensor    Calibrate    Filter    SKOutput
```

Everything connects via `->connect_to()`.

### Common Producers

```cpp
new AnalogInput(gpio, interval_ms)              // ADC reading
new DigitalInputState(gpio, mode, interval_ms)  // HIGH/LOW
new DigitalInputCounter(gpio, mode, edge, ms)   // Pulse count
new OneWireTemperature(dallas, config_path)     // DS18B20
```

### Common Transforms

```cpp
new Linear(multiplier, offset, config_path)     // y = mx + b
new MovingAverage(samples, config_path)         // Smoothing
new ChangeFilter(min, max, skips, config_path)  // Only on change
new Frequency(1.0, config_path)                 // Pulses to Hz
new LambdaTransform<In, Out>([](In v) { return v * 2; }, path)
```

### Consumers (SignalK Output)

```cpp
new SKOutputFloat("path.to.value", config_path)
new SKOutputInt("path.to.value", config_path)
new SKOutputBool("path.to.value", config_path)
```

### ReactESP Timing (Non-blocking)

```cpp
// One-shot delay
reactESP->onDelay(5000, []() { /* after 5s */ });

// Repeating
reactESP->onRepeat(500, []() { /* every 500ms */ });
```

**Critical:** Never use `delay()` in loop - use ReactESP instead.

### Build Commands

```bash
pio run                    # Build
pio run -t upload          # Flash to ESP32
pio device monitor         # Serial output
pio run -t clean           # Clean build
```

## Detailed References

- **[references/producers.md](references/producers.md)** - All sensor input types
- **[references/transforms.md](references/transforms.md)** - Data processing transforms
- **[references/patterns.md](references/patterns.md)** - C++ coding patterns, class structure
- **[references/platformio.md](references/platformio.md)** - Build configuration, GPIO reference
- **[references/debugging.md](references/debugging.md)** - Logging, serial monitor, common issues

## Key Documentation

| Resource | URL |
|----------|-----|
| SensESP Docs | https://signalk.org/SensESP/ |
| GitHub | https://github.com/SignalK/SensESP |
| Examples | https://github.com/SignalK/SensESP/tree/main/examples |
| Class Reference | https://signalk.org/SensESP/docs/generated/docs/ |
