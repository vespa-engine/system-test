# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class GarbageCollection < VdsTest

  def setup
    @valgrind=false
    set_owner("vekterli")
  end

  def deploy_gc_app(gc_enabled)
    deploy_app(default_app.doc_type("music", "music.year < 6").
               garbagecollection(gc_enabled).garbagecollectioninterval(1))
  end

  def feed_test_docs
    10.times { |i|
      doc = Document.new("music", "id:storage_test:music:n=1234:#{i}").
        add_field("year", i)
      vespa.document_api_v1.put(doc)
    }
  end

  def wait_until_n_docs_remain(n)
    while vespa.storage["storage"].get_document_count() != n do
      sleep 1
    end
  end

  def assert_that_garbage_collectable_docs_are_gone
    10.times { |i|
      doc = vespa.document_api_v1.get("id:storage_test:music:n=1234:#{i}")
      if (i > 5)
        assert_equal(nil, doc)
      else
        assert(doc != nil)
      end
    }
  end

  def crosscheck_bucket_consistency
    vespa.storage["storage"].wait_until_ready
  end

  def test_garbagecollection
    deploy_app(default_app)
    start

    feed_test_docs
    deploy_gc_app(true)

    wait_until_n_docs_remain(6)
    # Ensure we only removed what we _should_ have removed.
    assert_that_garbage_collectable_docs_are_gone

    # Before doing a final crosscheck validation of bucket state, ensure
    # that GC has been disabled so that the bucket state parsing code
    # does not get confused by intermittent GC operations being scheduled.
    config_generation = get_generation(deploy_gc_app(false)).to_i
    wait_for_reconfig(config_generation)
    crosscheck_bucket_consistency
  end

  def teardown
    stop
  end
end

