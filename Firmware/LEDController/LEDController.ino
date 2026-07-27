#include <FastLED.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#define NUM_LEDS 128
#define DATA_PIN 6
#define LED_TYPE WS2812B
#define COLOR_ORDER RGB

// Power limit in milliamps. Set to match your power supply.
// 128 LEDs at full white = ~7700mA. Recommended: 5V 10A supply.
// With a 3A supply, single colors work fine but white will be dimmed.
#define MAX_POWER_MA 3000

CRGB leds[NUM_LEDS];

// --- Modes ---
#define MODE_OFF          0
#define MODE_ON_WHITE     1
#define MODE_RAINBOW      2
#define MODE_CUSTOM_COLOR 3
#define MODE_BREATHING    4
#define MODE_FIRE         5
#define MODE_CHASE        6
#define MODE_GRADIENT     7
#define MODE_COLORCYCLE   8

int currentMode = MODE_OFF;

// Custom color + brightness state
byte customR = 255;
byte customG = 255;
byte customB = 255;
byte globalBrightness = 100; // 0-255 FastLED scale

// Breathing state
float breathPhase = 0.0;

// Fire state
byte heat[NUM_LEDS];
#define FIRE_COOLING  55
#define FIRE_SPARKING 120

// Chase state
int chaseOffset = 0;
unsigned long lastChaseUpdate = 0;

// Color cycle state
uint8_t cycleHue = 0;
unsigned long lastCycleUpdate = 0;

// Speed control: 0 = very slow (4x), 50 = normal, 100 = very fast (4x)
// Maps to a multiplier: speed 0 → 0.25x, speed 50 → 1.0x, speed 100 → 4.0x
byte speedFactor = 50;

// --- Serial buffer ---
const int MAX_COMMAND_LENGTH = 32;
char serialCommandBuffer[MAX_COMMAND_LENGTH];
byte commandLength = 0;

void setup() {
  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(100);
  // Limit total power draw to prevent voltage drop, flickering,
  // and color distortion at the far end of the strip
  FastLED.setMaxPowerInVoltsAndMilliamps(5, MAX_POWER_MA);
  Serial.begin(9600);
  Serial.println("LED Controller Ready");
}

void loop() {
  // --- Read serial ---
  while (Serial.available()) {
    char inChar = Serial.read();
    if (inChar == '\n' || inChar == '\r') {
      if (commandLength > 0) {
        serialCommandBuffer[commandLength] = '\0';
        processCommand(serialCommandBuffer);
        commandLength = 0;
      }
    } else if (commandLength < MAX_COMMAND_LENGTH - 1) {
      serialCommandBuffer[commandLength++] = inChar;
    }
  }

  // --- Render current mode ---
  switch (currentMode) {
    case MODE_OFF:
      fill_solid(leds, NUM_LEDS, CRGB::Black);
      FastLED.setBrightness(0);
      break;

    case MODE_ON_WHITE:
      fill_solid(leds, NUM_LEDS, CRGB::White);
      FastLED.setBrightness(globalBrightness);
      break;

    case MODE_RAINBOW:
      renderRainbow();
      FastLED.setBrightness(globalBrightness);
      break;

    case MODE_CUSTOM_COLOR:
      fill_solid(leds, NUM_LEDS, CRGB(customR, customG, customB));
      FastLED.setBrightness(globalBrightness);
      break;

    case MODE_BREATHING:
      renderBreathing();
      break;

    case MODE_FIRE:
      renderFire();
      FastLED.setBrightness(globalBrightness);
      break;

    case MODE_CHASE:
      renderChase();
      FastLED.setBrightness(globalBrightness);
      break;

    case MODE_GRADIENT:
      renderGradient();
      FastLED.setBrightness(globalBrightness);
      break;

    case MODE_COLORCYCLE:
      renderColorCycle();
      FastLED.setBrightness(globalBrightness);
      break;
  }

  FastLED.show();
  delay(20);
}

// ============================================================
// EFFECTS
// ============================================================

// Returns a speed multiplier: speed 0 → 0.25, speed 50 → 1.0, speed 100 → 4.0
// Uses exponential curve for perceptually linear feel
float getSpeedMultiplier() {
  // Map 0-100 to -2..+2 (log2 scale), then pow(2, x)
  // 0 → pow(2,-2) = 0.25x, 50 → pow(2,0) = 1.0x, 100 → pow(2,2) = 4.0x
  float normalized = (speedFactor - 50.0) / 25.0; // -2.0 to +2.0
  return pow(2.0, normalized);
}

void renderRainbow() {
  float mult = getSpeedMultiplier();
  unsigned long t = millis();
  // Default divisor 20; lower = faster. Scale inversely with speed.
  int divisor = max(1, (int)(20.0 / mult));
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CHSV((i * 255 / NUM_LEDS) + (t / divisor), 255, 255);
  }
}

void renderBreathing() {
  float mult = getSpeedMultiplier();
  breathPhase += 0.03 * mult;
  if (breathPhase > TWO_PI) breathPhase -= TWO_PI;

  // Sine oscillates 0.0 to 1.0
  float breath = (sin(breathPhase) + 1.0) / 2.0;
  // Scale brightness: min 5, max = globalBrightness (safe with any value)
  int maxB = max((int)globalBrightness, 5);
  int b = 5 + (int)(breath * (maxB - 5));
  b = constrain(b, 0, 255);

  fill_solid(leds, NUM_LEDS, CRGB(customR, customG, customB));
  FastLED.setBrightness((byte)b);
}

void renderFire() {
  float mult = getSpeedMultiplier();
  // Scale cooling with speed — faster = more cooling = more dynamic
  int cooling = (int)(FIRE_COOLING * mult);
  cooling = constrain(cooling, 20, 200);
  int sparking = (int)(FIRE_SPARKING * mult);
  sparking = constrain(sparking, 50, 240);

  for (int i = 0; i < NUM_LEDS; i++) {
    heat[i] = qsub8(heat[i], random8(0, ((cooling * 10) / NUM_LEDS) + 2));
  }

  for (int k = NUM_LEDS - 1; k >= 2; k--) {
    heat[k] = (heat[k - 1] + heat[k - 2] + heat[k - 2]) / 3;
  }

  if (random8() < (byte)sparking) {
    int y = random8(7);
    heat[y] = qadd8(heat[y], random8(160, 255));
  }

  // Mirror fire from both ends toward center
  int half = NUM_LEDS / 2;
  for (int j = 0; j < half; j++) {
    CRGB color = HeatColor(heat[j]);
    leds[j] = color;
    leds[NUM_LEDS - 1 - j] = color;
  }
}

void renderChase() {
  fadeToBlackBy(leds, NUM_LEDS, 80);

  for (int i = 0; i < NUM_LEDS; i++) {
    if ((i + chaseOffset) % 6 < 2) {
      leds[i] = CRGB(customR, customG, customB);
    }
  }

  float mult = getSpeedMultiplier();
  unsigned long interval = max(10UL, (unsigned long)(80.0 / mult));
  unsigned long now = millis();
  if (now - lastChaseUpdate >= interval) {
    chaseOffset = (chaseOffset + 1) % 6;
    lastChaseUpdate = now;
  }
}

void renderGradient() {
  float mult = getSpeedMultiplier();
  byte compR = 255 - customR;
  byte compG = 255 - customG;
  byte compB = 255 - customB;

  int divisor = max(1, (int)(30.0 / mult));
  unsigned long t = millis() / divisor;

  for (int i = 0; i < NUM_LEDS; i++) {
    byte pos = (byte)((i * 255 / NUM_LEDS) + t);
    byte blend = sin8(pos);

    byte r = lerp8by8(customR, compR, blend);
    byte g = lerp8by8(customG, compG, blend);
    byte b = lerp8by8(customB, compB, blend);
    leds[i] = CRGB(r, g, b);
  }
}

void renderColorCycle() {
  float mult = getSpeedMultiplier();
  unsigned long interval = max(5UL, (unsigned long)(40.0 / mult));
  unsigned long now = millis();
  if (now - lastCycleUpdate >= interval) {
    cycleHue++;
    lastCycleUpdate = now;
  }
  fill_solid(leds, NUM_LEDS, CHSV(cycleHue, 255, 255));
}

// ============================================================
// COMMAND PARSING
// ============================================================

bool parseInteger(const char* value, long minimum, long maximum, int* result) {
  if (value == NULL || result == NULL || *value == '\0') return false;

  char* end = NULL;
  long parsed = strtol(value, &end, 10);
  if (end == value || *end != '\0' || parsed < minimum || parsed > maximum) {
    return false;
  }

  *result = (int)parsed;
  return true;
}

void sendInvalidCommand() {
  Serial.println("ERR,INVALID_COMMAND");
}

void processCommand(char* cmd) {
  char cmdCopy[MAX_COMMAND_LENGTH];
  strncpy(cmdCopy, cmd, MAX_COMMAND_LENGTH - 1);
  cmdCopy[MAX_COMMAND_LENGTH - 1] = '\0';

  // Trim trailing whitespace
  size_t len = strlen(cmdCopy);
  while (len > 0 && isspace((unsigned char)cmdCopy[len - 1])) {
    cmdCopy[--len] = '\0';
  }

  char* token = strtok(cmdCopy, ",");
  if (token == NULL || strlen(token) == 0) return;

  // --- Named commands ---
  if (strcmp(token, "HELLO") == 0) {
    Serial.println("LEDCTRL,1");
  }
  else if (strcmp(token, "ON") == 0) {
    currentMode = MODE_ON_WHITE;
    Serial.println("Mode: White ON");
  }
  else if (strcmp(token, "OFF") == 0) {
    currentMode = MODE_OFF;
    Serial.println("Mode: OFF");
  }
  else if (strcmp(token, "RAINBOW") == 0) {
    currentMode = MODE_RAINBOW;
    Serial.println("Mode: Rainbow");
  }
  else if (strcmp(token, "BREATHING") == 0) {
    currentMode = MODE_BREATHING;
    breathPhase = 0.0;
    Serial.println("Mode: Breathing");
  }
  else if (strcmp(token, "FIRE") == 0) {
    currentMode = MODE_FIRE;
    memset(heat, 0, sizeof(heat));
    Serial.println("Mode: Fire");
  }
  else if (strcmp(token, "CHASE") == 0) {
    currentMode = MODE_CHASE;
    chaseOffset = 0;
    Serial.println("Mode: Chase");
  }
  else if (strcmp(token, "GRADIENT") == 0) {
    currentMode = MODE_GRADIENT;
    Serial.println("Mode: Gradient");
  }
  else if (strcmp(token, "COLORCYCLE") == 0) {
    currentMode = MODE_COLORCYCLE;
    cycleHue = 0;
    Serial.println("Mode: Color Cycle");
  }
  else if (strcmp(token, "SPEED") == 0) {
    char* val = strtok(NULL, ",");
    int parsed = 0;
    if (parseInteger(val, 0, 100, &parsed)) {
      speedFactor = (byte)parsed;
      Serial.print("Speed: "); Serial.println(speedFactor);
    } else {
      sendInvalidCommand();
    }
  }
  else if (strcmp(token, "BRIGHTNESS") == 0) {
    char* val = strtok(NULL, ",");
    int pct = 0;
    if (parseInteger(val, 0, 100, &pct)) {
      globalBrightness = map(pct, 0, 100, 0, 255);
      Serial.print("Brightness: "); Serial.println(pct);
    } else {
      sendInvalidCommand();
    }
  }
  else if (strcmp(token, "COLOR") == 0) {
    // COLOR,R,G,B — set the stored color without changing mode
    char* r_str = strtok(NULL, ",");
    char* g_str = strtok(NULL, ",");
    char* b_str = strtok(NULL, ",");
    int red = 0;
    int green = 0;
    int blue = 0;
    if (parseInteger(r_str, 0, 255, &red) &&
        parseInteger(g_str, 0, 255, &green) &&
        parseInteger(b_str, 0, 255, &blue)) {
      customR = (byte)red;
      customG = (byte)green;
      customB = (byte)blue;
      Serial.print("Color: RGB("); Serial.print(customR);
      Serial.print(","); Serial.print(customG);
      Serial.print(","); Serial.print(customB);
      Serial.println(")");
    } else {
      sendInvalidCommand();
    }
  }
  else {
    // Try B%,R,G,B format
    int brightness_pct = 0;
    if (parseInteger(token, 0, 100, &brightness_pct)) {
      char* r_str = strtok(NULL, ",");
      char* g_str = strtok(NULL, ",");
      char* b_str = strtok(NULL, ",");

      int red = 0;
      int green = 0;
      int blue = 0;
      if (parseInteger(r_str, 0, 255, &red) &&
          parseInteger(g_str, 0, 255, &green) &&
          parseInteger(b_str, 0, 255, &blue)) {
        customR = (byte)red;
        customG = (byte)green;
        customB = (byte)blue;
        globalBrightness = map(brightness_pct, 0, 100, 0, 255);
        currentMode = MODE_CUSTOM_COLOR;

        Serial.print("Custom: "); Serial.print(brightness_pct);
        Serial.print("% RGB("); Serial.print(customR);
        Serial.print(","); Serial.print(customG);
        Serial.print(","); Serial.print(customB);
        Serial.println(")");
      } else {
        sendInvalidCommand();
      }
    } else {
      sendInvalidCommand();
    }
  }
}
