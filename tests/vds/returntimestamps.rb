# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'vds_test'

class ReturnTimestamps < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app)
    start
  end

  def test_return_timestamps
    # Put document using vespa-feeder
    output = feedfile(selfdir+"data/returntimestamps.xml", { :trace => 9, :maxpending => 1 })

    set = Set.new
    output.each_line { |s|
	if (s =~ /Modification timestamp/)
          set.add(s[53..60])
        end
    }

    assert_equal(5, set.length);
  end

  def teardown
    stop
  end
end

