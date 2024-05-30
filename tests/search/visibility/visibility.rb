# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# -*- coding: utf-8 -*-
require 'indexed_only_search_test'
require 'document'
require 'thread'
require 'simple_http_feeder'
require 'app_generator/http'

class VisibilityFeeder < SimpleHTTPFeeder
  def initialize(testcase, mutex, cv, qrserver, document_api_v1, docbias,
                 doc_type, id_prefix)
    super(testcase, qrserver, document_api_v1, doc_type, id_prefix, "i1")
    @mutex = mutex
    @cv = cv
    @active = false
    @failed = false
    @exception = ""
    @thread = nil
    @docbias = docbias
  end

  def inactive
    @mutex.synchronize do
      return !@active
    end
  end

  def failed
    @mutex.synchronize do
      return @failed
    end
  end

  def exception
    @mutex.synchronize do
      return @exception
    end
  end

  def docquery(i)
    timeout = @testcase.valgrind ? 60 : 5
    "/search/?query=w#{i.to_s}&nocache&hits=10&ranking=unranked&format=json&timeout=#{timeout}"
  end

  def fmt_result(result)
    hitcount = result.hitcount
    docids = result.get_field_array('documentid')
    "#{hitcount} #{docids}"
  end

  def pollfeed(verbose = false)
    # puts "#### starting pollfeed thread ####"
    iters = 0
    wantbreak = false
    while true
      @mutex.synchronize do
        wantbreak = !@active
      end
      if wantbreak
        # puts "#### breaking out of pollfeed thread ####"
        break
      end
      # puts "#### running pollfeed thread ####"
      i = iters + @docbias
      puts "Handling doc #{i}" if verbose
      docid = gen_docid(i)
      dq = docquery(i)
      doc = gen_doc_docid(i, docid)
      beforeput = @qrserver.search(dq)
      @testcase.
        assert_equal(0, beforeput.hitcount,
                     "Unexpected number of hits before put of #{docid}: #{fmt_result(beforeput)}")
      @document_api_v1.put(doc, :brief => !verbose)
      afterput = @qrserver.search(dq)
      @testcase.
      assert_equal(1, afterput.hitcount,
                   "Unexpected number of hits after put of #{docid}: #{fmt_result(afterput)}")
      if iters % 3 == 0
        @document_api_v1.remove(docid, :brief => !verbose)
        afterremove = @qrserver.search(dq)
        @testcase.
          assert_equal(0, afterremove.hitcount,
                       "Unexpected number of hits after remove of #{docid}: #{fmt_result(afterremove)}")
      end
      iters = iters + 1
    end
    puts "Handled #{iters} feed iterations, bias was #{@docbias}" if verbose
    # puts "#### ending pollfeed thread ####"
  end

  def create_thread(verbose = false)
    # puts "########## create pollfeed thread ##########"
    @mutex.synchronize do
      @active = true
    end
    thread = Thread.new(verbose) do |pverbose|
      begin
        pollfeed(pverbose)
      rescue Exception => e
        puts "pollfeed thread got exception"
        puts e.message
        puts e.backtrace.inspect
        @mutex.synchronize do
          @failed = true
          @exception = e.message
        end
      rescue
        puts "pollfeed thread got unknown exception"
        @mutex.synchronize do
          @failed = true
          @exception = e.message
        end
      ensure
        @mutex.synchronize do
          @active = false
        end
      end
    end
    @mutex.synchronize do
      @thread = thread
    end
  end

  def join
#    puts "### join 1 ###"
    @mutex.synchronize do
      return if @thread.nil?
    end
#    puts "### join 2 ###"
    @mutex.synchronize do
      @active = false
      @cv.signal
    end
#    puts "### join 3 ###"
    @thread.join
    @thread = nil
#    puts "### join 4 ###"
  end
end

class Visibility < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    set_description("Verify that documents are searchable after put")
    @doc_type = "visibility"
    @id_prefix = "id:test:#{@doc_type}::"
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @disable_log_query_and_result = true
  end

  def get_base_sc(parts, r, rc)
    # Disable lid space compaction to avoid occasional visibility glitches
    SearchCluster.new("visibility").
      sd(selfdir + "visibility.sd").
      num_parts(parts).
      redundancy(r).
      indexing("default").
      allowed_lid_bloat(1000000).
      allowed_lid_bloat_factor(2.0).
      ready_copies(rc)
  end

  def create_groups(pergroup)
    NodeGroup.new(0, "mytopgroup").
      distribution("#{pergroup}|#{pergroup}|*").
      group(NodeGroup.new(0, "mygroup0").
            node(NodeSpec.new("node1", 0)).
            node(NodeSpec.new("node1", 1)).
            node(NodeSpec.new("node1", 2))).
      group(NodeGroup.new(1, "mygroup1").
            node(NodeSpec.new("node1", 3)).
            node(NodeSpec.new("node1", 4)).
            node(NodeSpec.new("node1", 5))).
      group(NodeGroup.new(2, "mygroup2").
            node(NodeSpec.new("node1", 6)).
            node(NodeSpec.new("node1", 7)).
            node(NodeSpec.new("node1", 8)))
  end

  def get_base_app(sc)
    SearchApp.new.
            container(Container.new.
                search(Searching.new).
                component(AccessLog.new("disabled")).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new).
                http(Http.new.server(Server.new("node1", vespa.default_document_api_port)))).
            cluster(sc).
            storage(StorageCluster.new("visibility", 41).distribution_bits(16))
  end

  def get_app(sc)
    get_base_app(sc)
  end

  def qrserver
    vespa.container.values.first
  end

  def document_api_v1
    vespa.document_api_v1
  end

  def unregister_feeders
    return if @feeders.nil?
    feederfailed = false
    exception = "(no exception message given)"
    @feeders.each do |feeder|
      feeder.join
      feederfailed = true if feeder.failed
      exception = feeder.exception
    end
    @feeders = nil
    puts "Stopped feeders"
    assert_equal(false, feederfailed, "Feeder failed due to exception: #{exception}")
  end

  def create_feeders(num_feeders)
    @feeders = Array.new
    num_feeders.times do |i|
      res = VisibilityFeeder.new(self, @mutex, @cv,
                                 qrserver, document_api_v1, i * 1000000,
                                 @doc_type, @id_prefix)
      @feeders.push(res)
   end
  end

  def start_feeders
    puts "Starting feeders"
    @feeders.each do |feeder|
       feeder.create_thread(false)
    end
  end

  def perform_test_visibility(parts, r, rc)
    sc = get_base_sc(parts, r, rc)
    app = get_app(sc)
    deploy_app(app)
    start
    create_feeders(10)
    start_feeders
    sleep 60
    unregister_feeders
  end

  def test_visibility_single
    perform_test_visibility(1, 1, 1)
  end

  def test_visibility_four_nodes_no_redundancy
    perform_test_visibility(4, 1, 1)
  end

  def teardown
    unregister_feeders
    stop
  end

  def test_visibility_four_nodes_redundancy
    perform_test_visibility(4, 2, 2)
  end

  def perform_test_hierarchical_distribution_visibility(lr)
    sc = get_base_sc(9, 3 * lr, 3 * lr).group(create_groups(lr))
    app = get_app(sc)
    deploy_app(app)
    start
    create_feeders(10)
    start_feeders
    sleep 60
    unregister_feeders
  end

  def test_hierarchical_distribution_visibility_no_redundancy
    @valgrind = false
    perform_test_hierarchical_distribution_visibility(1)
  end

  def test_hierarchical_distribution_visibility_redundancy
    @valgrind = false
    perform_test_hierarchical_distribution_visibility(2)
  end
end
