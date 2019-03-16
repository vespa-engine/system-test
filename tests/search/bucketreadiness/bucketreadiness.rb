# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'search/utils/elastic_doc_generator'

class BucketReadiness < SearchTest

  def initialize(*args)
    cmdline, tc_file, arg_pack = args
    arg_pack[:stress_test] = true
    super(cmdline, tc_file, arg_pack)
  end

  def timeout_seconds
    60*50
  end

  def nightly?
    true
  end

  def setup
    @valgrind=false
    set_owner("geirst")
    @base_query = "query=f1:word&nocache"
    @generated_dir = "#{dirs.tmpdir}/generated/"
    Dir::mkdir(@generated_dir)
  end

  def generate_docs(file_name, start, count)
    ElasticDocGenerator.write_docs(start, count, @generated_dir + file_name)
  end

  def generate_removes(file_name, start, count)
    ElasticDocGenerator.write_removes(start, count, @generated_dir + file_name)
  end

  def generate_updates(file_name, start, count)
    ElasticDocGenerator.write_updates(start, count, @generated_dir + file_name)
  end

  def add_search_path(query, search_path = nil)
    if (search_path != nil)
      return query + "&model.searchPath=#{search_path}/0"
    end
    return query
  end

  def get_query(search_path = nil)
    add_search_path(@base_query, search_path)
  end

  def stop_and_wait(i)
    stop_node_and_wait("mycluster", i)
  end

  def start_and_wait(i)
    start_node_and_wait("mycluster", i)
  end

  def verify_hitcount(search_path, exp_hitcount)
    query = get_query(search_path)
    puts "verify_hitcount(#{query}, #{exp_hitcount})"
    wait_for_hitcount(query, exp_hitcount)
    assert_hitcount(get_query(), exp_hitcount)
  end

  def create_app(sd_file)
    SearchApp.new.sd(selfdir + sd_file).
      search_type("ELASTIC").cluster_name("mycluster").num_parts(4).redundancy(3).ready_copies(2).
      storage(StorageCluster.new("mycluster", 4).distribution_bits(8))
  end

  def test_readiness_while_nodes_down_and_up
    set_description("Basic test for bucket readiness with 2 ready copies of each bucket and nodes going down and up")
    deploy_app(create_app("regular/test.sd"))
    start
    run_readiness_while_nodes_down_and_up_test
  end

  def test_readiness_while_nodes_down_and_up_fast_access
    set_description("Basic test for bucket readiness with 2 ready copies of each bucket and nodes going down and up with fast-access attribute")
    deploy_app(create_app("fast_access/test.sd"))
    start
    run_readiness_while_nodes_down_and_up_test
  end

  def run_readiness_while_nodes_down_and_up_test
    ["","2","3","4"].each do |i|
=begin
      vespa.adminserver.logctl("searchnode#{i}:proton.server.buckethandler", "debug=on,spam=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.persistenceengine.persistenceengine", "debug=on,spam=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.server.bucketmovecontroller", "debug=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.server.clusterstatehandler", "debug=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.server.feedhandler", "debug=on")
=end
    end

    chunks = 200
    generate_docs("doc.0.xml", 0, 5*chunks)
    generate_removes("rem.00.xml", 0, chunks)
    generate_removes("rem.01.xml", chunks, chunks)
    generate_removes("rem.02.xml", 2*chunks, chunks)
    generate_removes("rem.03.xml", 3*chunks, chunks)
    generate_docs("doc.00.xml", 0, chunks)
    generate_docs("doc.01.xml", chunks, chunks)
    generate_docs("doc.02.xml", 2*chunks, chunks)
    generate_docs("doc.03.xml", 3*chunks, chunks)
    generate_updates("upd.00.xml", 0, chunks)
    generate_updates("upd.01.xml", chunks, chunks)
    generate_updates("upd.02.xml", 2*chunks, chunks)
    generate_updates("upd.03.xml", 3*chunks, chunks)

    feed_and_wait_for_hitcount(get_query(), 5*chunks, :file => @generated_dir + "doc.0.xml")

    # feed removes
    feed_and_wait_for_hitcount(get_query(), 4*chunks, :file => @generated_dir + "rem.00.xml")

    stop_and_wait(0)
    verify_hitcount("1,2,3", 4*chunks)
    feed_and_wait_for_hitcount(get_query("1,2,3"), 3*chunks, :file => @generated_dir + "rem.01.xml")

    stop_and_wait(1)
    verify_hitcount("2,3", 3*chunks)
    feed_and_wait_for_hitcount(get_query("2,3"), 2*chunks, :file => @generated_dir + "rem.02.xml")

    stop_and_wait(2)
    verify_hitcount("3", 2*chunks)
    feed_and_wait_for_hitcount(get_query("3"), chunks, :file => @generated_dir + "rem.03.xml")

    start_and_wait(0)
    verify_hitcount("0,3", chunks)
    start_and_wait(1)
    verify_hitcount("0,1,3", chunks)
    start_and_wait(2)
    verify_hitcount(nil, chunks)

    # feed documents
    feed_and_wait_for_hitcount(get_query(), 2*chunks, :file => @generated_dir + "doc.00.xml")

    stop_and_wait(3)
    verify_hitcount("0,1,2", 2*chunks)
    feed_and_wait_for_hitcount(get_query("0,1,2"), 3*chunks, :file => @generated_dir + "doc.01.xml")

    stop_and_wait(2)
    verify_hitcount("0,1", 3*chunks)
    feed_and_wait_for_hitcount(get_query("0,1"), 4*chunks, :file => @generated_dir + "doc.02.xml")

    stop_and_wait(1)
    verify_hitcount("0", 4*chunks)
    feed_and_wait_for_hitcount(get_query("0"), 5*chunks, :file => @generated_dir + "doc.03.xml")

    start_and_wait(3)
    verify_hitcount("0,3", 5*chunks)

    start_and_wait(2)
    verify_hitcount("0,2,3", 5*chunks)
    start_and_wait(1)
    verify_hitcount(nil, 5*chunks)

    # feed updates
    @base_query = "query=f2:2012&nocache"
    verify_hitcount(nil, 0)
    feed_and_wait_for_hitcount(get_query(), chunks, :file => @generated_dir + "upd.00.xml")

    stop_and_wait(3)
    verify_hitcount("0,1,2", chunks)
    feed_and_wait_for_hitcount(get_query("0,1,2"), 2*chunks, :file => @generated_dir + "upd.01.xml")

    stop_and_wait(2)
    verify_hitcount("0,1", 2*chunks)
    feed_and_wait_for_hitcount(get_query("0,1"), 3*chunks, :file => @generated_dir + "upd.02.xml")

    stop_and_wait(1)
    verify_hitcount("0", 3*chunks)
    feed_and_wait_for_hitcount(get_query("0"), 4*chunks, :file => @generated_dir + "upd.03.xml")

    start_and_wait(3)
    verify_hitcount("0,3", 4*chunks)
    start_and_wait(2)
    verify_hitcount("0,2,3", 4*chunks)
    start_and_wait(1)
    verify_hitcount(nil, 4*chunks)
  end

  def execute_visit(exec_object)
    exec_object.execute("vespa-visit -i | wc -l").to_i
  end

  def assert_visit_count(id, exp_count)
    act_count = vespa.adminserver.execute("vespa-visit -i 2>/dev/null | grep \"id:test\" | wc -l").to_i
    puts "******** assert_visit_count(#{id}, #{act_count}) ********"
    assert_equal(exp_count, act_count)
  end

  class VisitorRunner
    def initialize(exec_object, thread_id)
      @exec_object = exec_object
      @thread_id = thread_id
      @done = false
    end
    def mark_done
      @done = true
    end
    def run
      i = 0
      while !@done do
        count = @exec_object.execute("vespa-visit --priority LOWEST -i 2>/dev/null | grep \"id:test\" | sort | uniq | wc -l").to_i
        puts "******** vespa-visit(#{@thread_id},#{i}): #{count} ********"
        i += 1
      end
    end
  end

  def test_visiting_while_nodes_down_and_up
    set_description("Test that we can do visiting while nodes are going down and up")
    app = create_app("regular/test.sd")
    app.config(ConfigOverride.new("vespa.config.content.core.stor-distributormanager").
               add("maxpendingidealstateoperations", 10000000))
    app.config(ConfigOverride.new("vespa.config.content.core.stor-server").
               add("max_merge_queue_size", 10000).
               add("max_merges_per_node", 40))
    app.config(ConfigOverride.new("vespa.config.content.core.stor-visitor").add("maxvisitorqueuesize", 100000))
    deploy_app(app)
    start
    ["","2","3","4"].each do |i|
=begin
      vespa.adminserver.logctl("searchnode#{i}:proton.server.buckethandler", "debug=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.server.bucketmovecontroller", "debug=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.server.clusterstatehandler", "debug=on")
      vespa.adminserver.logctl("searchnode#{i}:proton.server.feedhandler", "debug=on")
=end
    end

    docs = 10000
    generate_docs("doc.0.xml", 0, docs)
    feed_and_wait_for_hitcount(get_query(), docs, :file => @generated_dir + "/doc.0.xml")
    assert_visit_count(0, docs)
    visitors = []
    threads = []

    for i in 0...2 do
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["0"], i*4))
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["1"], 1+i*4))
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["2"], 2+i*4))
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["3"], 3+i*4))
    end
    for i in 0...8 do
      thread = Thread.new(visitors[i]) do |v|
        v.run
      end
      threads.push(thread)
    end

    sleep 4
    stop_and_wait(0)
    wait_for_hitcount(get_query("1,2,3"), docs)
    assert_visit_count(1, docs)

    sleep 4
    stop_and_wait(1)
    wait_for_hitcount(get_query("2,3"), docs)
    assert_visit_count(2, docs)

    sleep 4
    stop_and_wait(2)
    wait_for_hitcount(get_query("3"), docs)
    assert_visit_count(3, docs)

    sleep 4
    start_and_wait(0)
    wait_for_hitcount(get_query("0,3"), docs)
    assert_visit_count(4, docs)

    sleep 4
    start_and_wait(1)
    wait_for_hitcount(get_query("0,1,3"), docs)
    assert_visit_count(5, docs)

    sleep 4
    start_and_wait(2)
    wait_for_hitcount(get_query(), docs)
    assert_visit_count(6, docs)

    puts "Test completed, closing visiting threads"

    for i in 0...8 do
      visitors[i].mark_done
      threads[i].join
    end
  end

  def teardown
    begin
      vespa.adminserver.execute("pkill -KILL -f vespa-visit", :exceptiononfailure => false)
    ensure
      stop
    end
  end

end
