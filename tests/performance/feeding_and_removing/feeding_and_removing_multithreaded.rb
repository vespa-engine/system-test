# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/feeding_and_removing/feeding_and_removing_base.rb'

class FeedingAndRemovingMultithreaded < FeedingAndRemovingBase

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def test_feed_refeed_remove_multithreaded
    set_description("Test multi-threaded feed performance with 200K text documents (feed, re-feed, remove)")

    deploy_app(create_app(0, 1))
    start
    run_feed_refeed_remove_test(DELAY_0_SEC, INDEX_THREADS_1, 100000)

    clean_indexes_and_deploy_app(create_app(0, 2))
    run_feed_refeed_remove_test(DELAY_0_SEC, INDEX_THREADS_2, 100000)

    clean_indexes_and_deploy_app(create_app(0, 4))
    run_feed_refeed_remove_test(DELAY_0_SEC, INDEX_THREADS_4)

    clean_indexes_and_deploy_app(create_app(0, 8))
    run_feed_refeed_remove_test(DELAY_0_SEC, INDEX_THREADS_8)
  end

  def teardown
    super
  end

end
