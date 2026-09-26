require 'uart'

class SCServo
  HEADER          = [0xFF, 0xFF].freeze

  INSTR_READ      = 0x02
  INSTR_WRITE     = 0x03

  REG_MODE          = 0x21
  REG_TORQUE        = 0x28
  REG_GOAL_POS_L    = 0x2A
  REG_PRESENT_POS_L = 0x38

  READ_TIMEOUT_MS = 100

  CHECKHEAD_MAX_SKIP = 10

  def initialize(uart, id:)
    @uart = uart
    @id   = id
  end

  def write_pos(pos, time_ms: 0, speed: 0)
    pos_enc   = encode_word(pos)
    time_enc  = encode_word(time_ms)
    speed_enc = encode_word(speed)
    data = [REG_GOAL_POS_L,
            pos_enc[0],   pos_enc[1],
            time_enc[0],  time_enc[1],
            speed_enc[0], speed_enc[1]]
    gen_write(data)
  end

  def read_pos
    3.times do
      result = read_pos_once
      return result unless result.nil?
    end
    nil
  end

  def enable_torque(on = true)
    value = on ? 0x01 : 0x00
    gen_write([REG_TORQUE, value])
  end

  def set_mode(mode)
    value = case mode
            when :position then 0x00
            when :pwm      then 0x01
            else raise ArgumentError, "unknown mode: #{mode.inspect}"
            end
    gen_write([REG_MODE, value])
  end

  private

  def read_pos_once
    @uart.clear_rx_buffer
    send_packet(INSTR_READ, [REG_PRESENT_POS_L, 0x02])
    @uart.flush
    return nil unless check_head
    body_header = read_bytes(3, READ_TIMEOUT_MS)
    return nil if body_header.nil?
    id_byte  = body_header.bytes[0]
    len_byte = body_header.bytes[1]
    err_byte = body_header.bytes[2]
    return nil if id_byte != @id
    return nil if len_byte != (2 + 2)
    data = read_bytes(2, READ_TIMEOUT_MS)
    return nil if data.nil?
    cksum_byte = read_bytes(1, READ_TIMEOUT_MS)
    return nil if cksum_byte.nil?
    calc_sum = id_byte + len_byte + err_byte
    data.bytes.each { |b| calc_sum += b }
    expected = (~calc_sum) & 0xFF
    return nil if cksum_byte.bytes[0] != expected
    decode_word(data.bytes[0], data.bytes[1])
  end

  def gen_write(params)
    @uart.clear_rx_buffer
    send_packet(INSTR_WRITE, params)
    @uart.flush
    ack
  end

  def send_packet(instr, params)
    length = params.length + 2
    body = [@id, length, instr] + params
    sum  = body.inject(0) { |acc, b| acc + b }
    cksum = (~sum) & 0xFF
    packet = HEADER + body + [cksum]
    @uart.write(packet.pack('C*'))
  end

  def check_head
    last = 0
    skipped = 0
    while skipped <= CHECKHEAD_MAX_SKIP
      byte = read_bytes(1, READ_TIMEOUT_MS)
      return false if byte.nil?
      b = byte.bytes[0]
      return true if last == 0xFF && b == 0xFF
      last = b
      skipped += 1
    end
    false
  end

  def ack
    return true if @id == 0xFE
    return false unless check_head
    body = read_bytes(4, READ_TIMEOUT_MS)
    return false if body.nil?
    bytes = body.bytes
    return false if bytes[0] != @id
    return false if bytes[1] != 2
    calc = (bytes[0] + bytes[1] + bytes[2]) & 0xFF
    expected = (~calc) & 0xFF
    bytes[3] == expected
  end

  def read_bytes(n, timeout_ms)
    deadline = (Machine.uptime_us / 1000) + timeout_ms
    buf = ""
    while buf.bytesize < n
      chunk = @uart.readpartial(n - buf.bytesize)
      if chunk && !chunk.empty?
        buf << chunk
      else
        return nil if (Machine.uptime_us / 1000) > deadline
        Machine.delay_ms(1)
      end
    end
    buf
  end

  def encode_word(v)
    v &= 0xFFFF
    [(v >> 8) & 0xFF, v & 0xFF]
  end

  def decode_word(hi, lo)
    ((hi & 0xFF) << 8) | (lo & 0xFF)
  end
end
