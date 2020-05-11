# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'drb'
require 'socket'
require 'node_proxy'
require 'test_base'

class TestNodePool
  include DRb::DRbUndumped

  class TestNode
    attr_reader :hostname
    def initialize(hostname)
      @hostname = hostname
    end
  end

  def initialize(logger)
    @log = logger
    @hosts = []
    @lock = Mutex.new
    @max_available_nodes = 0

    addr = ":#{TestBase::DRUBY_REMOTE_PORT}"
    endpoint = DrbEndpoint.new(addr)
    endpoint.start_service(for_object: self)
    uri = URI.parse(DRb.current_server.uri)

    @log.debug "Node allocator endpoint: #{uri.host}:#{uri.port} (#{endpoint.secure? ? 'secure' : 'INSECURE'})"

    node_allocator_up = false
    endtime = Time.now.to_i + 10

    while Time.now.to_i < endtime
      begin
        TCPSocket.new("127.0.0.1", TestBase::DRUBY_REMOTE_PORT).close
        node_allocator_up = true
        break
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      end
      sleep 2
    end

    if ! node_allocator_up
      raise "Could not connect to node allocator at #{uri.host}:#{uri.port}"
    end
  end

  def register_node_server(hostname, port)
    @lock.synchronize do
      @hosts << "#{hostname}" unless @hosts.include?("#{hostname}")
      @max_available_nodes = @hosts.size if @hosts.size > @max_available_nodes
      @log.info "Registered node server on: #{hostname}:#{port}"
    end
  end

  def max_available
    @lock.synchronize do
      return @max_available_nodes
    end
  end

  def allocate(num)
    @lock.synchronize do
      nodes = []
      if num <= @hosts.size
        while nodes.size < num && @hosts.size > 0
          # Should test the node connection here
          nodes << @hosts.shift
        end
      end

      if nodes.size == num
        nodes.map { |n| TestNode.new(n) }
      else
        [] 
      end
    end
  end

  def free(nodes)
    nodes.each do |node|
      begin
        TCPSocket.new("#{node.hostname}", TestBase::DRUBY_REMOTE_PORT).close
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        @log.warn "Unable to free node at #{node.hostname}:#{TestBase::DRUBY_REMOTE_PORT} due to connection failure. Node will be dangling and not used in further tests."
        return
      end

      begin
        endpoint = DrbEndpoint.new("#{node.hostname}:#{TestBase::DRUBY_REMOTE_PORT}")
        node_server = endpoint.create_client(with_object: nil)
        @log.debug "Freeing node server. Calling shutdown on #{node.hostname}:#{TestBase::DRUBY_REMOTE_PORT}"
        node_server.shutdown
      rescue DRb::DRbConnError => e
        # The node server will shut down and lead to a connection error
      end
    end
  end
end

