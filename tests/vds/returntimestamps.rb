# Copyright Vespa.ai. All rights reserved.

require 'vds_test'

class ReturnTimestamps < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app)
    start
  end

  def test_return_timestamps
    output = feedfile(selfdir+"data/returntimestamps.json", { :client => :vespa_feed_client, :trace => 9, :maxpending => 1, :show_all => true })

    set = Set.new
    # Output depends on client, this works with vespa-feed-client
    output.each_line { |s|
	if (s =~ /Modification timestamp: (\d+)/)
          set.add($1)
        end
    }

    assert_equal(5, set.length);
  end

  def teardown
    stop
  end

end
