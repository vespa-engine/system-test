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

  def get_proton_config(memory, disk, enumstore, multivalue)
    ConfigOverride.new("vespa.config.search.core.proton").
      add("writefilter", ConfigValue.new("memorylimit", memory)).
      add("writefilter", ConfigValue.new("disklimit", disk)).
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("enumstorelimit", enumstore))).
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("multivaluelimit",
                                          multivalue))).
      add("writefilter", ConfigValue.new("sampleinterval", 2.0))
  end

  def get_cluster_controller_config(memory, disk, enumstore, multivalue)
    ConfigOverride.new("vespa.config.content.fleetcontroller").
      add("enable_cluster_feed_block", true).
      add(MapConfig.new("cluster_feed_block_limit").
          add("memory", memory).
          add("disk", disk).
          add("attribute-enum-store", enumstore).
          add("attribute-multi-value", multivalue))
  end

  def redeploy_app(memory, disk, enumstore, multivalue)
    proton_cfg = @block_feed_in_distributor ?
      get_proton_config(1.0, 1.0, 1.0, 1.0) : get_proton_config(memory, disk, enumstore, multivalue)
    controller_cfg = @block_feed_in_distributor ?
      get_cluster_controller_config(memory, disk, enumstore, multivalue) : get_cluster_controller_config(1.0, 1.0, 1.0, 1.0)

    redeploy(get_app.config(proton_cfg).config(controller_cfg), @cluster_name)
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
