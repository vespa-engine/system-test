# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Bug4917478 < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test bug 4917478, bolding in grouping issues")
  end

  def test_bug4917478
    timeout=2.0
    deploy_app(SearchApp.new.sd(selfdir+"bold.sd"))
    start
    feed(:file => selfdir+"feed.xml")
    wait_for_hitcount("query=sddocname:bold", 1)

    ogrp="all(group(iprd)+each(output(count())))"
    grpA="all(group(pmid)+max(5)+each(output(count())+max(1)+each(output(summary(default)))))"
    grpB="all(group(pmid)+max(5)+each(output(count())+max(1)+each(output(summary(catg)))))"

    gr2A="all(#{ogrp}+#{grpA})"
    gr2B="all(#{ogrp}+#{grpB})&summary=catg"
    gr2C="all(#{ogrp}+#{grpB})"

    assert_xml_result_with_timeout(timeout, "query=iphone",                selfdir+"result1.xml")
    assert_xml_result_with_timeout(timeout, "query=iphone&select=#{gr2A}", selfdir+"result2.xml")
    assert_xml_result_with_timeout(timeout, "query=iphone&select=#{gr2B}", selfdir+"result3.xml")
    assert_xml_result_with_timeout(timeout, "query=iphone&select=#{gr2C}", selfdir+"result4.xml")

  end

  def teardown
    stop
  end

end
