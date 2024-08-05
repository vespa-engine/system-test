# Copyright Vespa.ai. All rights reserved.
class SearchNode < VespaNode

  attr_accessor :num
  attr_reader :feed_destination

  def initialize(*args)
    super(*args)
    @num = @service_entry["num"]
    @feed_destination = @service_entry["feed-destination"]
  end

  def use_min_config_generation
    return true
  end

  def rpc_port
    @ports_by_tag["rpc"]
  end
  def trigger_flush
    output = `vespa-proton-cmd #{rpc_port} triggerFlush 2>&1`.chomp
    testcase.output(output)
  end

  def prepare_restart
    output = `vespa-proton-cmd #{rpc_port} prepareRestart 2>&1`.chomp
    testcase.output(output)
  end

  def get_state
    output = `vespa-proton-cmd #{rpc_port} getState 2>&1`.chomp
    testcase.output(output)
    output
  end

  def get_proton_status
    output = `vespa-proton-cmd #{rpc_port} getProtonStatus 2>&1`.chomp
    testcase.output(output)
    output
  end

  def get_state_v1_custom_component(path = "")
    get_state_v1("custom/component" + path)
  end

  def stop(force = false)
    ret = Sentinel.new(@testcase, tls_env()).stop_service(service, 50, force)
    dumpPStack unless ret
    return ret
  end

end
