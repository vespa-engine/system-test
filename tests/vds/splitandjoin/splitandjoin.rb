# Copyright Vespa.ai. All rights reserved.
require 'vds_multi_model_test'

class SplitAndJoin < VdsMultiModelTest

  def setup
    @valgrind=false

    set_owner("vekterli")
    deploy_app(default_app.bucket_split_count(6))
    start
  end

  def test_dynamicsplitbuckets_count
    docids = []

    20.times { |i|
      docid = "id:storage_test:music:n=1:" + i.to_s
      vespa.document_api_v1.put(Document.new("music", docid))
    }

    # Wait until everything is split up ok
    vespa.storage["storage"].wait_until_ready

    # Verify that we have 4 buckets
    buckets = vespa.storage["storage"].storage["0"].get_bucket_count
    assert_equal(5, buckets)

    # Delete most of the docs
    16.times { |i|
      docid = "id:storage_test:music:n=1:" + i.to_s
      vespa.document_api_v1.remove(docid)
    }

    # Redeploy with lower split size.
    deploy_app(default_app.bucket_split_count(5).bucket_split_size(200))

    vespa.storage["storage"].wait_until_ready

    # Shouldn't join since we still have meta entries for the buckets.
    buckets = vespa.storage["storage"].storage["0"].get_bucket_count
    assert_equal(5, buckets)
  end

  def teardown
    stop
  end

end
