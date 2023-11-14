# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class Split < VdsTest

  def setup
    @numbuckets=20
    set_owner("vekterli")
    make_feed_file("docs_test_split_buckets.xml", "music", 0, @numbuckets - 1, 6)
  end

  def timeout_seconds
    1200
  end

  def deploy_and_start(bucket_split_count)
    deploy_app(default_app.bucket_split_count(bucket_split_count))
    start
  end

  def teardown
    stop
    File.delete("docs_test_split_buckets.xml")
  end

  def get_16bits_mask(i)
    h = i.to_s(16)
    p=""
    z=(4-h.length)
    z.to_i.times{
      p="0"+p
    }
    return p+h
  end

  def test_split_buckets
    deploy_and_start(5)

    vespa.storage["storage"].wait_until_cluster_up # Is this necessary?

    set_description("")

    feedfile("docs_test_split_buckets.xml")

    vespa.storage["storage"].wait_until_ready(300)

    @numbuckets.times{|i|
      a=""
      retries=0
      until a.length == 2 || retries == 3
        regexp = /#{get_16bits_mask(i)}$/
        buckets = vespa.storage['storage'].storage['0'].get_buckets()['default'].keys.select{|id| id.match regexp}
        puts "#{get_16bits_mask(i)} \n#{buckets}"
        a = buckets
        retries = retries + 1
      end

      if a.length != 2
        puts "Failed to split bucket #{get_16bits_mask(i)}"
      end

      assert_equal(2, a.length)
    }

    # Files with data from only one user should be split once to correct
    # split point. But we can get some more splits, as a single node system
    # starts with only 1 min split bit. To generate numbuckets buckets we do
    # at maximum 2 * numbuckets splits, and then we should do at maximum
    # numbuckets splits to get to correct point. Thus, we should never split
    # more than 3 * numbuckets times.
    metrics = vespa.storage["storage"].distributor["0"].get_metrics_matching("vds.idealstate.split_bucket.done_ok")
    puts metrics
    # FIXME Proton doesn't have the "split multiple bits at once" optimization VDS had,
    # so we get a lot more splits than the test would otherwise expect.
    #assert(3 * @numbuckets > metrics["vds.idealstate.split_bucket.done_ok"]["count"])
  end

end

