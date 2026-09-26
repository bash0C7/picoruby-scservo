# picoruby-scservo — Repo-Local Rules for Claude Code

This is a **PicoRuby Runtime Gem** (pure Ruby, no C extension).
Mirrors github.com/m5stack/StackChan FTServo_Arduino (SCS.cpp + SCSCL.cpp).

## Public API contract — DO NOT BREAK

- `SCServo.new(uart, id:)`
- `write_pos(pos, time_ms: 0, speed: 0)` — move to absolute position (0-4095)
- `read_pos` — returns unsigned position or nil (retries up to 3 times)
- `enable_torque(on = true)` — torque enable/disable
- `set_mode(mode)` — `:position` or `:pwm`

## Protocol implementation notes

UART1 TX does not echo onto RX on StackChan, so the status packet follows a write or read request directly.

### Key constants (verified against mrblib/scservo.rb)

- `READ_TIMEOUT_MS = 100` — per-byte poll budget (generous vs. <1ms at 1Mbps)
- `CHECKHEAD_MAX_SKIP = 10` — max bytes scanned before giving up on 0xFF 0xFF header
- `REG_TORQUE = 0x28` (SCSCL_TORQUE_ENABLE = 40)
- `REG_GOAL_POS_L = 0x2A` (SCSCL_GOAL_POSITION_L = 42)
- `REG_PRESENT_POS_L = 0x38` (SCSCL_PRESENT_POSITION_L = 56)

### Wire encoding

Position and speed/time are big-endian u16 (`encode_word`/`decode_word`).
`write_pos` bundles POS(2) + TIME(2) + SPEED(2) in a single INSTR_WRITE to
REG_GOAL_POS_L (6 data bytes + 1 register address = 7 params, LEN = 9).

### read_pos retry semantics

`read_pos` retries up to 3 times on any failure (timeout, id mismatch,
length mismatch, checksum mismatch). Each attempt calls `clear_rx_buffer`
before sending the READ packet. Return `nil` only after all attempts
are exhausted.

## PicoRuby compatibility

Per `~/CLAUDE.md`, **avoid** these in `mrblib/*.rb`:

- `defined?` (use `Object.const_defined?(:Sym)` instead)
- `Hash#fetch`
- `String#reverse`, `String#rjust`
- inline `rescue`
- `proc`, `lambda`

## picoruby-uart on-device API pitfalls

When wiring this driver to a real UART on ESP32:

- **Unit symbols**: use `:ESP32_UART0`, `:ESP32_UART1`, or `:ESP32_UART2`.
  Passing `:UART1` or similar causes a silent Guru Meditation crash.
- **`write` argument must be String**: convert byte arrays with
  `array.pack('C*')` before calling `uart.write(...)`. Passing an Array
  raises `TypeError`.
- **`read(n)` ignores timeout_ms**: use `readpartial(n)` and roll your own
  poll loop. `SCServo#read_bytes` already does this correctly using
  `Machine.uptime_us` as the deadline clock.

## On-device require name

The gem is named `picoruby-scservo` in the build config, but on-device
the `picoruby-` prefix is stripped:

```ruby
require 'scservo'   # correct
require 'picoruby-scservo'  # LoadError on device
```

## Tests

Host-side characterization tests: `bundle exec rake test`

These are **characterization tests** — they pin the existing wire protocol
behavior. The source of truth is `mrblib/scservo.rb`. If a test
expectation and the implementation diverge, fix the test expectation
(recompute from the implementation), never modify `mrblib/scservo.rb`
to match a test.

## Git

- Conventional Commits: `feat` / `fix` / `docs` / `test` / `refactor` / `chore`.
- Imperative mood, English only.
- No comments. Code carries How, tests carry What (the test name), commit log carries Why. Keep only what the toolchain reads (magic comments, type annotations, rigor/steep directives).
