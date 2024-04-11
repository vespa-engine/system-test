# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_block_base'
require 'doc_generator'
require 'environment'

class FeedBlockDiskTwoNodesBase < FeedBlockBase

  @@DiskLimitResult = Struct.new("DiskLimitResult", :downnode, :upnode, :disklimit)

  def initialize(*args)
    super(*args)
    @maxage = 90
    @num_hosts = 2
    @debug_log_enabled = false
  end

  def setup(*args)
    super(*args)
    @valgrind = false
  end

  def timeout_seconds
    3000
  end

  def nodespec(nodeindex)
    assert(nodeindex < @num_hosts)
    nni = nodeindex + 1
    return NodeSpec.new("node#{nni}", nodeindex)
  end

  def create_group
    if @num_parts == 1
      return NodeGroup.new(0, "mytopgroup").
        node(nodespec(0))
    end
    assert(@num_parts == 2)
    NodeGroup.new(0, "mytopgroup").
      node(nodespec(0)).
      node(nodespec(1))
  end

  def get_sc
    SearchCluster.new(@cluster_name).
      sd(selfdir + "test.sd").
      num_parts(@num_parts).
      redundancy(1).
      indexing("default").
      ready_copies(1).
      group(create_group).
      tune_searchnode({ :flushstrategy => {:native => {:component => {:maxage => @maxage} } },
                        :summary => {:store => {:logstore => { :maxfilesize => @myuse / 10,
                                                               :chunk => {:compression => { :type => :none } }
                                                             } } }
                       })
  end

  def get_tls_configoverride
    ConfigOverride.new("searchlib.translogserver").
      add("filesizemax", 1000000)
  end

  def get_flush_configoverride
    ConfigOverride.new("vespa.config.search.core.proton").
      add("flush", ConfigValue.new("idleinterval", 1.0))
  end

  def get_hwinfo_disk_override(shared_disk)
    ConfigOverride.new("vespa.config.search.core.proton").
      add("hwinfo",
          ConfigValue.new("disk",
                          ConfigValue.new("shared", (shared_disk ? "true" : "false"))))
  end

  def get_app(search_cluster, shared_disk)
    SearchApp.new.cluster(search_cluster).
      num_hosts(@num_hosts).
      container(Container.new.
                search(Searching.new).
                component(AccessLog.new("disabled")).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new).
                http(Http.new.server(Server.new("node1", vespa.default_document_api_port)))).
      storage(StorageCluster.new(@cluster_name, 41)).
      config(get_tls_configoverride).
      config(get_flush_configoverride).
      config(get_hwinfo_disk_override(shared_disk))
  end

  def setup_strings
    num_strings = 10000
    puts "Generating #{num_strings} random strings"
    @strings = StringGenerator.rand_array(50, 50, num_strings)
    puts "Generated #{num_strings} random strings"
  end

  def select_strings
    retval = Array.new
    16000.times do
      retval.push(@strings[rand(@strings.size)])
    end
    retval
  end

  def strings_as_json(string_array)
    "[ \"" + string_array.join("\", \"") + "\" ]"
  end

  def get_resource_usage(idx)
    get_node(idx).get_state_v1_custom_component("/resourceusage")
  end

  def calculate_disk_limit(usage)
    diskusage = usage["disk"]["stats"]
    used = diskusage["used"].to_f
    capacity = diskusage["capacity"].to_f
    available = capacity - used
    assert(@myuse.to_f * 2 < available)
    1.to_f - (available - @myuse) / capacity
  end

  def http_v1_api_put_long(http, id)
    url = "/document/v1/#{@namespace}/#{@doc_type}/docid/#{id}"
    httpHeaders = {}
    jsonarray = strings_as_json(select_strings)
    puts "Putting doc with id #{id}"
    http_v1_api_post(http,
                     url,
                     "{ \"fields\": { \"a1\" : #{jsonarray} } }",
                     httpHeaders)
  end

  def reached_disklimit(response)
    if @block_feed_in_distributor
      response.code == "507" && response.body =~ /resource exhaustion: in content cluster 'test': disk on node /
    else
      response.code == "507" && response.body =~ /diskLimitReached/
    end
  end

  def sleep_with_reason(delay, reason)
    puts "Sleep #{delay} seconds#{reason}"
    sleep delay
  end

  def feed_until_failure(upnode)
    threadlist = []
    for i in 1..4
      id = i * 1000000 # Ensure id ranges are disjoint
      threadlist << Thread.new(id) do |my_id|
        feed_until_failure_thread(upnode, my_id)
      end
    end
    threadlist.each do |thread|
      thread.join
    end
    hit_count_query = "query=sddocname:test&nocache&model.searchPath=#{upnode}/0"
    hit_count = search(hit_count_query).hitcount
    puts "Failed at doccount #{hit_count}"
    hit_count
  end

  def feed_until_failure_thread(upnode, id)
    http = https_client.create_client(vespa.document_api_v1.host, vespa.document_api_v1.port)
    fails = 0
    flushedid = id - 1
    while fails < 2
      response = http_v1_api_put_long(http, id)
      if response.code == "200"
        fails = 0
        if id >= 200 + flushedid
          puts "Flushing to disk to ensure space used after put #{id}"
          get_node(upnode).trigger_flush
          flushedid = id
        end
        id = id + 1
      else
        fails = fails + 1
        if reached_disklimit(response)
          get_node(upnode).trigger_flush
        end
        sleep_with_reason(@sleep_delay, " to settle after failed put")
      end
    end
    assert(reached_disklimit(response))
    puts "Failed at id #{id}"
  end

  def feed_after_expansion()
    http = https_client.create_client(vespa.document_api_v1.host, vespa.document_api_v1.port)
    id = 0 # Range 0..1M
    20.times do
      response = http_v1_api_put_long(http, id)
      assert(response.code == "200")
      id = id + 1
    end
  end

  def perform_du(node_idx)
    puts "perform_du: node_idx=#{node_idx}"
    get_node(node_idx).execute("cd #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.test && date && hostname && df . && ( du || true )")
  end

  def calculate_myuse(shared_disk)
    if shared_disk
      @myuse = 320 * 1024 * 1024
    else
      # If the containers for this test use shared disks while the
      # argument shared_disk is false then this test is vulerable to
      # disk usage changes caused by other containers (e.g. other tests).
      @myuse = 1600 * 1024 * 1024
    end
  end

  def calculate_disklimit
    puts "Checking disk free on nodes"
    usage0 = get_resource_usage(0)
    disklimit0 = calculate_disk_limit(usage0)
    puts "Resource usage on node 0 is #{usage0}"
    puts "Suggested limit based on node 0 is #{disklimit0}"
    perform_du(0)
    usage1 = get_resource_usage(1)
    disklimit1 = calculate_disk_limit(usage1)
    puts "Resource usage on node 1 is #{usage1}"
    puts "Suggested limit based on node 1 is #{disklimit1}"
    perform_du(1)
    if (disklimit0 < disklimit1)
      result = @@DiskLimitResult.new(0, 1, disklimit1)
    else
      result = @@DiskLimitResult.new(1, 0, disklimit0)
    end
    result
  end

  def redeploy_with_reduced_disk_limit(disklimit, shared_disk)
    puts "Redeploying with reduced disk limit"
    search_cluster = get_sc
    app = get_app(search_cluster, shared_disk)
    set_resource_limits(app, search_cluster, 1.0, disklimit, 1.0, 0.0)
    redeploy(app)
    sleep_with_reason(@sleep_delay, " to allow new config to propagate")
    settle_cluster_state("uimrd")
  end

  def stop_node_to_be_down_during_initial_feeding(downnode)
    puts "Stopping content node #{downnode} to run in degraded mode with only 1 node up"
    get_node(downnode).stop
    sleep_with_reason(@sleep_delay, " to allow content node #{downnode} to stop")
    settle_cluster_state("uir")
  end

  def start_node_that_was_down_during_initial_feeding(downnode)
    get_node(downnode).start
    sleep_with_reason(@sleep_delay, " to allow content node #{downnode} to start")
    settle_cluster_state("uir")
  end

  def mostly_settle_document_redistribution(upnode, num_docs)
    hit_count_query = "query=sddocname:test&nocache&model.searchPath=#{upnode}/0"
    hit_count = search(hit_count_query).hitcount
    puts "num docs = #{num_docs},  hit count = #{hit_count}"
    hit_count_settle_limit = num_docs / 2 + 100
    while hit_count >= hit_count_settle_limit
      sleep_with_reason(@sleep_delay, ", waiting for node #{upnode} hit count (currently #{hit_count}) to be less than #{hit_count_settle_limit}")
      perform_du(0)
      perform_du(1)
      hit_count = wait_for_not_hitcount(hit_count_query, hit_count, 180, 0)
    end
    puts "Node #{upnode} hit count is now #{hit_count}"
    perform_du(upnode)
    sleep_with_reason(@maxage, " to trigger maxage flushing")
    perform_du(upnode)
    sleep_with_reason(90, " to allow 8-9 summary compaction rounds")
    perform_du(upnode)
  end

  def enable_debug_logging
    vespa.search["test"].searchnode.each_value do |proton|
      proton.logctl2("persistence.filestor.service_layer_host_info_reporter", "all=on")
      proton.logctl2("state.manager", "all=on")
    end
    vespa.storage["test"].distributor.each_value do |distributor|
      distributor.logctl2("state.manager", "all=on")
    end
  end

  def run_feed_block_document_v1_api_two_nodes_disklimit_test(shared_disk)
    @num_parts = 2
    setup_strings
    calculate_myuse(shared_disk)
    deploy_app(get_app(get_sc, shared_disk))
    start
    enable_debug_logging if @debug_log_enabled
    disklimit = calculate_disklimit
    redeploy_with_reduced_disk_limit(disklimit.disklimit, shared_disk)
    stop_node_to_be_down_during_initial_feeding(disklimit.downnode)
    num_docs = feed_until_failure(disklimit.upnode)
    perform_du(disklimit.upnode)
    start_node_that_was_down_during_initial_feeding(disklimit.downnode)
    mostly_settle_document_redistribution(disklimit.upnode, num_docs)
    puts "Feeding again after effective expansion from 1 to 2 nodes"
    feed_after_expansion()
  end

end
