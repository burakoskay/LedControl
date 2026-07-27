# LED Control

LED Control is a native macOS menu-bar app for controlling a WS2812B LED strip
through an Arduino-compatible USB serial connection.

The app supports solid colors, custom presets, brightness control, and Rainbow,
Breathing, Fire, Chase, Gradient, and Color Cycle effects. Everything runs
locally; there are no accounts, analytics, or network services.

## Requirements

- macOS 13 or later
- Xcode 16 or later
- Arduino Uno or a compatible AVR board
- WS2812B strip and the FastLED 3.10.3 library

## Hardware

The included firmware defaults to 128 LEDs on Arduino pin 6 and limits the strip
to 3,000 mA. Adjust `NUM_LEDS`, `DATA_PIN`, `COLOR_ORDER`, and `MAX_POWER_MA` in
`Firmware/LEDController/LEDController.ino` for your installation.

Do not power a full strip from the Arduino's 5 V pin. Use a correctly rated,
fused 5 V supply, connect the supply ground to Arduino ground, add power
injection where required, and place a 300–500 Ω resistor on the data line. A
large capacitor across the strip's power input and a 5 V logic-level shifter are
recommended. Disconnect power before rewiring.

## Setup

1. Install FastLED 3.10.3 from Arduino Library Manager.
2. Upload `Firmware/LEDController/LEDController.ino` to the Arduino.
3. Open `LedControl.xcodeproj` in Xcode and run the `LedControl` scheme.
4. Open the lightbulb menu-bar icon, choose **Serial Ports**, and select the
   Arduino.

The app verifies the `LEDCTRL,1` firmware handshake before enabling controls, so
it will not silently send commands to unrelated serial devices.

Command-line firmware upload for an Arduino Uno:

```sh
arduino-cli core install arduino:avr@1.8.7
arduino-cli lib install FastLED@3.10.3
arduino-cli compile --fqbn arduino:avr:uno Firmware/LEDController
arduino-cli upload --fqbn arduino:avr:uno --port /dev/cu.usbmodemXXXX Firmware/LEDController
```

Replace the example port with the device shown by `arduino-cli board list`.

## Build and test

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Tools/verify.sh
```

If Xcode is already selected with `xcode-select`, omit `DEVELOPER_DIR`.

## Serial protocol

Commands are ASCII lines at 9,600 baud. Firmware replies to `HELLO` with
`LEDCTRL,1`. Supported commands include `OFF`, effect names, `SPEED,0..100`,
`BRIGHTNESS,0..100`, `COLOR,R,G,B`, and `brightness,R,G,B`.

## Project layout

```text
LedControl/          macOS application source
Firmware/            Arduino firmware
ORSSerialPort/       vendored ORSSerialPort 2.1.0 source and license
LedControlTests/     protocol unit tests
Tools/               local verification script
```

## License

LED Control is available under the MIT License. See `LICENSE` and
`THIRD_PARTY_NOTICES.md`.
