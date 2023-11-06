# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class JoinSparseBucketsTest < VdsTest

  def setup
    set_owner("vekterli")
  end

  def timeout_seconds
    600
  end

  def teardown
    stop
  end

  def deploy_with_params(params={})
    deploy_app(default_app.
               num_nodes(params[:num_nodes] || 1).
               redundancy(params[:redundancy] || 1).
               bucket_split_count(params[:split_count]).
               min_storage_up_ratio(0.1).
               config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
                      add('enable_join_for_sibling_less_buckets', 'true').
                      add('enable_inconsistent_join', params[:inconsistent_join] ? 'true' : 'false')))
  end

  def make_doc_id(n)
    "id:test:music:n=1:doc#{n}"
  end

  def feed_doc(id)
    doc = Document.new("music", id)
    vespa.document_api_v1.put(doc)
  end

  def get_cluster
    vespa.storage['storage']
  end

  def get_storage_node
   get_cluster.storage['0']
  end

  def enumerate_buckets
    vespa.adminserver.execute("vespa-stat --user 1 | grep BucketId | cut -d'(' -f 3 | cut -d')' -f 1").split
  end

  def assert_that_sparse_bucket_exists
    buckets = enumerate_buckets()
    sibling_count = {}
    buckets.each do |b|
      if b !~ /^0x([a-f0-9]+)$/
        flunk "Bucket #{b} not recognized as valid format"
      end
      bucket = $~[1]
      bid = bucket.to_i(16)
      used_bits = bid >> (64 - 6)
      base_bucket = bid & ~(1 << (used_bits - 1))
      puts "#{bucket} -> #{bid.to_s(16)} (#{used_bits} bits) -> base #{base_bucket.to_s(16)}"
      if sibling_count.has_key? base_bucket
        assert_equal(1, sibling_count[base_bucket])
        sibling_count[base_bucket] = 2
      else
        sibling_count[base_bucket] = 1
      end
    end

    sparse_buckets = 0

    sibling_count.each do |base_bucket, count|
      puts "base bucket #{base_bucket.to_s(16)} has #{count} siblings"
      sparse_buckets += 1 if count == 1
    end

    assert sparse_buckets > 0
  end

  def feed_n_docs_via_gateway(doc_count)
    doc_count.times do |i|
      feed_doc(make_doc_id(i))
    end
  end

  def test_sparse_buckets_can_be_joined
    set_description("Test that a sparsely populated bucket tree can be " +
                    "compacted (joined) down to its optimal representation")

    # By splitting out so massively for a single user, we basically guarantee
    # that we won't get a nice, even distribution that leads to 2 split targets
    # per split. As such, we'll get a sparse bucket tree by default!
    deploy_with_params(:split_count => 2)
    start
    doc_count = 40
    feed_n_docs_via_gateway(doc_count)
    wait_until_ready
    assert_that_sparse_bucket_exists

    # We want everything down to 1 single bucket.
    gen = get_generation(deploy_with_params(:split_count => 100)).to_i
    # Ensure that config is visible on nodes (and triggering ideal state ops) before running wait_until_ready
    get_cluster.wait_until_content_nodes_have_config_generation(gen)
    wait_until_ready

    vespa.adminserver.execute("vespa-stat --user 1")
    buckets_after = enumerate_buckets
    assert_equal(1, buckets_after.size)
    assert_equal(doc_count, get_cluster.get_document_count('id.user == 1'))
  end

end
