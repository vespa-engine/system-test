# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class TensorFlowValidate < IndexedSearchTest

  def setup
    @valgrid = false
    set_owner("lesters")
    set_description("Validate TensorFlow import")
  end

  def teardown
    stop
  end

  def do_not_test_tensorflow
    add_bundle_dir(selfdir + "mnist_bundle", "mnist")
    deploy(selfdir + "app/")
    start

    feed_and_wait_for_docs("mnist", 100, :file => selfdir + "feed.json")

    10.times do |i|
      result = search("query=sddocname:mnist&hits=10&class=#{i}&searchChain=stateless")
      result.hit.each { |hit|
        assert((hit.field["relevance"].to_f - hit.field["tf_relevance"].to_f).abs < 0.00001)
      }
    end

  end

end

