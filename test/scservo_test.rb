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
    assert_equal [0xFF, 0xFF], sent[0, 2]
    assert_equal 0x01, sent[2]
    assert_equal 9,    sent[3]
    assert_equal 0x03, sent[4]
    assert_equal 0x2A, sent[5]
    assert_equal [0x01, 0x2C], sent[6, 2]
    body_sum = sent[2, sent.length - 3].inject(0) { |a, b| a + b }
    assert_equal (~body_sum) & 0xFF, sent.last
  end

  def test_write_pos_encodes_time_and_speed_fields
    uart = FakeUART.new
    servo = SCServo.new(uart, id: 1)
    ack_cksum = (~(1 + 2 + 0)) & 0xFF
    uart.queue_rx([0xFF, 0xFF, 0x01, 0x02, 0x00, ack_cksum])

    servo.write_pos(300, time_ms: 500, speed: 200)

    sent = uart.written.bytes
    assert_equal [0x01, 0x2C], sent[6, 2]
    assert_equal [0x01, 0xF4], sent[8, 2]
    assert_equal [0x00, 0xC8], sent[10, 2]
  end
end

class NoClearFakeUART < FakeUART
  def clear_rx_buffer; end
end

class ReadPosErrorTrackingTest < Test::Unit::TestCase
  def test_last_read_error_is_no_header_on_timeout_with_no_bytes
    uart = NoClearFakeUART.new
    servo = SCServo.new(uart, id: 1)

    servo.send(:read_pos_once)

    assert_equal :no_header, servo.last_read_error
    assert_nil servo.last_status
  end

  def test_last_read_error_is_checksum_on_bad_checksum
    uart = NoClearFakeUART.new
    servo = SCServo.new(uart, id: 1)
    uart.queue_rx([0xFF, 0xFF, 0x01, 0x04, 0x00, 0x01, 0x2C, 0x00])

    servo.send(:read_pos_once)

    assert_equal :checksum, servo.last_read_error
    assert_nil servo.last_status
  end

  def test_last_status_is_set_from_nonzero_status_byte_on_good_reply
    uart = NoClearFakeUART.new
    servo = SCServo.new(uart, id: 1)
    data = [0x01, 0x2C]
    err_byte = 0x20
    calc_sum = 1 + 4 + err_byte + data[0] + data[1]
    cksum = (~calc_sum) & 0xFF
    uart.queue_rx([0xFF, 0xFF, 0x01, 0x04, err_byte, data[0], data[1], cksum])

    result = servo.send(:read_pos_once)

    assert_equal 300, result
    assert_nil servo.last_read_error
    assert_equal 0x20, servo.last_status
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
    assert_equal 0x03, sent[4]
    assert_equal 0x28, sent[5]
    assert_equal 0x01, sent[6]
  end

  def test_enable_torque_false_emits_zero
    uart = FakeUART.new
    servo = SCServo.new(uart, id: 1)
    ack_cksum = (~(1 + 2 + 0)) & 0xFF
    uart.queue_rx([0xFF, 0xFF, 0x01, 0x02, 0x00, ack_cksum])

    servo.enable_torque(false)

    sent = uart.written.bytes
    assert_equal 0x00, sent[6]
  end
end
