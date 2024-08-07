# Copyright Vespa.ai. All rights reserved.


class StorageMessage
  @@last_id = 2222

  def initialize
    @msg_type = -1
    @@last_id += 1
    @id = @@last_id
    @local_id = 0
  end

  def serialize
    [@msg_type, @id, @local_id].pack('LQL')
  end

  def deserialize(buf)
    @msg_type, @id, @local_id = buf.slice!(0, 16).unpack('LQL')
  end

end

class StorageCommand < StorageMessage
  def initialize
    super
    @priority = 0
    @source_index = 0xFFFF
  end

  def serialize
    super + [@priority, @source_index].pack('LS')
  end
end

class StorageReply < StorageMessage
  attr_accessor :return_code, :return_str, :address

  def initialize
    super
    @return_code = 0
    @return_str = ""
    @address = ""
  end

  def deserialize(buf)
    super
    if (buf.slice!(0, 1).unpack('c') != 0) then
      @address = buf.slice!(0, buf.slice!(0,2).unpack('S')[0])
      puts "address = #{@address}"
    end
    @return_code = buf.slice!(0,4).unpack('L')[0]
    puts "returncode = #{@return_code}"
    @return_str = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
  end
end

class Parameters < Hash

  def serialize
    output = [size].pack('L')
    each { |key, value| output += [key.length, key, value.length, value].pack('La*La*') }
    output
  end

  def deserialize(buf)
    count = buf.slice!(0,4).unpack('L')[0]
    count.times do
      key = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
      value = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
      self[key] = value
    end
  end
end

class AdminCommand < StorageCommand
  attr_accessor :params

  def initialize
    super
    @params = Parameters.new
    @msg_type = 0
  end

  def serialize
    super + params.serialize
  end
end

class AdminReply < StorageReply
  attr_accessor :params, :data

  def initialize
    super
    @params = Parameters.new
    @data = ""
  end

  def deserialize(buf)
    super
    @params.deserialize(buf)
    @data = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
  end
end


class PingCommand < StorageCommand
  attr_accessor :data

  def initialize
    super
    @data = ""
    @msg_type = 12
  end

  def serialize
    super + [@data.length, @data].pack('La*')
  end
end

class PingReply < StorageReply
  attr_accessor :data

  def initialize
    super
    @data = ""
  end

  def deserialize(buf)
    super
    @data = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
  end
end

class StatusCommand < StorageCommand
  attr_accessor :n_status, :s_status

  def initialize
    super
    @n_status = ""
    @s_status = ""
    @msg_type = 44
  end

  def serialize
    super +
    [@n_status.length, @n_status].pack('La*') +
    [@s_status.length, @s_status].pack('La*')
  end
end

class StatusReply < StorageReply
  attr_accessor :n_status, :s_status

  def initialize
    super
    @n_status = ""
    @s_status = ""
  end

  def deserialize(buf)
    super
    @n_status = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
    @s_status = buf.slice!(0, buf.slice!(0,4).unpack('L')[0])
  end
end


