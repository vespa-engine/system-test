# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require 'distributionstates'

class DistributionStatesTest < Test::Unit::TestCase
  class StubTest
    def output(str)
      puts str
    end
  end

  def initialize(*args)
    super(*args)
    @testcase = StubTest.new
  end

  def test_missing_json
    state = DistributionStates.new(@testcase, nil)
    assert(state.matching_states)
    assert(state.bucket_spaces.empty?)
  end

  def test_missing_published
    json = JSON.parse('{ }')
    state = DistributionStates.new(@testcase, json)
    assert(state.matching_states)
    assert(state.bucket_spaces.empty?)
  end

  def test_baseline_only
    json = JSON.parse('{ "published": { "baseline": "version:10 storage:3 distributor:3" } }')
    state = DistributionStates.new(@testcase, json)
    assert(state.matching_states)
    assert(state.bucket_spaces.empty?)
  end

  def test_matching_states
    json = JSON.parse('{ "published": { "baseline": "version:10 storage:3 distributor:3", "bucket-spaces": [ { "name" : "default", "state" : "version:10 storage:3 distributor:3" } ] } }')
    state = DistributionStates.new(@testcase, json)
    assert(state.matching_states)
    assert(!state.bucket_spaces.empty?)
    assert(state.bucket_spaces.has_key?('default'))
    assert(!state.bucket_spaces.has_key?('global'))
  end

  def test_not_matching_states
    json = JSON.parse('{ "published": { "baseline": "version:10 storage:3 distributor:3", "bucket-spaces": [ { "name" : "default", "state" : "version:10 storage:4 distributor:3" } ] } }')
    state = DistributionStates.new(@testcase, json)
    assert(!state.matching_states)
  end
end
