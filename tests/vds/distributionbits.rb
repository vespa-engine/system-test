# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class DistributionBitTest < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.distribution_bits(8))
    start
  end

  def teardown
    stop
  end

  def get_split_level
    s = vespa.storage["storage"].storage["0"].get_status_page("/systemstate")
    if (s =~ /minimum used bits (\d+)/)
        return $1.to_i
    end
    raise "Failed to find split level in status page: #{s}"
  end

  def wait_for_split_level(wanted)
    while (1)
      split_level = get_split_level()
      if (split_level == wanted)
        return
      end
      sleep(5)
    end
  end

  def get_split_count()
    metrics = vespa.storage["storage"].storage["0"].get_metrics_matching("vds.filestor.alldisks.allthreads.splitbuckets.count")
    puts metrics
    return metrics.count
  end

  def test_increasing_distribution_bits
    puts "FEEDING INITIAL DOCS"
    doc = Document.new("music", "id:test:music:n=1:doc1")
    vespa.document_api_v1.put(doc)
    doc = Document.new("music", "id:test:music:n=1:doc2")
    vespa.document_api_v1.put(doc)

    assert_equal(8, get_split_level())
    puts "Have performed #{get_split_count()} splits"
    #assert_equal(2, get_split_count())

    deploy_app(default_app.distribution_bits(18))

    wait_for_split_level(18)

    puts "Have performed #{get_split_count()} splits"
    #assert_equal(3, get_split_count())
  end

end

