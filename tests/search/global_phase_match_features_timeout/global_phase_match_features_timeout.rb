# Copyright Vespa.ai. All rights reserved.
require 'json'
require 'indexed_only_search_test'

# When a content node reaches its timeout while extracting match features,
# the hits it has not reached yet must not be sent to the container with a
# number (0.0) in place of a tensor match feature. Otherwise the global
# phase fails the whole query with:
#   'attribute(tags)' must be of type tensor<float>(tag{}), not tensor()
class GlobalPhaseMatchFeaturesTimeout < IndexedOnlySearchTest

  DOCS = 300

  def setup
    @valgrind = false
    set_owner("boeker")
    set_description("Test that a timeout during match feature extraction does not break global-phase ranking")
    # One thread per search, so match features are extracted one hit at a time.
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").threads_per_search(1))
    start
  end

  def test_timeout_during_match_feature_extraction
    feed_and_wait_for_docs("test", DOCS, :file => write_docs)

    # Extracting match features for all 300 hits takes 300 * 50 ms = 15 s,
    # so the content node reaches its timeout halfway through.
    result = search_base("query=sddocname:test&ranking=slow_match_features&timeout=10.0")
    errors = result.json['root']['errors'] || []
    puts "Errors: #{errors}"

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
