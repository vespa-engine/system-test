# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'
require 'app_generator/http'

class FeedBlockBase < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    @doc_type = "test"
    @namespace = "test"
    @cluster_name = "test"
    @id_prefix = "id:test:#{@doc_type}::"
    @block_feed_in_distributor = false
    @sleep_delay = 12
    @num_parts = 1
    @disable_log_query_and_result = true
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
      container(Container.new.
                search(Searching.new).
                component(AccessLog.new("disabled")).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new).
                http(Http.new.server(Server.new("node1", vespa.default_document_api_port)))).
      sd(selfdir + "test.sd").num_parts(@num_parts).redundancy(@num_parts).ready_copies(1)
  end

  def get_proton_config(address_space)
    ConfigOverride.new("vespa.config.search.core.proton").
      add("writefilter",
          ConfigValue.new("attribute",
                          ConfigValue.new("address_space_limit", address_space))).
      add("writefilter", ConfigValue.new("sampleinterval", 2.0))
  end

  def get_cluster_controller_config(address_space)
    ConfigOverride.new("vespa.config.content.fleetcontroller").
      add("enable_cluster_feed_block", true).
      add(MapConfig.new("cluster_feed_block_limit").
          add("attribute-address-space", address_space))
  end

  def get_filestor_config(reporter_noise_level)
    ConfigOverride.new("vespa.config.content.stor-filestor").
      add("resource_usage_reporter_noise_level", reporter_noise_level)
  end

  def set_proton_limits(search_cluster, memory, disk, address_space)
    cfg = get_proton_config(address_space)
    search_cluster.config(cfg)
    search_cluster.proton_resource_limits(ResourceLimits.new.memory(memory).disk(disk))
  end

  def set_cluster_controller_limits(app, search_cluster, memory, disk, address_space)
    cfg = get_cluster_controller_config(address_space)
    app.config(cfg)
    search_cluster.resource_limits(ResourceLimits.new.memory(memory).disk(disk))
  end

  # TODO: change signature when config for cluster controller is simplified
  def set_resource_limits(app, search_cluster, memory, disk, address_space, reporter_noise_level = nil)
    if @block_feed_in_distributor
      set_proton_limits(search_cluster, 1.0, 1.0, 1.0)
      set_cluster_controller_limits(app, search_cluster, memory, disk, address_space)
    else
      set_proton_limits(search_cluster, memory, disk, address_space)
      set_cluster_controller_limits(app, search_cluster, 1.0, 1.0, 1.0)
    end
    if reporter_noise_level != nil
      search_cluster.config(get_filestor_config(reporter_noise_level))
    end
  end

  # TODO: change signature when config for cluster controller is simplified
  def redeploy_app(memory, disk, address_space)
    app = get_app
    set_resource_limits(app, app, memory, disk, address_space)

    redeploy(app, @cluster_name)
    sample_sleep(' after reconfig')
  end

  def http_v1_api_post(http, url, body, headers)
    response = http.post(url, body, headers)
    puts "response.code is #{response.code} response.body is #{response.body}"
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
