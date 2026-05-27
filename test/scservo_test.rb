require "test_helper"

class EncodeDecodeWordTest < Test::Unit::TestCase
  def setup
    @servo = SCServo.new(FakeUART.new, id: 1)
  end

  def test_encode_word_big_endian
    assert_equal [0x01, 0x2C], @servo.send(:encode_word, 300)
  end

  def test_encode_word_masks_to_u16
    assert_equal [0xFF, 0xFF], @servo.send(:encode_word, 0x1FFFF)
  end

  def test_decode_word_combines_hi_lo
    assert_equal 300, @servo.send(:decode_word, 0x01, 0x2C)
  end
end

class WritePosFrameTest < Test::Unit::TestCase
  def test_write_pos_emits_goal_position_frame
    uart = FakeUART.new
    servo = SCServo.new(uart, id: 1)
    ack_cksum = (~(1 + 2 + 0)) & 0xFF
    uart.queue_rx([0xFF, 0xFF, 0x01, 0x02, 0x00, ack_cksum])

    servo.write_pos(300, time_ms: 0, speed: 0)

    sent = uart.written.bytes
    assert_equal [0xFF, 0xFF], sent[0, 2]   # HEADER
    assert_equal 0x01, sent[2]              # ID
    assert_equal 9,    sent[3]              # LEN = params(7) + 2
    assert_equal 0x03, sent[4]              # INSTR_WRITE
    assert_equal 0x2A, sent[5]              # REG_GOAL_POS_L
    assert_equal [0x01, 0x2C], sent[6, 2]   # pos 300 big-endian
    body_sum = sent[2, sent.length - 3].inject(0) { |a, b| a + b }
    assert_equal (~body_sum) & 0xFF, sent.last
  end
end

class EnableTorqueFrameTest < Test::Unit::TestCase
  def test_enable_torque_emits_torque_register_frame
    uart = FakeUART.new
    servo = SCServo.new(uart, id: 1)
    ack_cksum = (~(1 + 2 + 0)) & 0xFF
    uart.queue_rx([0xFF, 0xFF, 0x01, 0x02, 0x00, ack_cksum])

    servo.enable_torque(true)

    sent = uart.written.bytes
    assert_equal 0x03, sent[4]  # INSTR_WRITE
    assert_equal 0x28, sent[5]  # REG_TORQUE
    assert_equal 0x01, sent[6]  # on
  end
end
