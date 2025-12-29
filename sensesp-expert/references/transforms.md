# SensESP Transforms

Transforms process data between producers and consumers.

## Linear Scaling

```cpp
#include "sensesp/transforms/linear.h"

// output = input * multiplier + offset
new Linear(multiplier, offset, config_path)

// Examples:
new Linear(1.0, 273.15)           // °C to Kelvin
new Linear(0.514444, 0.0)         // knots to m/s
new Linear(1.0/4095.0, 0.0)       // ADC to 0-1 ratio
new Linear(3.3/4095.0 * 5.7, 0.0) // ADC with voltage divider
```

## Voltage Divider

```cpp
#include "sensesp/transforms/voltagedivider.h"

// For measuring higher voltages
// R1 = top resistor, R2 = bottom resistor
new VoltageDividerR2(R1, R2, config_path)

// 100k/27k divider for 12V battery
new VoltageDividerR2(100000, 27000, "/transforms/vdiv")
```

## Averaging & Filtering

```cpp
#include "sensesp/transforms/moving_average.h"
#include "sensesp/transforms/median.h"

// Moving average (smoothing)
new MovingAverage(10, "/transforms/avg")  // 10 samples

// Median filter (spike removal)
new Median(5, "/transforms/med")  // 5 samples
```

## Change Filter

```cpp
#include "sensesp/transforms/change_filter.h"

// Only emit when value changes significantly
new ChangeFilter(
    0.1,   // min_delta - minimum change to emit
    100.0, // max_delta - always emit if change exceeds this
    10,    // max_skips - emit after N unchanged readings anyway
    config_path
)
```

## Frequency (Pulses to Hz)

```cpp
#include "sensesp/transforms/frequency.h"

// Convert pulse count to frequency
// multiplier applied to result
new Frequency(1.0, config_path)

// For RPM: Hz * 60 = RPM
counter
  ->connect_to(new Frequency(1.0))
  ->connect_to(new Linear(60.0, 0.0))  // Hz to RPM
  ->connect_to(new SKOutputFloat("propulsion.main.revolutions"));

// Note: SignalK uses Hz, not RPM!
// So just output Hz directly:
counter
  ->connect_to(new Frequency(1.0))
  ->connect_to(new SKOutputFloat("propulsion.main.revolutions"));
```

## Threshold

```cpp
#include "sensesp/transforms/threshold.h"

// Emit true when above threshold
new ThresholdTransform<float, bool>(
    12.0,  // threshold
    true,  // value when above
    false  // value when below
)
```

## Lambda Transform (Custom)

```cpp
#include "sensesp/transforms/lambda_transform.h"

// Simple type conversion
new LambdaTransform<float, float>(
    [](float input) {
        return input * 2.0;
    },
    config_path
)

// With state
class MyTransform : public LambdaTransform<float, float> {
public:
    MyTransform() : LambdaTransform<float, float>(
        [this](float input) {
            return input + offset_;
        }
    ) {}
private:
    float offset_ = 10.0;
};
```

## Integrator

```cpp
#include "sensesp/transforms/integrator.h"

// Accumulate values over time
auto* integrator = new Integrator(1.0, 0.0, config_path);
// multiplier = 1.0, initial value = 0.0

// Reset integrator
integrator->set(0.0);
```

## Debounce

```cpp
#include "sensesp/transforms/debounce.h"

// For noisy digital inputs
new Debounce<bool>(50)  // 50ms debounce time
```

## Time Counter

```cpp
#include "sensesp/transforms/time_counter.h"

// Count time while input is true (engine hours)
new TimeCounter<bool>(config_path)
```

## Chaining Transforms

```cpp
adc_input
  ->connect_to(new VoltageDividerR2(100000, 27000))  // Scale voltage
  ->connect_to(new MovingAverage(10))                 // Smooth
  ->connect_to(new ChangeFilter(0.01, 1.0, 60))       // Reduce updates
  ->connect_to(new SKOutputFloat("electrical.batteries.house.voltage"));
```

## Splitting Output

```cpp
// One producer, multiple consumers
auto* temp = new OneWireTemperature(dallas);

temp->connect_to(new SKOutputFloat("environment.inside.temperature"));
temp->connect_to(new LambdaConsumer<float>([](float t) {
    // Also log locally
    Serial.printf("Temp: %.1f°C\n", t - 273.15);
}));
```
