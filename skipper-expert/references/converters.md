# SKipper Data Converters Reference

Converters transform SignalK data for display.

---

## Position to WGS-84 String

Converts `navigation.position` JSON to readable coordinates.

**Input:** `{ "latitude": 45.123, "longitude": -122.456 }`

**Arguments:**
- `DDD°MM'SS'' N/S/W/E` - Degrees, minutes, seconds
- `000.000 N/S/W/E` - Decimal degrees

**Options:**
- Two lines checkbox: Put lat and lon on separate lines

**Use with:** Label control for position display

---

## Datetime to String

Formats datetime paths.

**Arguments:**
- `datetime` - Full date and time, local format
- `twolines` - Date on line 1, time on line 2
- `date` - Date only
- `time` - Time only
- `difference` - Time span from now (hh:mm:ss)

**Use with:** Label for timestamps, ETA, elapsed time

---

## Zone to Color

Maps SignalK zone state to colors.

**Zone mappings:**
- Normal / Nominal → Green
- Warning → Orange
- Alert / Critical / Emergency → Red

**Arguments:**
- Translucent option for semi-transparent colors

**Important:** Bind to a COLOR property, not the value!

**Example setup:**
1. Bind Value to `electrical.batteries.house.voltage`
2. Bind Stroke Color to same path WITH Zone to Color converter
3. Now bar color changes based on SignalK zones

---

## JSON Template

Extract and format data from complex JSON objects.

**Syntax:** `{{propertyName}}` to extract values

**Special tokens:**
- `{{$newline}}` - Line break

**Example:**
```
Input: { "latitude": 45.123, "longitude": -122.456 }
Template: Lat: {{latitude}}{{$newline}}Lon: {{longitude}}
Output:
Lat: 45.123
Lon: -122.456
```

**Use for:**
- Complex JSON paths with multiple values
- Custom formatting of structured data
- Extracting nested properties

---

## Using Converters

### In Binding Dialog

1. Select SignalK path
2. Enable "Converter" toggle
3. Choose converter from dropdown
4. Set arguments if available
5. Preview result

### Multiple Conversions

Only one converter per binding. For complex transformations:
1. Use JSON Template to extract/format
2. Or create custom SignalK plugin to pre-process data

---

## Offset and Multiply

Simple math transformations (not technically converters but available in binding).

**Offset:** Add/subtract from value
```
Value = 273.15 (Kelvin)
Offset = -273.15
Result = 0 (Celsius)
```

**Multiply:** Scale value
```
Value = 5.144 (m/s)
Multiply = 1.944
Result = 10 (knots)
```

**Note:** SKipper auto-converts SI units based on metric/imperial setting. Manual offset/multiply needed only for special cases.

---

## Unit Conversion

SKipper automatically converts SignalK SI units:

| SignalK (SI) | Metric | Imperial |
|--------------|--------|----------|
| Kelvin | Celsius | Fahrenheit |
| m/s | km/h | knots/mph |
| meters | meters | feet |
| radians | degrees | degrees |
| Pascals | hPa/mbar | inHg |

Unit conversion happens automatically based on:
1. Global metric/imperial setting
2. Per-control unit override

You can override units per control in the binding properties.
