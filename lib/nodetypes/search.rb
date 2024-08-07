# Copyright Vespa.ai. All rights reserved.

class Search

  attr_accessor :searchnode, :fbench

  def initialize(testcase, vespa)
    @testcase = testcase
    @vespa = vespa
    @searchnode = {}
    @fbench = {}
  end

  def empty?
      @searchnode.empty? &&
      @fbench.empty?
  end

  def wait_until_ready(timeout=90)
    @testcase.output("Waiting for search cluster to be ready")
    wait_until_searchnodes_ready(timeout)
  end

  def adjust_timeout(timeout)
    if @testcase.valgrind
      timeout *= 5
      @testcase.output("using timeout #{timeout} with valgrind")
    elsif @testcase.has_active_sanitizers
      timeout *= 5
      @testcase.output("using timeout #{timeout} with sanitizers")
    else
      @testcase.output("using timeout #{timeout}, no valgrind")
    end
    timeout
  end

  # Returns the first searchnode in the search cluster
  def first
    searchnode[0]
  end

  def wait_until_searchnodes_ready(timeout)
    if searchnode.size < 1
      return
    end
    node = first
    cl = node.cluster
    @testcase.output("Waiting for #{@searchnode.size} searchnodes in cluster '#{cl}'...")
    endtime = Time.now.to_i + adjust_timeout(timeout.to_i)
    while Time.now.to_i < endtime
      names, specs = @vespa.slobrok["0"].lookup_rpc_server(node.feed_destination)
      if names != nil && specs.size >= @searchnode.size
        @testcase.output("#{specs.size} searchnodes ready.")
        return true
      end
      sleep 0.1
    end
    raise "Timeout while waiting for searchnodes to become ready."
  end

  def add_service(remote_serviceobject)
    if not remote_serviceobject
      return
    end

    if remote_serviceobject.servicetype == "searchnode"
      @searchnode[remote_serviceobject.num] = remote_serviceobject
    #elsif remote_serviceobject.servicetype == "qrserver"
    #  @qrserver[remote_serviceobject.index] = remote_serviceobject
    elsif remote_serviceobject.servicetype == "fbench"
      @fbench[remote_serviceobject.index] = remote_serviceobject
    end
  end

  def to_s
    repr_string = ""
    searchnode.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    fbench.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    return repr_string.chomp
  end

end


