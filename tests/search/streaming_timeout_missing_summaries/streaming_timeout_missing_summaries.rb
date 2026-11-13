# Copyright Vespa.ai. All rights reserved.
require 'search_test'
require 'json'

# Reproduces SUPPORT-452: When a streaming search cluster times out, hits from
# other (indexed) clusters in the same query are returned without summary
# fields, because the streaming visitor consumes the entire query timeout and
# there is no time left for the fill phase.
class StreamingTimeoutMissingSummaries < SearchTest

  NUM_INDEXED_DOCS = 10
  NUM_STREAM_DOCS = 4000

  def setup
    set_owner("boeker")
    set_description("Hits from an indexed cluster lose summary fields when a streaming cluster in the same query times out")
  end

  # Indexed and streaming schemas in separate content clusters: FederationSearcher merges them.
  def create_two_cluster_app
    SearchApp.new.
      cluster(SearchCluster.new("indexed_docs").sd(selfdir + "indexeddoc.sd")).
      cluster(SearchCluster.new("streaming_docs").sd(selfdir + "streamdoc.sd", :mode => "streaming"))
  end

  # Indexed and streaming schemas in the same content cluster: ClusterSearcher merges them.
  def create_mixed_mode_app
    SearchApp.new.
      cluster(SearchCluster.new("docs").
              sd(selfdir + "indexeddoc.sd", :mode => "index").
              sd(selfdir + "streamdoc.sd", :mode => "streaming"))
  end

  def generate_and_feed
    feed_file = "#{dirs.tmpdir}/docs.json"
    File.open(feed_file, "w") do |f|
      docs = []
      NUM_INDEXED_DOCS.times do |i|
        docs << { "put" => "id:test:indexeddoc::#{i}", "fields" => { "id" => i, "title" => "indexed title #{i}" } }
      end
      NUM_STREAM_DOCS.times do |i|
        docs << { "put" => "id:test:streamdoc:g=group#{i % 10}:#{i}", "fields" => { "id" => i, "title" => "stream title #{i}" } }
      end
      f.write(JSON.generate(docs))
    end
    feed(:file => feed_file)
    wait_for_hitcount("yql=select * from indexeddoc where true", NUM_INDEXED_DOCS)
    wait_for_hitcount("yql=select * from streamdoc where true&streaming.selection=true", NUM_STREAM_DOCS)
  end

  def query(ranking, timeout)
    {
      'yql' => 'select * from sources * where true',
      'streaming.selection' => 'true',
      'ranking' => ranking,
      'hits' => '10',
      'timeout' => timeout,
      'trace.level' => '3'
    }
  end

  def hits_of(json)
    (json['root']['children'] || []).select { |h| h['id'] && !h['id'].start_with?('group:') }
  end

  def errors_of(json)
    json['root']['errors'] || []
  end

  def test_indexed_hits_not_filled_when_streaming_times_out_two_clusters
    run_repro(create_two_cluster_app)
  end

  def test_indexed_hits_not_filled_when_streaming_times_out_mixed_mode_cluster
    run_repro(create_mixed_mode_app)
  end

  def test_indexed_hits_not_filled_when_streaming_times_out_two_clusters_global_phase
    run_repro(create_two_cluster_app, 'slow_global')
  end

  def test_indexed_hits_not_filled_when_streaming_times_out_mixed_mode_cluster_global_phase
    run_repro(create_mixed_mode_app, 'slow_global')
  end

  # Indexed hits have ids like index:<source>/<partid>/<gid>, streaming hits have document ids.
  def indexed_hit?(hit)
    hit['id'].start_with?('index:')
  end

  def run_repro(app, slow_ranking = 'slow')
    deploy_app(app)
    start
    generate_and_feed

    puts "Control: cheap ranking, everything should be filled"
    json = search_base(query('default', '10s')).json
    hits = hits_of(json)
    assert_equal(10, hits.size, "Expected 10 hits, got: #{JSON.pretty_generate(json)}")
    hits.each do |hit|
      assert(hit['fields'].key?('title'), "Expected summary field 'title' in #{hit}")
    end

    #puts "Repro: slow ranking for the streaming schema, which then times out"
    #json = search_base(query(slow_ranking, '2s')).json
    #puts JSON.pretty_generate(json)

    #errors = errors_of(json)
    #puts "Errors: #{JSON.pretty_generate(errors)}"
    #assert(errors.any? { |e| e['code'] == 12 }, "Expected a timeout error (code 12), got: #{errors}")
    ## The fill is skipped because no time is left, and this is reported. Note that FederationSearcher.fill
    ## passes a fresh Result (without the streaming error) to ClusterSearcher.fill, so the
    ## "only if no error yet" condition there never hides this message.
    #assert(errors.any? { |e| e['message'].start_with?('No time left to get summaries') },
    #       "Expected a 'No time left to get summaries' error, got: #{errors}")

    #hits = hits_of(json)
    #indexed_hits = hits.select { |h| indexed_hit?(h) }
    #assert(!indexed_hits.empty?, "Expected hits from the indexed schema")
    #assert(hits.all? { |h| indexed_hit?(h) }, "Expected no hits from the timed out streaming search")
    #indexed_hits.each do |hit|
    #  assert(hit['fields'].key?('matchfeatures'), "Expected matchfeatures in #{hit}")
    #  # This is the reported problem: summary fields are missing.
    #  assert(!hit['fields'].key?('title'), "Expected summary field 'title' to be missing (bug reproduced) in #{hit}")
    #  assert(!hit['fields'].key?('id'), "Expected summary field 'id' to be missing (bug reproduced) in #{hit}")
    #end
  end

end
