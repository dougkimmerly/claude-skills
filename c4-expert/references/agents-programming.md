# Agents & Programming Patterns

## Advanced Lighting Scenes

More powerful than basic Lighting Scenes agent.

### Scene Properties

| Property | Description |
|----------|-------------|
| Show flash option | Enable light flashing |
| Tracking | All Loads / Any Load for scene activation |
| Hold Rates | Ramp speed when button held |
| Toggle Scene | Scene to activate on deactivation |
| Delay | Wait before action |
| Rate | Transition time (ramp/fade) |

### Scene Actions

- **Set Level:** Fixed brightness (0-100%)
- **Toggle:** Flip current state
- **Ramp:** Gradual change over time
- **Flash:** Blink on/off (alerts)
- **Delay On/Off:** Timed delays

### Example: Guest Mode Scene

Override motion sensors when entertaining:
```
Scene: "Party Mode"
- All outdoor lights: 80%
- Rate: 3 seconds
- Tracking: All Loads

Programming:
WHEN: Party Mode activates
  Set variable "PartyModeActive" = True

WHEN: Motion sensor triggers
  IF: PartyModeActive = False
  THEN: Execute normal motion programming
  ELSE: Do nothing (lights stay at party levels)
```

## Scheduler Agent

### Event Types

| Type | Options |
|------|----------|
| **Time** | Specific time (7:30 AM) |
| **Sunrise/Sunset** | Offset support (+/- minutes) |
| **Recurring** | Daily, Weekly, Monthly, Yearly |
| **One-time** | Specific date |

### Randomization

"Randomize by +/- X minutes" - Varies execution time:
- Security benefit (vacation mode)
- Prevents simultaneous device activation

### Example: Vacation Lighting

```
Event: "Vacation Evening"
- Time: Sunset
- Randomize: +/- 30 minutes
- Repeat: Daily
- Start: [vacation start]
- Stop: [vacation end]

Actions:
- Living room lights: Random 60-80%
- Kitchen lights: Random 40-60%
- Bedroom lights: 30% (delay 2 hours, then off)
```

### Conditional Schedules

Combine scheduler with conditionals:
```
WHEN: Scheduler "Morning" fires
  IF: Day of Week is Saturday OR Sunday
  THEN: Delay 2 hours, then execute
  ELSE: Execute immediately
```

## Timer Agent

### Timer Types

- **Countdown:** Single execution after delay
- **Repeating:** Execute every X interval

### Programming Timers

```
WHEN: Garage door opens
  Start timer "Garage Warning" (10 minutes)

WHEN: Timer "Garage Warning" expires
  IF: Garage door is still open
  THEN: 
    - Flash kitchen lights 3 times
    - Send push notification
    - Restart timer (another 10 minutes)
```

## Macros

Reusable action sequences - create once, use many places.

### Creating Macros

1. Agents → Add → Macros
2. Name the macro (e.g., "All Lights Off")
3. Add actions in Programming view
4. Use macro in other programming

### Example Macros

**"Goodnight Sequence":**
```
1. Set all interior lights to 0%
2. Delay 30 seconds
3. Lock all doors
4. Set thermostat to 68°F
5. Arm security system (Stay mode)
```

**"Movie Mode":**
```
1. Dim living room to 20%
2. Close blinds
3. Turn on AV system
4. Set receiver to surround mode
```

## Media Scenes

Multi-room audio groups that act as one zone.

### Configuration

1. Select rooms to include
2. Set volume relationships (master/slave)
3. Choose default source

### Usage

When Media Scene activates:
- All rooms play same source
- Volume adjusts proportionally
- Single interface controls all

## Push Notifications

Requires 4Sight subscription.

### Setup

1. Add Push Notification agent
2. Define notification text
3. Associate with events in programming

### Example

```
WHEN: Front door unlocked via code "Guest"
  Send push notification:
    "Guest arrived - Front door unlocked at [TIME]"
```

## Programming Best Practices

### Debouncing

Prevent rapid-fire execution:
```
WHEN: Motion sensor activates
  IF: Timer "MotionDebounce" is NOT running
  THEN:
    - Execute actions
    - Start timer "MotionDebounce" (30 seconds)
```

### State Tracking

Use variables to track system state:
```
Variables:
- PartyMode (Boolean)
- LastScene (String)
- OccupancyCount (Number)

WHEN: Scene changes
  Set LastScene = [scene name]
```

### Failsafes

Always include fallback logic:
```
WHEN: Goodnight scene activates
  Execute goodnight actions
  Start timer "GarageDoorCheck" (5 minutes)

WHEN: Timer "GarageDoorCheck" expires
  IF: Garage door is open
  THEN: Close garage door
```
