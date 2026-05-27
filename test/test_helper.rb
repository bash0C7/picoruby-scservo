require "test/unit"

# PicoRuby shim: 'uart' is a runtime built-in; no-op the require under CRuby.
$LOADED_FEATURES << "uart" unless $LOADED_FEATURES.include?("uart")

# scservo の read_bytes は Machine.uptime_us / delay_ms に依存する。
# NOTE: Machine.reset! must be called in setup for any test that exercises the
# read_bytes timeout path (current tests don't, but future ones will).
unless defined?(Machine)
  module Machine
    @@offset_us = 0
    def self.uptime_us; @@offset_us; end
    def self.delay_ms(ms); @@offset_us += ms * 1_000; end
    def self.reset!; @@offset_us = 0; end
  end
end

# write を記録し、queue_rx で仕込んだ応答 bytes を readpartial で返す UART モック。
class FakeUART
  attr_reader :written
  def initialize
    @written = +""
    @rx = +""
  end
  def queue_rx(bytes)
    @rx << bytes.pack("C*")
    self
  end
  def write(str)
    @written << str
    str.bytesize
  end
  def flush; end
  def clear_rx_buffer
    @rx = +""
  end
  def readpartial(n)
    return nil if @rx.empty?
    chunk = @rx.byteslice(0, n)
    @rx = @rx.byteslice(chunk.bytesize..) || +""
    chunk
  end
end

require "scservo"
