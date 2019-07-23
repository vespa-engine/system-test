# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Search

  attr_accessor :topleveldispatch, :searchnode, :fbench

  def initialize(testcase, vespa)
    @testcase = testcase
    @vespa = vespa
    @topleveldispatch = {}
    @searchnode = {}
    @fbench = {}
  end

  def empty?
    @topleveldispatch.empty? &&
      @searchnode.empty? &&
      @fbench.empty?
  end

  def wait_until_ready(timeout=90)
    @testcase.output("Waiting for search cluster to be ready")
    wait_until_searchnodes_ready(timeout)
    wait_until_topleveldispatch_ready(timeout)
  end

  def adjust_timeout(timeout)
    if @testcase.valgrind
      timeout *= 5
      @testcase.output("using timeout #{timeout} with valgrind")
    else
      @testcase.output("using timeout #{timeout}, no valgrind")
    end
    timeout
  end

  # Returns the first searchnode in the search cluster
  def first
    searchnode[0]
  end

  # Returns the first tld in the search cluster
  def first_tld
    topleveldispatch["0"]
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

  def wait_until_topleveldispatch_ready(timeout)
    @topleveldispatch.each_value { |topleveldispatch| topleveldispatch.wait_until_ready(timeout) }
  end

  def add_service(remote_serviceobject)
    if not remote_serviceobject
      return
    end

    if remote_serviceobject.servicetype == "topleveldispatch"
      # remote_serviceobject.index for a tld is per container cluster, so we might get overlapping indexes
      # when there are more than one container cluster. Add tld by starting from latest unused index
      new_index = "#{@topleveldispatch.length}"
      @topleveldispatch[new_index] = remote_serviceobject
    elsif remote_serviceobject.servicetype == "searchnode"
      @searchnode[remote_serviceobject.num] = remote_serviceobject
    #elsif remote_serviceobject.servicetype == "qrserver"
    #  @qrserver[remote_serviceobject.index] = remote_serviceobject
    elsif remote_serviceobject.servicetype == "fbench"
      @fbench[remote_serviceobject.index] = remote_serviceobject
    end
  end

  def to_s
    repr_string = ""
    topleveldispatch.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    searchnode.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    fbench.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    return repr_string.chomp
  end

end


