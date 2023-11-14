# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class JoinBucketCount < VdsTest

  def setupApplication(splitCount)
    get_generation(deploy_app(
               default_app.num_nodes(2).redundancy(1).bucket_split_count(splitCount).bucket_split_size(50000).
               config(ConfigOverride.new("vespa.config.content.persistence").add("revert_time_period", "1")).
               config(ConfigOverride.new("vespa.config.content.persistence").add("keep_remove_time_period", "1"))))
  end

  def setup
    @valgrind=false

    set_owner("vekterli")

    setupApplication(9)
    start
  end

  def buckets_on_node(node)
    vespa.storage['storage'].storage[node.to_s].get_bucket_count
  end

  def wait_for_bucket_count(wantedcount, timeout = 300)
    for i in 0..timeout do
      count = buckets_on_node(0) + buckets_on_node(1)
      return if count == wantedcount
      sleep 1
      puts "Bucket count: #{count} != Wanted count: #{wantedcount}"
    end
    assert(false, "Bucket count did not become #{wantedcount} within timeout of #{timeout} seconds.")
  end

  def test_join_count
    10.times { |i|
      doc = Document.new("music", "id:storage_test:music:n=1234:" + i.to_s)
      vespa.document_api_v1.put(doc)
    }

    vespa.storage["storage"].wait_until_ready

    wait_for_bucket_count(2)

    gen = setupApplication(50)
    # Ensure that config is visible on nodes so we won't race with wait_until_ready
    vespa.storage['storage'].wait_until_content_nodes_have_config_generation(gen.to_i)

    8.times { |i|
      vespa.document_api_v1.remove("id:storage_test:music:n=1234:" + i.to_s)
    }

    vespa.storage["storage"].wait_until_ready

    wait_for_bucket_count(1)
  end

  def teardown
    stop
  end
end

