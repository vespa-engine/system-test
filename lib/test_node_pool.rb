# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'drb'
require 'socket'
require 'node_proxy'
require 'test_base'

class TestNodeFailure < StandardError
end

class TestNodePool
  include DRb::DRbUndumped

  def initialize(logger)
    @log = logger
    @nodes = []
    @lock = Mutex.new
    @max_available_nodes = 0

    addr = ":#{TestBase::DRUBY_NODE_POOL_PORT}"
    endpoint = DrbEndpoint.new(addr)
    endpoint.start_service(for_object: self)
    uri = URI.parse(DRb.current_server.uri)

    @log.debug "Node allocator endpoint: #{uri.host}:#{uri.port} (#{endpoint.secure? ? 'secure' : 'INSECURE'})"

    node_allocator_up = false
    endtime = Time.now.to_i + 10

    while Time.now.to_i < endtime
      begin
        TCPSocket.new("127.0.0.1", TestBase::DRUBY_NODE_POOL_PORT).close
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

  def register_node_server(hostname, port, parent)
    @lock.synchronize do
      @nodes << "#{hostname}" unless @nodes.include?("#{hostname}")
      @max_available_nodes = @nodes.size if @nodes.size > @max_available_nodes
      @log.info "Registered node server on: #{hostname}:#{port} (parent #{parent}). Available nodes count is #{@nodes.size}."
    end
  end

  def max_available
    @lock.synchronize do
      return @max_available_nodes
    end
  end

  def allocate(num, timeout_sec = 0)
    if num > max_available
      raise "Requested #{num} nodes, but max number of available nodes is #{max_available}."
    end

    endtime = Time.now.to_i + timeout_sec
    while timeout_sec <= 0 || Time.now.to_i < endtime
      allocated, num_free = allocate_required_or_none(num)

      if allocated.size == num
        @log.debug("Allocated #{num} nodes. Available nodes count is #{num_free}.")
        return allocated
      end

      sleep(3)
    end

    raise "Requested #{num} nodes, but could not allocate within #{timeout_sec} seconds."
  end

  def all_alive?(nodes)
    nodes.each do |node|
      begin
        endpoint = DrbEndpoint.new("#{node}:#{TestBase::DRUBY_REMOTE_PORT}")
        node_server = endpoint.create_client(with_object: nil)
        raise "Node #{node} is dead." unless node_server.alive?
      rescue StandardError => e
        @log.warn("Exception: #{e.message}")
        return false
      end
    end
    true
  end

  def free(nodes)
    nodes.each do |node|
      begin
        TCPSocket.new(node, TestBase::DRUBY_REMOTE_PORT).close
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
        @log.warn "Unable to free node at #{node}:#{TestBase::DRUBY_REMOTE_PORT} due to connection failure. Node will be dangling and not used in further tests."
        next
      end

      begin
        endpoint = DrbEndpoint.new("#{node}:#{TestBase::DRUBY_REMOTE_PORT}")
        node_server = endpoint.create_client(with_object: nil)
        @log.debug "Freeing node server. Calling shutdown on #{node}:#{TestBase::DRUBY_REMOTE_PORT}"
        node_server.shutdown
      rescue DRb::DRbConnError => e
        # The node server will shut down and lead to a connection error
      end
    end
  end

  private

  def allocate_required_or_none(num)
    @lock.synchronize do
      allocated = @nodes.shift(num)
      if allocated.size == num
        [allocated, @nodes.size]
      else
        @nodes.concat(allocated)
        [[], @nodes.size]
      end
    end
  end

end

