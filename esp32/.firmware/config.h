#pragma once

// ── CAN IDs ───────────────────────────────────────────────────────────────────
#define CAN_ID_STW_ACTN_RQ    0x045u  // 69   - STW_ACTN_RQ:  steering stalk (Legacy follow distance)
#define CAN_ID_TRIP_PLANNING  0x082u  // 130  - UI_tripPlanning: precondition trigger
#define CAN_ID_BMS_HV_BUS     0x132u  // 306  - BMS_hvBusStatus: pack voltage / current
#define CAN_ID_BMS_SOC        0x292u  // 658  - BMS_socStatus:   state of charge
#define CAN_ID_BMS_THERMAL    0x312u  // 786  - BMS_thermalStatus: battery temp
#define CAN_ID_GTW_CAR_STATE  0x318u  // 792  - GTW_carState:    OTA detection
#define CAN_ID_EPAS_STATUS    0x370u  // 880  - EPAS3P_sysStatus: nag killer target
#define CAN_ID_GTW_CAR_CONFIG 0x398u  // 920  - GTW_carConfig:   HW version detection
#define CAN_ID_ISA_SPEED      0x399u  // 921  - ISA speed limit:  HW4 chime suppress
#define CAN_ID_AP_LEGACY      0x3EEu  // 1006 - DAS_autopilot:   Legacy / HW1 / HW2
#define CAN_ID_FOLLOW_DIST    0x3F8u  // 1016 - DAS_followDistance: speed profile source
#define CAN_ID_AP_CONTROL     0x3FDu  // 1021 - DAS_autopilotControl: HW3 / HW4 core

// ── GPIO pin mapping ─────────────────────────────────────────────────────────
#if defined(ARDUINO_ARCH_ESP8266)
// NodeMCU v2 (ESP8266) + MCP2515 SPI CAN module.
//
// ESP8266 has no native CAN peripheral, so only the MCP2515 driver is usable
// here.  HSPI pins are fixed in silicon; only CS is configurable.  We pick D1
// (GPIO5) for CS to avoid bootstrap pins (GPIO0/2/15).
//
// There is no TWAI TX/RX pin on this board, so PIN_CAN_TX / PIN_CAN_RX are
// intentionally omitted — the TWAI driver cannot be selected on ESP8266.
#define PIN_LED       2   // D4, onboard blue LED (active-LOW)
#define PIN_BUTTON    0   // D3, onboard FLASH button (active-LOW, pull-up)

// MCP2515 SPI (HSPI) — SCK/MISO/MOSI are hardwired on ESP8266
#define PIN_MCP_CS    5   // D1 — safe non-bootstrap pin
#define PIN_MCP_SCK  14   // D5 — HSPI SCK (fixed)
#define PIN_MCP_MISO 12   // D6 — HSPI MISO (fixed)
#define PIN_MCP_MOSI 13   // D7 — HSPI MOSI (fixed)

#else
// M5Stack ATOM Lite + ATOMIC CAN Base (CA-IS3050G) — default ESP32 mapping
#define PIN_CAN_TX   22   // TWAI TX → ATOMIC CAN Base TX
#define PIN_CAN_RX   19   // TWAI RX ← ATOMIC CAN Base RX
#define PIN_LED      27   // SK6812 NeoPixel (single LED)
#define PIN_BUTTON   39   // Built-in button, active-LOW (no external pull-up needed)

// MCP2515 SPI — only used in CAN_DRIVER_MCP2515 build (generic ESP32)
// Standard VSPI pins: SCK=18, MISO=19, MOSI=23, CS=5
#define PIN_MCP_CS   5
#define PIN_MCP_SCK  18
#define PIN_MCP_MISO 19
#define PIN_MCP_MOSI 23
#endif

// MCP2515 oscillator: common Chinese modules use 8 MHz
#define MCP_CRYSTAL_MHZ  MCP_8MHZ   // from autowp-mcp2515 CAN_CLOCK enum

// ── Timing ────────────────────────────────────────────────────────────────────
#define WIRING_WARN_MS        5000u   // Red LED / serial warning if no CAN after this
#define PRECOND_INTERVAL_MS    500u   // Re-inject 0x082 precondition every N ms
#define BMS_PRINT_MS          1000u   // BMS serial print interval
#define BUTTON_DEBOUNCE_MS      50u
#define LONG_PRESS_MS         3000u   // Long press → toggle NAG killer
#define DOUBLE_CLICK_MS        400u   // Max gap between two clicks for double-click
#define STATUS_PRINT_MS       5000u   // Periodic status line when Active
