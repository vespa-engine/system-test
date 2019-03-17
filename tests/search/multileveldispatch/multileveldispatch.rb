# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'search/utils/elastic_doc_generator'

class MultiLevelDispatchTest < SearchTest

  def setup
    set_owner("geirst")

    @num_docs = 500
    @num_hits = 20
    @valgrind = false
  end

  def timeout_seconds
    return 3000
  end

  def create_app(dispatch)
    SearchApp.new.cluster(
      SearchCluster.new("mycluster").sd(selfdir + "test.sd").
      dispatch(dispatch).redundancy(2).ready_copies(2).num_parts(6))
  end

  def create_implicit_dispatch
    Dispatch.new.num_dispatch_groups(2)
  end

  def create_explicit_dispatch
    Dispatch.new.group(DispatchGroup.new([0,1,2])).group(DispatchGroup.new([3,4,5]))
  end

  def generate_and_feed_docs
    docs = DocumentSet.new()
    for i in 0...@num_docs do
      ds = ElasticDocGenerator.generate_docs(i, 1, { :field1 => 'word', :field2 => "#{i}" })
      ds.documents.each do |doc|
        docs.add(doc)
      end
    end
    feed_file = "#{dirs.tmpdir}/docs.xml"
    docs.write_xml(feed_file)
    feed(:file => feed_file)
  end

  def assert_hitcounts
    assert_hitcount("query=sddocname:test&nocache", @num_docs)
    assert_hitcount("query=f1:word&nocache", @num_docs)
  end

  def wait_for_hitcounts
    wait_for_hitcount("query=sddocname:test&nocache", @num_docs)
    wait_for_hitcount("query=f1:word&nocache", @num_docs)
  end

  def assert_not_enough_hitcounts
      hitcount = search("query=sddocname:test&nocache").hitcount
      puts "assert_not_enough_hitcounts: #{hitcount} (#{@num_docs}) hits"
      assert(hitcount < @num_docs)
  end

  def get_query(search_path)
    "query=sddocname:test&nocache&model.searchPath=#{search_path.gsub(';', '%3B')}"
  end

  def get_hitcount(search_path)
    query = get_query(search_path)
    hitcount = search(query).hitcount
    puts "get_hitcount: '#{query}', hitcount=#{hitcount}"
    return hitcount
  end

  def assert_equal_hitcounts(search_paths)
    last_hitcount = get_hitcount(search_paths[0])
    for i in 1...search_paths.size do
      puts "Expects search paths '#{search_paths[i-1]}' and '#{search_paths[i]}' to give #{last_hitcount} hits"
      hitcount = get_hitcount(search_paths[i])
      assert_equal(last_hitcount, hitcount)
    end
  end

  def assert_results(offset)
    puts "assert_result(): hits=#{@num_hits}, offset=#{offset}"
    result = search("query=sddocname:test&nocache&hits=#{@num_hits}&offset=#{offset}")
    assert_equal(@num_hits, result.hit.size)
    hit_idx = 0
    for i in offset...(offset + @num_hits) do
      doc_id = @num_docs - 1 - i
      #puts "check_result(): hit_idx=#{hit_idx}, doc_id=#{doc_id}"
      assert_field_value(result, "f1", "word", hit_idx)
      assert_field_value(result, "f2", doc_id.to_s, hit_idx)
      assert_relevancy(result, doc_id, hit_idx)
      hit_idx += 1
    end
  end

  def assert_corpus
    assert_hitcounts
    for i in 0...(@num_docs / @num_hits) do
      assert_results(i*@num_hits)
    end
  end

  def assert_search_paths
    # mld part 0 with rows 0,1,2,unspecified (and search node 0)
    assert_equal_hitcounts(["0/0;0/", "0/1;0/", "0/2;0/", "0/;0/"])

    # mld part 1 with rows 0,1,2,unspecified (and search node 0)
    assert_equal_hitcounts(["1/0;0/", "1/1;0/", "1/2;0/", "1/;0/"])

    # mld part 0 with 3 underlying search nodes
    part_0_hits = get_hitcount("0/;0/") + get_hitcount("0/;1/") + get_hitcount("0/;2/")

    # mld part 1 with 3 underlying search nodes
    part_1_hits = get_hitcount("1/;0/") + get_hitcount("1/;1/") + get_hitcount("1/;2/")

    puts "assert_search_paths: part_0_hits=#{part_0_hits}, part_1_hits=#{part_1_hits}"
    assert_equal(@num_docs, part_0_hits + part_1_hits)
  end

  def get_search_node(i)
    vespa.search["mycluster"].searchnode[i]
  end

  def get_dispatch_node(distribution_key)
    vespa.search["mycluster"].topleveldispatch.each_value do |dispatch_node|
      config_id = dispatch_node.config_id
      if config_id.match(/dispatch.#{distribution_key}/)
        puts "get_dispatch_node(#{distribution_key}): '#{config_id}'"
        return dispatch_node
      end
    end
    puts "get_dispatch_node(#{distribution_key}): nil"
    return nil
  end

  def stop_and_wait(i)
    get_dispatch_node(i).stop
    stop_node_and_wait("mycluster", i)
  end

  def start_and_wait(i)
    get_dispatch_node(i).start
    start_node_and_wait("mycluster", i)
  end

  # Verify that the vespa model has 6 search nodes and 6 dispatch nodes.
  def assert_services
    cluster = vespa.search['mycluster']
    puts "assert_services(): topleveldispatchers:\n#{cluster.topleveldispatch}"
    assert_equal(6, cluster.searchnode.size)
    assert_equal(6 + 1, cluster.topleveldispatch.size)
    for i in 0...6 do
      # Note that search node indexes (in ruby model) and distribution keys are the same
      distribution_key = i
      puts "assert_services(): Verifying node [#{i}]"
      assert_equal("mycluster/search/cluster.mycluster/#{distribution_key}",
                   get_search_node(i).config_id)
      assert_equal("mycluster/search/cluster.mycluster/dispatchers/dispatch.#{distribution_key}",
                   get_dispatch_node(distribution_key).config_id)
    end
  end

  # Verify that we have full coverage when 1 search node and 1 dispatch node are down.
  def assert_search_and_dispatch_nodes_down
    for i in 0...6 do
      stop_and_wait(i)
      assert_corpus
      start_and_wait(i)
    end
  end

  # Verify that we have full coverage when up to 2 dispatch nodes (in the same group) are down and
  # that coverage is lost if all 3 dispatch nodes are down.
  def assert_dispatch_nodes_down(node_list)
    get_dispatch_node(node_list[0]).stop
    assert_hitcounts
    get_dispatch_node(node_list[1]).stop
    assert_hitcounts
    get_dispatch_node(node_list[2]).stop
    assert_not_enough_hitcounts

    get_dispatch_node(node_list[2]).start
    wait_for_hitcounts
    get_dispatch_node(node_list[1]).start
    sleep 3
    assert_hitcounts
    get_dispatch_node(node_list[0]).start
    sleep 3
    assert_hitcounts
  end

  def test_2_dispatch_groups_basic_search
    set_description("Test basic multi-level dispatch searching")
    deploy_app(create_app(create_implicit_dispatch))
    start
    generate_and_feed_docs

    5.times do
      assert_corpus
    end

    assert_search_paths
  end

  def test_2_dispatch_groups_nodes_down_and_up
    set_description("Test search coverage when search nodes and dispatch nodes go down and up")
    deploy_app(create_app(create_explicit_dispatch))
    start
    generate_and_feed_docs

    assert_services
    assert_search_and_dispatch_nodes_down
    assert_dispatch_nodes_down([0, 1, 2])
    assert_dispatch_nodes_down([3, 4, 5])
  end

  def teardown
    stop
  end

end
