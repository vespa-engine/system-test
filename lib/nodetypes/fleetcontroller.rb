# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Fleetcontroller < VespaNode
  @fleetcontroller = nil

  def init
    @statusport = @ports[0]
    @rpc_port = @ports[1]
    retries = 30*4
    if testcase.valgrind
      retries = retries * 5
      testcase.output("using #{retries} retries with valgrind")
    elsif testcase.has_active_sanitizers
      retries = retries * 5
      testcase.output("using #{retries} retries with sanitizers")
    else
      testcase.output("using #{retries} retries, no valgrind")
    end
#    if (!@fleetcontroller) then
      begin
        testcase.output("Connecting to fleetctrl at localhost:#{@rpc_port}")
        @fleetcontroller = RpcWrapper.new("localhost", @rpc_port, tls_env())
      rescue RuntimeError => e
        testcase.output("Failed to talk to RPC server: #{e.to_s}")
      rescue SystemCallError => e
 	testcase.output(e.message)
        retries = retries - 1
        if retries <= 0
          raise "Timeout while waiting for fleetcontroller."
        else
          sleep 0.5
          retry
        end
#      end
    end
  end

  def get_status_page(page = "/")
    10.times { |i|
      begin
        _, data = https_get('localhost', @statusport, page)
        return data
      rescue Exception => e
        if (i > 8)
          raise e
        else
          sleep 0.5
        end
      end
    }
  end

  def set_node_state(nodetype, index, state)
    init

    servername = "storage/cluster." + cluster + "/#{nodetype}/#{index}"

    testcase.output(servername)
    testcase.output(state)
    @fleetcontroller.setNodeState(servername, state)
  end

  def get_system_state
    init
    begin
      garbage, system = @fleetcontroller.getSystemState()
      #system.gsub!(/\s+\.\d+\.t:\d+/, '')
      return system
    rescue RuntimeError => e
        testcase.output("Failed to talk to RPC server: #{e.to_s}")
    end
  end

  def get_system_state_without_version
    init
    system = get_system_state()
    array = system.split(/\s+/)
    if (array[0] =~ /^version/) then
      array.shift
    end
    # Shouldn't really be removed, but lets remove it until we can configure cluster up
    # requirements
    if (array[0] =~ /^cluster/) then
      array.shift
    end
    return array.join(" ")
  end

  def wait_for_stable_system
    init
    garbage = ""
    system = ""
    lastsystem = "none at all"
    retries = 1500
    if testcase.valgrind
      retries = retries * 5
      testcase.output("using #{retries} retries with valgrind")
    elsif testcase.has_active_sanitizers
      retries = retries * 5
      testcase.output("using #{retries} retries with sanitizers")
    else
      testcase.output("using #{retries} retries, no valgrind")
    end

    begin
      garbage, system = @fleetcontroller.getSystemState()
      #system.gsub!(/\s+\.\d+\.t:\d+/, '')
      testcase.output("System state: ")
      testcase.output(system)
    rescue Exception => e
      system = "failed RPC request: #{e}"
      puts system
    end

    # Should also check for cluster:d state, but removing for now as we can't configure when to
    # be down yet
    while (system != lastsystem || system.index(".s:i") != nil || system.index("distributor") == nil || system.index("storage") == nil)
      retries = retries - 1
      testcase.output("retries: #{retries}")
      if retries <= 0
        raise "Timeout while waiting for stable system in fleetcontroller."
      end
      sleep 0.5
      lastsystem = system
      begin
        garbage, system = @fleetcontroller.getSystemState()
        #system.gsub!(/\s+\.\d+\.t:\d+/, '')
        testcase.output("System state: ")
        testcase.output(system)
      rescue Exception => e
        system = "failed RPC request: #{e}"
        puts system
      end
    end
    testcase.output("System is stable with state " + system + "\n")
  end

  def do(command, exceptiononfailure = true)
    res = execute(command + " --port #{ports[0]}", :exceptiononfailure => exceptiononfailure)
    arr = res.split("\n")
    arr.shift() # Remove "Connecting to fleetctrl" line
    out = arr.join("\n")
    return out
  end

end
