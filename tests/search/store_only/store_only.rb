# Copyright Vespa.ai. All rights reserved.
require 'search_test'

class StoreOnly < SearchTest

  def setup
    set_owner("yngve")
    deploy("#{selfdir}/app")
    start
  end

  def test_store_only
    feed_and_wait_for_docs("index_me", 1, :file => "#{selfdir}/input.json");
  end

  def teardown
    stop
  end

end
