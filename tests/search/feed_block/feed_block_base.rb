# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class FeedBlockBase < IndexedSearchTest

  def setup
    set_owner("toregge")
    srand(123)
    @doc_type = "test"
    @namespace = "test"
    @cluster_name = "test"
    @id_prefix = "id:test:#{@doc_type}::"
    @block_feed_in_distributor = false
    @sleep_delay = 12
    @num_parts = 1
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def timeout_seconds
    1800
  end

  def qrserver
    vespa.container.values.first
  end

  def sample_sleep(msgend = '')
    puts "Sleep #{@sleep_delay} seconds to ensure resources sampled#{msgend}"
    sleep @sleep_delay
  end

  def get_app
    SearchApp.new.cluster_name(@cluster_name).
      sd(selfdir + "test.sd").num_parts(@num_parts).redundancy(@num_parts).ready_copies(1).enable_http_gateway
  end

  def get_proton_config(enumstore, multivalue)
    ConfigOverride.new("vespa.config.search.core.proton").
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("enumstorelimit", enumstore))).
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("multivaluelimit",
                                          multivalue))).
      add("writefilter", ConfigValue.new("sampleinterval", 2.0))
  end

  def get_cluster_controller_config(enumstore, multivalue)
    ConfigOverride.new("vespa.config.content.fleetcontroller").
      add("enable_cluster_feed_block", true).
      add(MapConfig.new("cluster_feed_block_limit").
          add("attribute-enum-store", enumstore).
          add("attribute-multi-value", multivalue))
  end

  def get_filestor_config(reporter_noise_level)
    ConfigOverride.new("vespa.config.content.stor-filestor").
      add("resource_usage_reporter_noise_level", reporter_noise_level)
  end

  def set_proton_limits(app, memory, disk, enumstore, multivalue)
    cfg = get_proton_config(enumstore, multivalue)
    app.config(cfg)
    app.proton_resource_limits(ResourceLimits.new.memory(memory).disk(disk))
  end

  def set_cluster_controller_limits(app, memory, disk, enumstore, multivalue)
    cfg = get_cluster_controller_config(enumstore, multivalue)
    app.config(cfg)
    app.resource_limits(ResourceLimits.new.memory(memory).disk(disk))
  end

  def set_resource_limits(app, memory, disk, enumstore, multivalue, reporter_noise_level = nil)
    if @block_feed_in_distributor
      set_proton_limits(app, 1.0, 1.0, 1.0, 1.0)
      set_cluster_controller_limits(app, memory, disk, enumstore, multivalue)
    else
      set_proton_limits(app, memory, disk, enumstore, multivalue)
      set_cluster_controller_limits(app, 1.0, 1.0, 1.0, 1.0)
    end
    if reporter_noise_level != nil
      app.config(get_filestor_config(reporter_noise_level))
    end
  end

  def redeploy_app(memory, disk, enumstore, multivalue)
    app = get_app
    set_resource_limits(app, memory, disk, enumstore, multivalue)

    redeploy(app, @cluster_name)
    sample_sleep(' after reconfig')
  end

  def http_v1_api_post(http, url, body, headers)
    response = http.post(url, body, headers)
    puts "response.code is #{response.code}"
    puts "response.body is #{response.body}"
    return response
  end

  def get_node(idx)
    vespa.content_node(@cluster_name, idx)
  end

  def get_cluster
    vespa.storage[@cluster_name]
  end

  def get_cluster_state
    get_cluster.get_cluster_state
  end

  def settle_cluster_state(check_states = "ui")
    clusterstate = get_cluster_state
    get_cluster.wait_for_cluster_state_propagate(clusterstate, 300,
                                                 check_states)
  end

  def teardown
    stop
  end

end
