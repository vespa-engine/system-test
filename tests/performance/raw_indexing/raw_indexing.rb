# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'json_document_writer'
require 'indexed_search_test'
require 'performance/fbench'
require 'pp'

class FeedingIndexTest < PerformanceTest

  def setup
    set_owner("onorum")
    set_description("simple test for indexing and query performance")
    
    @warmUpDocPath = "#{dirs.tmpdir}warm_up_docs.json"
    @docPath = "#{dirs.tmpdir}feed_docs.json"
    # webtext file is from https://openaipublic.azureedge.net/gpt-2/output-dataset/v1/webtext.train.jsonl
    @webtextFile = 'webtext.train.jsonl'
  end

  def test_feeding_and_querying_docs
    deploy_app(create_app)
    @container = vespa.container.values.first
    set_up_files

    start
    vespa_destination_start

    feedfile(@warmUpDocPath, {localfile: true, :numthreads => 3, :route => '"combinedcontainer/chain.indexing null/default"'})

    profiler_start
    run_feeder(@docPath, [parameter_filler("legend", "test_feeding_performance")], {localfile: true})
    profiler_report('profile_feed')

    query_docs
  end

  def set_up_files
    download_doc_file
    make_warm_up_docs
    make_feed_docs
    make_queries
  end

  def download_doc_file
    download_file_from_s3(@webtextFile, @container, 'raw_indexing')
  end

  def make_warm_up_docs
    @container.execute("cd #{dirs.tmpdir} && python3 #{selfdir}make_json_docs.py 2000 #{@webtextFile} warm_up_docs.json")
  end

  def make_feed_docs
    @container.execute("cd #{dirs.tmpdir} && python3 #{selfdir}make_json_docs.py 200000 #{@webtextFile} feed_docs.json")
  end

  def make_queries
    @container.execute("cd #{dirs.tmpdir} && python3 #{selfdir}make_queries.py feed_docs.json queries.txt 3")
  end

  def query_docs
    @queryfile = "#{dirs.tmpdir}queries.txt"
    container = (vespa.qrserver['0'] or vespa.container.values.first)

    run_fbench(container, 8, 20, [parameter_filler('tag', 'ignore'),
                                  parameter_filler('legend', 'ignore1')])

    run_fbench(container, 8, 60, [parameter_filler('tag', 'query'),
                                  parameter_filler('legend', 'getv1api')])
  end

  def create_app
    # We only care about single node performance for this test.
    SearchApp.new.sd(selfdir + 'doc.sd').
      num_parts(1).redundancy(1).ready_copies(1).
      search_dir(selfdir + "search").
      container(Container.new("combinedcontainer").
                  jvmoptions('-Xms10g -Xmx10g').
                  search(Searching.new).
                  docproc(DocumentProcessing.new).
                  documentapi(ContainerDocumentApi.new))
  end

end
