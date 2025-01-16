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
    visit_result["documents"].each do |document|
      result.push(document["id"])
    end
    result
  end

  def teardown
    stop
  end
end

