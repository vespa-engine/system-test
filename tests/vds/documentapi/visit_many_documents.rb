# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class VisitManyDocumentsTest < VdsTest

  def setup
    set_owner('vekterli')
    deploy_app(default_app.distribution_bits(8))
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    @tmp_bin_dir = container.create_tmp_bin_dir
    container.execute("gcc -g -O3 -o #{@tmp_bin_dir}/docs #{selfdir}/docs.cpp")
    start
    @num_users = 500
    @docs_per_user = 100
    @wanted_doc_count = 27
  end

  def timeout_seconds
    1800
  end

  def feed_documents
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    container.execute("#{@tmp_bin_dir}/docs #{@num_users} #{@docs_per_user}| vespa-feed-perf")
  end

  def test_visit_many_documents
    set_description("Test visiting of many documents using continuation token")
    feed_documents
    [false, true].each { |stream|
      visit_with_continuation(stream)
    }
    # Test JSONL with several different wanted doc counts to have responses that span
    # everything from small subsets up to returning the entire corpus in one go.
    # JSONL always implies stream=true.
    [@wanted_doc_count, 1_000, 10_000, 100_000].each { |doc_count|
      visit_with_jsonl doc_count
    }
  end

  def visit_with_continuation(stream)
    puts "Visiting via Document V1 API with stream=#{stream}"
    doc_ids = Set.new
    params = {:selection => "music", :cluster => "storage", :wantedDocumentCount => @wanted_doc_count, :stream => stream}
    continuation = nil
    visit_count = 0
    loop do
      result = vespa.document_api_v1.visit(continuation ? params.merge(:continuation => continuation) : params)
      visit_count += 1
      doc_ids.merge(get_document_ids(result))
      continuation = result["continuation"]
      break if continuation == nil
    end
    puts "visit_count=#{visit_count}"
    docs_total = @num_users * @docs_per_user
    assert_equal(docs_total, doc_ids.size)
  end

  def get_document_ids(visit_result)
    result = []
    res_doc_count = visit_result['documentCount'].to_i
    visit_result["documents"].each do |document|
      result.push(document["id"])
    end
    if res_doc_count != result.size
      raise "Inconsistent specified doc count (#{res_doc_count}) and actual returned doc chunks (#{result.size})"
    end
    result
  end

  class MyResponseHandler < JsonLinesResponseHandler
    attr_reader :continuation, :doc_ids, :reported_document_count, :percent_finished
    def initialize
      super
      @continuation = nil
      @percent_finished = 0.0
      @doc_ids = Set.new
      @reported_document_count = -1
    end

    def on_put(doc_id, fields)
      @doc_ids.add(doc_id)
    end

    def on_remove(doc_id)
      # TODO test removes as well. Existing test does not do this.
    end

    def on_continuation(token, percent_finished)
      @continuation = token # nil if finished
      @percent_finished = percent_finished
    end

    def on_document_count(doc_count)
      @reported_document_count = doc_count
    end
  end

  # P --> Q
  def implies(p, q)
    not p or q
  end

  def visit_with_jsonl(wanted_doc_count)
    puts "Visiting via Document V1 API with JSONL stream response and wanted document count #{wanted_doc_count}"
    params = {:selection => 'music', :cluster => 'storage', :wantedDocumentCount => wanted_doc_count}
    doc_ids = Set.new
    visit_count = 0
    last_percent_finished = 0.0
    continuation = nil
    loop do
      handler = MyResponseHandler.new
      vespa.document_api_v1.visit_jsonl_stream(handler, continuation ? params.merge(:continuation => continuation) : params)
      puts "visited #{handler.doc_ids.size} (#{handler.reported_document_count}) docs (#{handler.percent_finished}% finished)"
      raise 'No docs visited' if handler.doc_ids.size == 0
      continuation = handler.continuation
      doc_ids.merge(handler.doc_ids)
      assert_equal(handler.doc_ids.size, handler.reported_document_count,
                   'Inconsistent reported document count vs. actual returned document set cardinality')
      visit_count += 1
      assert(implies(handler.percent_finished < 100.0, !continuation.nil?),
             'A non-finished continuation did not have a token set')
      assert(implies(continuation.nil?, handler.percent_finished == 100.0),
             'Response did not have a continuation set, but is not marked as completed')
      assert(handler.percent_finished >= last_percent_finished,
             "Expected percent finished to be monotonically increasing: " +
             "was #{last_percent_finished}, is now #{handler.percent_finished}")
      last_percent_finished = handler.percent_finished
      break if continuation.nil?
    end
    puts "visit_count=#{visit_count}"
    docs_total = @num_users * @docs_per_user
    assert_equal(docs_total, doc_ids.size)
  end

end

