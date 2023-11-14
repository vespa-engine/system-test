# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class StoreOnly < SearchTest

  def setup
    set_owner("yngve")
    deploy("#{selfdir}/app")
    start
  end

  def test_store_only
    feed_and_wait_for_docs("index_me", 1, :file => "#{selfdir}/input.xml");
  end

  def teardown
    stop
  end

end
