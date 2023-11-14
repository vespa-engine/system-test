# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Packet

  attr_accessor :pcode, :req_id, :data, :host_order, :no_reply

  RPC_REQUEST = 100
  RPC_REPLY = 101
  RPC_ERROR = 102

  def host_order=(native)
    @host_order = native
    if (native) then
      @short_char = 'S'
      @int_char = 'L'
      @float_char = 'e'
      @double_char = 'E'
    else
      @short_char = 'n'
      @int_char = 'N'
      @float_char = 'g'
      @double_char = 'G'
    end
  end

  def initialize
    @pcode = 0
    @req_id = 0
    self.host_order = false
    @no_reply = false
    @data = ""
  end

  def read(io)
    data = io.read(4)
    if (data and data.length == 4)
      p_len = data.unpack('N')[0]
      data = io.read(p_len)
      if (data and data.length == p_len)
        @data = ""
        flags, @pcode, @req_id, @data = data.unpack('nnNa*')
        self.host_order = (flags[0] == 1)
        @no_reply = (flags[1] == 1)
        return true
      end
    end
    raise RuntimeError, "missing data reading RPC-packet from socket"
  end

  def to_s
    p_len = @data.length + 8
    flags = 0
    flags += 1 if @host_order
    flags += 2 if @no_reply
    [ p_len, flags, @pcode, @req_id].pack('NnnN') + @data
  end

  protected
  def serialize(type, val)
    case type
    when 'b' then [val].pack('C')
    when 'h' then [val].pack(@short_char)
    when 'i' then [val].pack(@int_char)
    when 'l' then [val >> 32, val & 0xffffffff].pack(@int_char + @int_char)
    when 'f' then [val].pack(@float_char)
    when 'd' then [val].pack(@double_char)
    when 's' then [val.length, val].pack(@int_char + 'a*')
    when 'x' then [val.length, val].pack(@int_char + 'a*')
    end
  end

  def deserialize(type, str)
    case type
    when 'b' then str.slice!(0,1).unpack('C')[0]
    when 'h' then str.slice!(0,2).unpack(@short_char)[0]
    when 'i' then str.slice!(0,4).unpack(@int_char)[0]
    when 'l' then str.slice!(0,4).unpack(@int_char)[0] << 32 + str.slice!(0,4).unpack(@int_char)[0]
    when 'f' then str.slice!(0,4).unpack(@float_char)[0]
    when 'd' then str.slice!(0,8).unpack(@double_char)[0]
    when 's' then str.slice!(0, str.slice!(0,4).unpack(@int_char)[0])
    when 'x' then str.slice!(0, str.slice!(0,4).unpack(@int_char)[0])
    end
  end
end


class CommandPacket < Packet
  def initialize(in_types, method)
    super()
    @in_types = in_types
    @method = method
    @pcode = RPC_REQUEST
    @data = [@method.length,@method].pack('Na*')
  end


  def parameters=(params)
    @data = [@method.length, @method].pack('Na*')
    @data += [@in_types.length, @in_types].pack('Na*')
    @in_types.each_char do |c|
      case
      when "bhilfdsx".include?(c)
        @data += serialize(c, params.slice!(0))
      when "BHILFDSX".include?(c)
        array = params.slice!(0)
        @data += [array.size].pack(@int_char)
        array.each { |val| data += serialize(c.downcase, val) }
      end
    end
  end

  def method
    data = @data.dup
    data.slice!(0, data.slice!(0,4).unpack(@int_char)[0])
  end

  attr_writer :in_types

  def parameters
    data = @data.dup
    data.slice!(0, data.slice!(0,4).unpack(@int_char)[0]) # method=
    data.slice!(0, data.slice!(0,4).unpack(@int_char)[0]) # intypes=
    params=[]
    @in_types.each_char do |c|
      case
      when "bhilfdsx".include?(c)
        params << deserialize(c, data)
      when "BHILFDSX".include?(c)
        size = data.slice!(0,4).unpack(@int_char)[0]
        arr = []
        size.times { arr << deserialize(c.downcase, data) }
        params << arr
      end
    end
    params
  end
end


class ReplyPacket < Packet
  def initialize(out_types, cmd)
    super()
    @out_types = out_types
    @pcode = RPC_REPLY
    @req_id = cmd.req_id
  end
  def ret_values=(out_types, values)
    @data = [@out_types.length, @out_types].pack(@int_char + 'a*')
    @out_types.each_char do |c|
      case
      when "bhilfdsx".include?(c)
        @data += serialize(c, values.slice!(0))
      when "BHILFDSX".include?(c)
        array = values.slice!(0)
        @data += [array.size].pack(@int_char)
        array.each { |val| @data += serialize(c.downcase, val) }
      end
    end
  end

  def ret_values
    data = @data.dup
    ret=[]
    type_length = data.slice!(0,4).unpack(@int_char)[0]
    types = data.slice!(0, type_length) # outtypes=
    @out_types.each_char do |c|
      case
      when "bhilfdsx".include?(c)
        ret << deserialize(c, data)
      when "BHILFDSX".include?(c)
        size = data.slice!(0,4).unpack(@int_char)[0]
        arr = []
        size.times { arr << deserialize(c.downcase, data) }
        ret << arr
      end
    end
    ret
  end
end

if __FILE__ == $0

  require 'test/unit'
  require 'stringio'

  class PacketTest < Test::Unit::TestCase
    def test_serialize
      in_packet = Packet.new
      in_packet.pcode = 100
      in_packet.req_id = 1000
      in_packet.data = "Tjohei"
      in_packet.no_reply = true
      in_packet.host_order = false

      serialized = in_packet.to_s

      out_packet = Packet.new
      out_packet.read(StringIO.new(serialized))

      assert_equal(in_packet.pcode, out_packet.pcode)
      assert_equal(in_packet.req_id, out_packet.req_id)
      assert_equal(in_packet.data, out_packet.data)
      assert_equal(in_packet.no_reply, out_packet.no_reply)
      assert_equal(in_packet.host_order, out_packet.host_order)

      File.open("packet.txt", "w") { |f| f << serialized }
    end

  end

end
