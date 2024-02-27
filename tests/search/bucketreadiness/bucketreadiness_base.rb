# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'search/utils/elastic_doc_generator'

class BucketReadinessBase < IndexedOnlySearchTest

  def setup
    @valgrind=false
    set_owner("geirst")
    @base_query = "query=f1:word&nocache"
    @generated_dir = "#{dirs.tmpdir}/generated/"
    Dir::mkdir(@generated_dir)
    @debug_log_enabled = false
  end

  def initialize(*args)
    cmdline, tc_file, arg_pack = args
    arg_pack[:stress_test] = true
    super(cmdline, tc_file, arg_pack)
  end

  def run_readiness_while_nodes_down_and_up_test
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

    enable_merge_debug_logging if @debug_log_enabled

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
    wait_for_hitcount(get_query(), exp_hitcount)
  end

  def create_app(sd_file)
    SearchApp.new.sd(selfdir + sd_file).
      search_type("ELASTIC").cluster_name("mycluster").num_parts(4).redundancy(3).ready_copies(2).
      storage(StorageCluster.new("mycluster", 4).distribution_bits(8))
  end

  def enable_merge_debug_logging
    for i in 0..3
      vespa.content_node("mycluster", i).logctl2("persistence.mergehandler", "debug=on,spam=on")
      vespa.distributor_node("mycluster", i).logctl2("distributor.operation.idealstate.merge","debug=on,spam=on")
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
