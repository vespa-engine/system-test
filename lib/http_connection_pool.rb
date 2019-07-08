# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'net/http'
require 'thread'

class Connection

  def initialize(key, host, port)
    @key = key
    @connection = Net::HTTP.new(host, port)
    @connection.start
  end

  def getKey()
    return @key
  end

  def getConnection()
    return @connection
  end
end

class HttpConnectionPool

  def initialize
    @connections = {}
    @mutex = Mutex.new
  end

  def acquire(host, port)
    key = host + ":" + port.to_s
    connection = nil
    @mutex.synchronize do
      if @connections.has_key?(key)
        available = @connections[key]
        if ! available.empty?
          connection = available.pop
        end
      end
    end
    if ! connection
      connection = Connection.new(key, host, port)
    end
    return connection
  end

  def release(connection)
    key = connection.getKey
    @mutex.synchronize do
      if ! @connections.has_key?(key)
        @connections[key] = Array.new
      end
      @connections[key].push(connection)
    end
  end

end
