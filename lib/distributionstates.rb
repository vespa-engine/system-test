# Copyright Vespa.ai. All rights reserved.
require 'json'
require 'nodetypes/storageclusterstate'

class DistributionStates
  attr_reader :baseline, :bucket_spaces, :matching_states

  def initialize(testcase, json)
    @baseline = nil
    @bucket_spaces = Hash.new
    @matching_states = true
    parse(testcase, json)
  end

  def parse(testcase, json)
    if json.nil?
      testcase.output("Missing json, using empty distribution state")
      @baseline = StorageClusterState.new(testcase, "")
      return
    end
    published = json['published']
    if published.nil?
      testcase.output("Failed to get published distribution state: " + json.to_s)
      @baseline = StorageClusterState.new(testcase, "")
      return
    end
    @baseline = StorageClusterState.new(testcase, published['baseline'])
    bucket_spaces = published['bucket-spaces']
    if !bucket_spaces.nil?
      bucket_spaces.each do |bucket_space|
        name = bucket_space['name']
        state = StorageClusterState.new(testcase, bucket_space['state'])
        @bucket_spaces[name] = state
        if !(state == @baseline)
          @matching_states = false
        end
      end
    end
  end
end
