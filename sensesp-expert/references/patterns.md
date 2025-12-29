# SensESP C++ Patterns

## Class Structure

```cpp
// Header file (.h)
class ChainController {
public:
    // Constructor
    ChainController(float min, float max);
    
    // Public methods
    void lowerAnchor(float amount);
    void stop();
    float getChainLength() const;  // const for getters
    
    // Constants
    static constexpr float BOW_HEIGHT_M = 2.0;
    
private:
    // Member variables (trailing underscore)
    float min_length_;
    float target_;
    ChainState state_;
    
    // Private helpers
    void updateTimeout(float amount);
};
```

## Enum Classes

```cpp
// Prefer enum class (type safe)
enum class ChainState {
    IDLE,
    LOWERING,
    RAISING
};

// Usage
if (state_ == ChainState::IDLE) { ... }
```

## Constants

```cpp
// Use constexpr for compile-time constants
static constexpr float BOW_HEIGHT_M = 2.0;
static constexpr unsigned long COOLDOWN_MS = 3000;
```

## Null/Pointer Safety

```cpp
// Always check pointers before use
if (depthListener_ != nullptr) {
    float depth = depthListener_->get();
}

// Or early return pattern
if (accumulator_ == nullptr) return;
```

## Safe Math

```cpp
// Avoid division by zero
if (depth > 0.01) {
    float scope = chain / depth;
}

// Use fmax/fmin for bounds
float effective = fmax(0.0, depth - BOW_HEIGHT);

// Check for valid numbers
if (!isnan(value) && !isinf(value)) {
    // Use value
}
```

## SensESP Observable Pattern

```cpp
// Create observable value
horizontalSlack_ = new ObservableValue<float>(0.0);

// Connect to SignalK
horizontalSlack_->connect_to(
    new SKOutputFloat("navigation.anchor.chainSlack")
);

// Later, emit value
horizontalSlack_->set(newValue);
```

## SensESP Listener Pattern

```cpp
// In class constructor
depthListener_ = new SKValueListener<float>("environment.depth.belowSurface");

// In main.cpp setup
controller->getDepthListener()->connect_to(
    new LambdaConsumer<float>([controller](float depth) {
        controller->setDepthBelowSurface(depth);
    })
);
```

## Lambda Consumers

```cpp
// Simple callback
new LambdaConsumer<float>([](float value) {
    Serial.printf("Received: %.2f\n", value);
});

// Capturing variables
new LambdaConsumer<float>([controller](float value) {
    controller->setValue(value);
});

// Capturing by reference (careful with lifetime!)
new LambdaConsumer<float>([&state](float value) {
    state = value;  // Danger if state goes out of scope
});
```

## ReactESP Async (Never use delay()!)

```cpp
// One-shot delayed action
reactESP->onDelay(5000, []() {
    Serial.println("5 seconds elapsed");
});

// Repeating action
reactESP->onRepeat(500, []() {
    calculateSlack();
});

// Cancel a reaction
auto reaction = reactESP->onRepeat(100, myFunc);
reaction->remove();  // Stop it
```

## Hardware Control

```cpp
// Initialize pins in setup
pinMode(downRelayPin_, OUTPUT);
pinMode(upRelayPin_, OUTPUT);

// Relay control (check active HIGH or LOW!)
digitalWrite(downRelayPin_, LOW);   // Typically ON
digitalWrite(downRelayPin_, HIGH);  // Typically OFF

// Safe direction change
void changeDirection() {
    digitalWrite(downRelayPin_, HIGH);  // Stop both
    digitalWrite(upRelayPin_, HIGH);
    // Use ReactESP delay, not delay()!
    reactESP->onDelay(100, [this]() {
        // Now safe to activate new direction
    });
}
```

## Logging

```cpp
// ESP-IDF style (preferred)
ESP_LOGI("TAG", "Info: %.2f", value);
ESP_LOGW("TAG", "Warning message");
ESP_LOGE("TAG", "Error: %d", code);
ESP_LOGD("TAG", "Debug details");

// Simple Serial (quick debugging)
Serial.printf("[DEBUG] chain=%.2f depth=%.2f\n", chain, depth);
```

## Common Gotchas

1. **Forgetting `const`** on getter methods
2. **Integer division** - use `float(a) / b`
3. **Pointer lifetime** - SensESP objects must persist (use `new`)
4. **Relay active state** - check datasheet for HIGH/LOW
5. **Blocking delays** - never use `delay()`, use ReactESP
6. **Missing includes** - each SensESP class needs its header
7. **WiFi 5GHz** - ESP32 only supports 2.4GHz
