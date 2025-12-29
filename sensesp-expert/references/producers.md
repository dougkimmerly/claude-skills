# SensESP Producers

Producers generate data from hardware sensors.

## Analog Input (ADC)

```cpp
#include "sensesp/sensors/analog_input.h"

// Basic analog read
auto* input = new AnalogInput(36, 1000);  // GPIO36, every 1000ms

// With config path for web UI calibration
auto* input = new AnalogInput(36, 1000, "/sensors/voltage");
```

ESP32 ADC: 12-bit (0-4095), 0-3.3V range.

## Digital Input

### State (HIGH/LOW)

```cpp
#include "sensesp/sensors/digital_input.h"

// Read switch state
auto* switch_state = new DigitalInputState(
    GPIO_NUM_4,      // Pin
    INPUT_PULLUP,    // Mode
    1000             // Read interval ms
);
```

### Change Detection

```cpp
// Only emit on state change
auto* button = new DigitalInputChange(
    GPIO_NUM_4,
    INPUT_PULLUP,
    CHANGE           // RISING, FALLING, or CHANGE
);
```

### Pulse Counter

```cpp
// Count pulses (for RPM, flow meters)
auto* counter = new DigitalInputCounter(
    GPIO_NUM_4,
    INPUT_PULLUP,
    RISING,          // Count rising edges
    1000             // Report every 1000ms
);

// Convert to frequency
counter->connect_to(new Frequency(1.0, "/transforms/freq"));
```

## Temperature Sensors

### DS18B20 (1-Wire)

```cpp
#include "sensesp/sensors/onewire_temperature.h"

#define ONE_WIRE_PIN 4

auto* dallas = new DallasTemperatureSensors(ONE_WIRE_PIN);

// Each sensor on the bus
auto* temp1 = new OneWireTemperature(dallas, "/sensors/temp1");
auto* temp2 = new OneWireTemperature(dallas, "/sensors/temp2");

temp1
  ->connect_to(new Linear(1.0, 273.15))  // °C to Kelvin
  ->connect_to(new SKOutputFloat("propulsion.main.temperature"));
```

### BME280 (I2C)

```cpp
#include "sensesp/sensors/bme280.h"

auto* bme = new BME280(0x76);  // I2C address

bme->temperature_source
  ->connect_to(new SKOutputFloat("environment.inside.temperature"));

bme->pressure_source
  ->connect_to(new SKOutputFloat("environment.outside.pressure"));

bme->humidity_source
  ->connect_to(new SKOutputFloat("environment.inside.humidity"));
```

## GPS

```cpp
#include "sensesp/sensors/gps.h"

auto* gps = new GPSInput(Serial2, 9600);

gps->position
  ->connect_to(new SKOutputPosition("navigation.position"));

gps->speed
  ->connect_to(new SKOutputFloat("navigation.speedOverGround"));

gps->course
  ->connect_to(new SKOutputFloat("navigation.courseOverGroundTrue"));
```

## System Sensors

```cpp
#include "sensesp/sensors/system_info.h"

// ESP32 internal
auto* uptime = new Uptime();
auto* free_mem = new FreeMem();
auto* ip = new IPAddressDisplay();
```

## Custom Producer

```cpp
#include "sensesp/sensors/sensor.h"

class MyCustomSensor : public Sensor<float> {
public:
    MyCustomSensor(uint read_interval)
        : Sensor<float>(read_interval) {}
    
    void update() override {
        float value = readHardware();
        this->emit(value);
    }
    
private:
    float readHardware() {
        // Your sensor reading code
        return 42.0;
    }
};
```

## Observable Values (Manual Emit)

```cpp
#include "sensesp/system/observable.h"

// Create observable
auto* chain_length = new ObservableValue<float>(0.0);

// Connect to SignalK
chain_length->connect_to(
    new SKOutputFloat("navigation.anchor.rodeDeployed")
);

// Later, emit new value
chain_length->set(15.5);
```

## SignalK Listener (Subscribe to SK Data)

```cpp
#include "sensesp/signalk/signalk_listener.h"

// Listen to SignalK path
auto* depth = new SKValueListener<float>("environment.depth.belowSurface");

depth->connect_to(new LambdaConsumer<float>([](float d) {
    Serial.printf("Depth: %.2f m\n", d);
}));
```
