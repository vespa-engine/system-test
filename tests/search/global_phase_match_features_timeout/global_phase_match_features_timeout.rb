# Copyright Vespa.ai. All rights reserved.
require 'json'
require 'indexed_only_search_test'

# When a content node reaches its timeout while extracting match features,
# the hits it has not reached yet must not be sent to the container with a
# number (0.0) in place of a tensor match feature. Otherwise the global
# phase fails the whole query with:
#   'attribute(tags)' must be of type tensor<float>(tag{}), not tensor()
#
# Extracting match features is slow only on the content node with
# distribution key 0 (see test.sd).
class GlobalPhaseMatchFeaturesTimeout < IndexedOnlySearchTest

  DOCS = 600
  QUERY = "query=sddocname:test&ranking=slow_match_features&timeout=10.0"

  def setup
    @valgrind = false
    set_owner("boeker")
    set_description("Test that a timeout during match feature extraction does not break global-phase ranking")
  end

  def test_one_content_node
    deploy_and_feed(1)

    # Extracting match features for all 600 hits takes 600 * 50 ms = 30 s,
    # so the content node reaches its timeout and returns no hits.
    result = search_and_print(QUERY)
    assert_no_type_errors(result)
    assert_equal(0, result.hitcount)
  end

  def test_two_content_nodes
    deploy_and_feed(2)

    # The slow content node gets about half of the hits. Extracting their
    # match features takes about 300 * 50 ms = 15 s, so it reaches its timeout
    # and returns no hits. The other content node returns all its hits.
    result = search_and_print(QUERY)
    assert_no_type_errors(result)
    assert(result.hitcount > 0 && result.hitcount < DOCS,
           "Expected only the hits of one content node, got #{result.hitcount} of #{DOCS}")

    # The global phase re-ranked the returned hits: sum(attribute(tags)) is 1.0.
    assert(result.hit.size > 0, "Expected hits")
    result.hit.each do |hit|
      assert_equal(1.0, hit.field["relevancy"].to_f)
    end
  end

  def search_and_print(query)
    # Not search(): it adds its own timeout, which is scaled up for
    # instrumented builds. This test depends on the exact timeout in QUERY.
    result = search_base(query)
    puts "Search reply:\n#{JSON.pretty_generate(result.json)}"
    result
  end

  def deploy_and_feed(content_nodes)
    # One thread per search, so match features are extracted one hit at a time.
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").num_parts(content_nodes).threads_per_search(1))
    start
    feed_and_wait_for_docs("test", DOCS, :file => write_docs)
  end

  def assert_no_type_errors(result)
    errors = result.json['root']['errors'] || []
    type_errors = errors.select { |error| error['message'].to_s.include?('must be of type') }
    assert(type_errors.empty?, "Global phase got match features of the wrong type: #{type_errors}")
  end

  def write_docs
    file = dirs.tmpdir + "docs.json"
    docs = (1..DOCS).map do |i|
      { "put" => "id:test:test::#{i}",
        "fields" => { "id" => i, "tags" => { "cells" => { "a" => 1.0 } } } }
    end
    File.write(file, JSON.pretty_generate(docs))
    file
  end

end
