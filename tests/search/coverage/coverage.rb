# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Coverage < IndexedOnlySearchTest

  NUM_DOCUMENTS = 200_000

  def setup
    set_owner("boeker")
  end

  def create_app(schema_file)
    SearchApp.new.sd(selfdir + "coverage.sd")

    topgroup = NodeGroup.new(0, "mytopgroup").distribution("*") # Use "1|*" for multiple groups
    nodegroup = NodeGroup.new(0, "mygroup0")
    nodegroup.node(NodeSpec.new("node1", 0))
    nodegroup.node(NodeSpec.new("node1", 1))
    nodegroup.node(NodeSpec.new("node1", 2))
    topgroup.group(nodegroup)
    #nodegroup2 = NodeGroup.new(1, "mygroup1")
    #nodegroup2.node(NodeSpec.new("node1", 2))
    #nodegroup2.node(NodeSpec.new("node1", 3))
    #topgroup.group(nodegroup2)

    SearchApp.new
             .search_dir(selfdir + "search")
             .cluster(SearchCluster.new("mycluster")
                                       .sd(schema_file)
                                       .redundancy(2)
                                       .ready_copies(1)
                                       .group(topgroup))
  end

  def test_coverage_when_stopping_node
    set_description("Check reported coverage when a node in a group is stopped")
    deploy_app(create_app(selfdir + "coverage.sd"))

    @container = get_container
    compile_document_generator
    start

    feed_and_wait("coverage", NUM_DOCUMENTS, 2048)

    search_and_print

    search_cluster = vespa.search.values.first
    assert_equal(3, search_cluster.searchnode.length)

    first_searchnode = search_cluster.searchnode.values.first
    puts "Stopping searchnode #{first_searchnode}"
    first_searchnode.stop

    600.times do
      search_and_print
      sleep 0.2
    end

    puts "Starting searchnode #{first_searchnode}"
    first_searchnode.start

    600.times do
      search_and_print
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
