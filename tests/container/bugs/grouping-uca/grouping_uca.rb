# Copyright Vespa.ai. All rights reserved.
require "search_container_test"

class GroupingUCA < SearchContainerTest

  def setup
    set_owner("hmusum")
    set_description("Test order of grouping output when using UCA (Unicode Collation Algorithm) for single- and multivalued fields")
  end

  def test_bug4390127
    deploy(selfdir+"app")
    start
    feed(:file => selfdir+"feed.json")
    assert_xml_result_with_timeout(20, 'sddocname:music&hits=0&nocache&streaming.selection=true&select=all(group(lang)order(max(uca(lang,"sv"))) each(output(count())))', selfdir + "single.xml")
    assert_xml_result_with_timeout(20, 'sddocname:music&hits=0&nocache&streaming.selection=true&select=all(group(lang)order(max(uca(tracks,"sv"))) each(output(count())))', selfdir + "multi.xml")
  end


end
