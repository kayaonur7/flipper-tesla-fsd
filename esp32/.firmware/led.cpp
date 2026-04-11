#include "led.h"
#include "config.h"
#include <Arduino.h>

#if defined(ARDUINO_ARCH_ESP8266)
// ── NodeMCU (ESP8266): single active-LOW GPIO LED ────────────────────────────
//
// The onboard blue LED cannot render distinct colours, so we represent each
// LedColor with a time-based blink pattern.  Main.cpp calls led_set() from
// update_led() on every loop iteration, so the LED state converges quickly
// even without an explicit ticker.
//
//   LED_GREEN  = solid ON      (active mode)
//   LED_BLUE   = slow blink    (listen-only)
//   LED_YELLOW = medium blink  (OTA detected, TX suspended)
//   LED_RED    = fast blink    (error / no CAN traffic)
//   LED_OFF    = solid OFF

void led_init() {
    pinMode(PIN_LED, OUTPUT);
    digitalWrite(PIN_LED, HIGH);  // active-LOW → OFF
}

void led_set(LedColor color) {
    uint32_t period_ms = 0;
    uint32_t on_ms     = 0;

    switch (color) {
        case LED_GREEN:  period_ms = 0;    on_ms = 1;   break;  // solid on
        case LED_BLUE:   period_ms = 1000; on_ms = 500; break;  // 1 Hz 50%
        case LED_YELLOW: period_ms = 400;  on_ms = 200; break;  // 2.5 Hz 50%
        case LED_RED:    period_ms = 150;  on_ms = 75;  break;  // ~7 Hz 50%
        case LED_OFF:
        default:         period_ms = 0;    on_ms = 0;   break;  // solid off
    }

    bool on;
    if (period_ms == 0) {
        on = (on_ms != 0);
    } else {
        on = (millis() % period_ms) < on_ms;
    }
    // Active-LOW
    digitalWrite(PIN_LED, on ? LOW : HIGH);
}

#else
// ── ESP32: single SK6812/WS2812B NeoPixel ────────────────────────────────────
#include <Adafruit_NeoPixel.h>

// M5Stack ATOM Lite: single SK6812 (GRB order) on PIN_LED (GPIO27)
static Adafruit_NeoPixel g_strip(1, PIN_LED, NEO_GRB + NEO_KHZ800);

void led_init() {
    g_strip.begin();
    g_strip.setBrightness(25);  // keep dim — the ATOM LED is very bright
    g_strip.clear();
    g_strip.show();
}

void led_set(LedColor color) {
    uint32_t c;
    switch (color) {
        case LED_BLUE:   c = g_strip.Color(  0,   0, 255); break;
        case LED_GREEN:  c = g_strip.Color(  0, 255,   0); break;
        case LED_YELLOW: c = g_strip.Color(255, 200,   0); break;
        case LED_RED:    c = g_strip.Color(255,   0,   0); break;
        default:         c = 0;                             break;
    }
    g_strip.setPixelColor(0, c);
    g_strip.show();
}
#endif
