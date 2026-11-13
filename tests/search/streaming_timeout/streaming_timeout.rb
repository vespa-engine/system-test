# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'

require 'json'

class StreamingTimeout < StreamingSearchTest
  NUM_DOCUMENTS = 100_000
  NUM_DIMENSIONS = 2048

  def setup
    set_owner("boeker")
    set_description("Test timeout behavior in streaming search")
  end

  def get_container
    vespa.qrserver["0"] or vespa.container.values.first
  end

  def compile_document_generator
    @tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -std=c++20 -O3 -o #{@tmp_bin_dir}/docs #{selfdir}data/docs.cpp")
  end

  def feed_and_wait(name, num_documents, num_dimensions)
    puts "Feeding documents"
    @container.execute("#{@tmp_bin_dir}/docs #{name} #{num_documents} #{num_dimensions} | vespa-feed-perf")
    wait_for_atleast_hitcount("query=sddocname:#{name}&streaming.selection=true", num_documents)
  end

  def test_hits_filled_on_soft_timeout
    deploy_app(SearchApp.new.sd(selfdir + "streaming_timeout/test.sd").search_dir(selfdir + "streaming_timeout/search"))
    @container = get_container
    compile_document_generator
    start

    puts "Feeding #{NUM_DOCUMENTS} documents"
    feed_and_wait("test", NUM_DOCUMENTS, NUM_DIMENSIONS)

    query = {
      'yql' => 'select * from sources * where ({targetHits:100}nearestNeighbor(tensor_field, q_v))',
      'input.query(q_v)' => "#{[0.0] * NUM_DIMENSIONS}",
      'streaming.selection' => true
    }
    result = search_with_timeout(5.0, query)

    puts JSON.pretty_generate(result.json)
  end


end
