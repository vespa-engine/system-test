# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'document_set'
require 'indexed_search_test'
require 'search/grouping_adv/grouping_base'

class GroupingIndexed < IndexedSearchTest

  def timeout_seconds
    1800
  end

  include GroupingBase

  def test_advgrouping_fs4_notworking
    deploy_app(singlenode_2cols_realtime(selfdir+"test.sd"))
    start
    feed_docs

    querytest_failing_common
  end

  def test_advgrouping_fs4
    deploy_app(singlenode_2cols_realtime(selfdir+"test.sd").threads_per_search(1))
    start
    feed_docs

    querytest_common

    # Test for bug http://bug.corp.yahoo.com/show_bug.cgi?id=3393155
    result = search("query=sddocname:test&ranking=default&streaming.selection=&tracelevel=2&select=all%28group%28a%29 each%28output%28count%28%29,sum%28n%29,avg%28n%29,max%28n%29,min%28n%29,xor%28n%29%29%29%29")
    exp_fill_default = "^.*fill to dispatch.*rankprofile\\[default\\].*$"
    assert(result.xmldata.match(exp_fill_default) != nil, "Expected #{exp_fill_default} in result")
    result = search("query=sddocname:test&streaming.selection=&ranking=unranked&tracelevel=2&select=all%28group%28a%29 each%28output%28count%28%29,sum%28n%29,avg%28n%29,max%28n%29,min%28n%29,xor%28n%29%29%29%29")
    exp_fill_unranked = "^.*fill to dispatch.*rankprofile\\[unranked\\].*$"
    assert(result.xmldata.match(exp_fill_unranked) != nil, "Expected #{exp_fill_unranked} in result")

    # Test session cache accuracy
    check_query("all%28group%28a%29 max%281%29 each%28output%28count%28%29%29%29%29&groupingSessionCache=false", "#{selfdir}/accuracy1.xml")
    check_query("all%28group%28a%29 max%281%29 each%28output%28count%28%29%29%29%29&groupingSessionCache=true", "#{selfdir}/accuracy2.xml")
    check_query("all%28group%28a%29 max%281%29 precision%28100%29 each%28output%28count%28%29%29%29%29&groupingSessionCache=true", "#{selfdir}/accuracy1.xml")

    # Test debug function
    check_fullquery("/?query=s:aaa&hits=0&timeout=5.0&select=all%28group%28debugwait%28a, 0.1, true%29%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/debug1.xml")
    check_fullquery("/?query=s:aaa&hits=0&timeout=5.0&select=all%28group%28debugwait%28a, 0.1, false%29%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/debug2.xml")
    startstamp = Time.now.to_i
    check_fullquery("/?query=s:aaa&hits=0&timeout=5.0&select=all%28group%28debugwait%28a, 1.0, true%29%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/debug3.xml")
    endstamp = Time.now.to_i
    duration = endstamp - startstamp
    assert(duration >= 1)
    puts "Duration: #{duration}"
    check_fullquery("/?query=sddocname:test&timeout=5.0&hits=0&select=all%28group%28debugwait%28a, 20.0, true%29%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/debug4.xml")
  end


  def test_advgrouping_use_exact_group_count_when_applicable
    set_owner("bjorncs")
    deploy_app(SearchApp.new.sd(selfdir+"test2.sd"))
    start

    docs = DocumentSet.new
    (1..2048).each do |a|
      doc = Document.new("test2", "id:ns:test2::#{a}")
      doc.add_field("a", a.to_s)
      docs.add(doc)
    end
    feedfile = dirs.tmpdir + "input.xml"
    docs.write_xml(feedfile)

    feed_and_wait_for_docs("test2", 2048, {:file => feedfile})

    assert_count_equals("select=all(group(a)output(count()))", 2025)
    assert_count_equals("select=all(group(a)output(count())each(output(count())))", 2048)
    assert_count_equals("select=all(group(a)max(5)output(count())each(output(count())))", 2025)
    assert_count_equals("select=all(group(a)max(4000)output(count())each(output(count())))", 2048)
    assert_count_equals("select=all(group(a)max(2025)output(count())each(output(count())))", 2025)
  end

  def test_hits_in_best_group
    set_owner("bjorncs")
    deploy_app(singlenode_2cols_realtime(selfdir+"test.sd").threads_per_search(1))
    start
    feed_docs
    check_query("all(group(a)max(1)each(each(output(summary()))))", "#{selfdir}/best-group1.xml")
  end

  def assert_count_equals(query, count)
    query_url = "/?query=sddocname:test2&nocache&hits=0&format=json&#{query}"
    tree = search(query_url).json
    assert_equal(count, tree["root"]["children"][0]["fields"]["count()"])
 end


  # Test to make sure that the session ids from the qrs should not conflict in
  # case query times out.
  def test_advgrouping_sessionid_conflict
    set_owner("bjorncs")
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_docs

    querystr = "/?query=sddocname:test&timeout=5.0&nocache&hits=0&select=all%28group%28a%29 each%28group%28b%29 each%28group%28c%29 each%28group%28d%29 each%28output%28count%28%29%29%29%29%29%29%29"
    timeout_start = 0.001
    timeout_inc = 0.001
    timeout_end = 1.0
    numqueries = 0
    errors = 0
    while (timeout_start < timeout_end)
      begin
        error = runquery(querystr, timeout_start)
      rescue EOFError
        puts "Got EOF from qrserver with timeout: #{timeout_start}"
        error = true
      end
      numqueries += 1
      if !error then
        break
      end
      errors += 1
      timeout_start += timeout_inc
    end

    puts "Ran #{numqueries} queries, which resulted in #{errors} errors"
    # Should at least fail once
    assert(errors != 0)
    qrserver = vespa.container.values.first
    qrserver.stop
    qrserver.start
    wait_for_hitcount("query=sddocname:test", 28)

    # Should all work fine
    for i in 0..numqueries do
      check_fullquery("/?query=sddocname:test&timeout=5.0&nocache&hits=0&select=all%28group%28a%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/session.xml")
    end
  end

end
