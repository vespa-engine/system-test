# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class WriteFilterBase < IndexedSearchTest

  def setup
    set_owner("toregge")
    srand(123)
    @doc_type = "writefilter"
    @namespace = "writefilter"
    @cluster_name = "writefilter"
    @id_prefix = "id:test:#{@doc_type}::"
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
      sd(selfdir + "writefilter.sd").num_parts(@num_parts).redundancy(@num_parts).ready_copies(1).enable_http_gateway
  end

  def get_configoverride(memorylimit, disklimit, enumstorelimit, multivaluelimit)
    ConfigOverride.new("vespa.config.search.core.proton").
      add("writefilter", ConfigValue.new("memorylimit", memorylimit)).
      add("writefilter", ConfigValue.new("disklimit", disklimit)).
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("enumstorelimit", enumstorelimit))).
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("multivaluelimit",
                                          multivaluelimit))).
      add("writefilter", ConfigValue.new("sampleinterval", 2.0))
  end

  def redeploy_app(memorylimit, disklimit, enumstorelimit, multivaluelimit)
    redeploy(get_app.config(get_configoverride(memorylimit, disklimit, enumstorelimit, multivaluelimit)),
             @cluster_name)
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
