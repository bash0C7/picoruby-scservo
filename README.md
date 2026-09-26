# picoruby-scservo

PicoRuby UART driver for FEETECH SCServo SCSCL-series smart servos.
Mirrors the [m5stack/StackChan FTServo_Arduino reference](https://github.com/m5stack/StackChan/tree/main/firmware/main/hal/drivers) (SCS.cpp + SCSCL.cpp) byte-for-byte.

## Dependency

Requires [picoruby-uart](https://github.com/picoruby/picoruby-uart).
`picoruby-uart` ships with R2P2-ESP32 as a PicoRuby built-in — no separate install needed.

## Public API

| Method | Description |
|---|---|
| `SCServo.new(uart, id: N)` | Create instance. `uart` is a picoruby-uart UART object; `id` is the servo hardware ID (1-253, 0xFE = broadcast). |
| `write_pos(pos, time_ms: 0, speed: 0)` | Move to position `pos` (0-4095). `time_ms` = move duration; `speed` = max speed (0 = max). |
| `read_pos` | Read current position (0-4095 unsigned). Retries up to 3 times; returns `nil` on failure. |
| `enable_torque(on = true)` | Enable (`true`) or disable (`false`) torque. |
| `set_mode(mode)` | `:position` (default) or `:pwm`. |

## Usage example

```ruby
require 'uart'
require 'scservo'

uart = UART.new(
  unit: :ESP32_UART1,
  txd_pin: 6,
  rxd_pin: 7,
  baudrate: 1_000_000
)

servo = SCServo.new(uart, id: 1)

servo.enable_torque(true)
servo.write_pos(2048, time_ms: 500, speed: 0)   # center, 500ms
pos = servo.read_pos
puts pos.inspect
```

Note: keyword arguments must be written in full (`time_ms: 500`) — PicoRuby does not support bare shorthand kwargs.

## Installation

In your `build_config/*.rb`:

```ruby
conf.gem github: 'bash0C7/picoruby-scservo'
```

On-device require name (strip the `picoruby-` prefix):

```ruby
require 'scservo'
```

## License

MIT
