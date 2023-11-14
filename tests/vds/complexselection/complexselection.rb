# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class ComplexSelection < VdsTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app.sd(selfdir + "banana.sd"))
    start
  end

  def test_complex_selection
    # Put docment with array attribute using vespa-feeder
    feedfile(selfdir+"complex.xml")

    assert_output([ "id:test:banana::1", "id:test:banana::2", "id:test:banana::3" ], "banana.stringmap")
    assert_output([ "id:test:banana::1", "id:test:banana::2", "id:test:banana::3" ], "banana.stringmap{5}")
    assert_output([ "id:test:banana::1", "id:test:banana::3" ], "banana.stringmap{3}")
    assert_output([ "id:test:banana::2", "id:test:banana::3" ], "banana.stringmap{4} == \"buongiorno\"")
    assert_output([ "id:test:banana::1", "id:test:banana::3" ], "banana.stringmap.key == \"3\"")

    assert_output([ "id:test:banana::1", "id:test:banana::3" ], "banana.structmap")
    assert_output([ "id:test:banana::3" ], "banana.structmap.value.title == \"arrivederci\"")
    assert_output([ ], "banana.structmap{2}.title == \"arrivederci\"")
    assert_output([ ], "banana.structmap{2}.structfield")

    assert_output([ "id:test:banana::1", "id:test:banana::3" ], "banana.structarr[$x].title == \"star wars\" AND banana.structarr[$x].director == \"george lucas\"")
    assert_output([ "id:test:banana::1" ], "banana.structarr[$x].title == \"empire strikes back\" AND banana.structarr[$x].director == \"irwin kershner\"")
  end

  def assert_output(correct, expr)
    assert_equal(correct.sort, getdocumentids(vespa.storage["storage"].storage["0"].execute("vespa-visit --xmloutput -s '" + expr + "'")).sort)
  end

  def getdocumentids(output)
    retval = []
    output.each_line { |s|
	if (s =~ /documentid=\"(.*)\"/)
          retval.push($1)
        end
    }
    return retval
  end

  def teardown
    stop
  end
end

