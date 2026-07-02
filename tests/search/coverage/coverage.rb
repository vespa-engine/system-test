# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Coverage < IndexedOnlySearchTest

  NUM_DOCUMENTS = 100_000
  NUM_GROUPS = 2
  NUM_NODES_PER_GROUP = 2

  def setup
    set_owner("boeker")
  end

  def create_app(schema_file, num_groups, num_nodes_per_group)
    SearchApp.new.sd(selfdir + "coverage.sd")

    if num_groups > 1
      distribution = "1|*"
    else
      distribution = "*"
    end
    topgroup = NodeGroup.new(0, "mytopgroup").distribution(distribution)
    distkey = 0
    for g in 1..num_groups do
      nodegroup = NodeGroup.new(g-1, "mygroup#{g-1}")
      for n in 1..num_nodes_per_group do
        nodegroup.node(NodeSpec.new("node1", distkey))
        distkey = distkey + 1
      end
      topgroup.group(nodegroup)
    end

    SearchApp.new
             .search_dir(selfdir + "search")
             .cluster(SearchCluster.new("mycluster")
                                       .sd(schema_file)
                                       .redundancy(num_groups)
                                       .ready_copies(num_groups)
                                       .min_active_docs_coverage(90.0)
                                       .group(topgroup))
  end

  def test_coverage_when_stopping_node
    set_description("Check reported coverage when a node in a group is stopped")
    deploy_app(create_app(selfdir + "coverage.sd", NUM_GROUPS, NUM_NODES_PER_GROUP))

    @container = get_container
    compile_document_generator
    start

    feed_and_wait("coverage", NUM_DOCUMENTS, 2048)

    search_and_print

    search_cluster = vespa.search.values.first
    assert_equal(NUM_GROUPS * NUM_NODES_PER_GROUP, search_cluster.searchnode.length)

    first_searchnode = search_cluster.searchnode.values.first
    puts "Stopping searchnode #{first_searchnode}"
    first_searchnode.stop

    300.times do
      search_and_print
      puts "Searchnode was stopped"
      sleep 0.2
    end

    puts "Starting searchnode #{first_searchnode}"
    first_searchnode.start

    300.times do
      search_and_print
      puts "Searchnode was started again"
      sleep 0.2
    end
  end

  def search_and_print
    query = {
      "yql" => "select * from sources * where ({targetHits:100}nearestNeighbor(tensor_field, q_v))",
      "input.query(q_v)" => "#{[0.0] * 2048}",
      "summary" => "minimal",
      "hits" => "1"
    }
    result = search(query)
    puts JSON.pretty_generate(result.json)
  end

  def wait_for_documents(name, num_documents)
    puts "Waiting for #{num_documents} hits"
    wait_for_atleast_hitcount("query=sddocname:#{name}", num_documents)
    puts "Waited for #{num_documents} hits"
  end

  def feed_and_wait(name, num_documents, num_dimensions)
    puts "Feeding documents"
    @container.execute("#{@tmp_bin_dir}/docs #{name} #{num_documents} #{num_dimensions} | vespa-feed-perf")
    wait_for_documents(name, num_documents)
  end

  def compile_document_generator
    @tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -g -O3 -o #{@tmp_bin_dir}/docs #{selfdir}docs.cpp")
  end

  def get_container
    vespa.qrserver["0"] or vespa.container.values.first
  end


end
