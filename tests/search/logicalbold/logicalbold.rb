# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class LogicalBold < IndexedSearchTest

  def setup
    set_owner("bratseth")
    deploy_app(SearchApp.new.sd("#{selfdir}/common_different_name_to_doctype.sd").
               cluster(SearchCluster.new("logical").
                       sd("#{selfdir}/book.sd").
                       sd("#{selfdir}/music.sd")).
               cluster(SearchCluster.new("video").
                       sd("#{selfdir}/video.sd")))
    start
  end

  def test_logicalbold
    puts "Description: Test bolding"
    puts "Component: Config, Indexing, Search etc"

    feed_and_wait_for_docs("video", 3, :file => "#{selfdir}/all.xml", :cluster => "logical")

    puts "Query: sanity checks"
    wait_for_hitcount("query=sddocname:book",  1);
    wait_for_hitcount("query=sddocname:music", 2);
    wait_for_hitcount("query=sddocname:video", 3);

    puts "Query: bolding (book)"
    assert_field("query=x", selfdir+"x.result", "author", true)
    assert_field("query=x", selfdir+"x.result", "title", true)

    puts "Query: dynteaser (book)"
    assert_field("query=elected", "#{selfdir}/elected.result", "description")

    puts "Query: bolding (video)"
    assert_field("query=(rooney+douglas+julia+stiles)", selfdir+"actors.result", "actor", true)
    assert_field("query=(rooney+douglas+julia+stiles)", selfdir+"actors.result", "disp_actor", true)

    puts "Query: bolding (music)"
    assert_field("query=stash", "#{selfdir}/stash.result", "title", true)

    puts "Query: bolding (all)"
    assert_field("query=the", "#{selfdir}/the.result", "title", true)

    puts "Query: bolding (different summary)"
    assert_field("query=the&summary=smallsum", "#{selfdir}/the.result", "title", true)
    puts "Query: bolding and ranking (different summary)"
    assert_result("query=the&summary=smallsum&skipnormalizing&sorting=-[rank]%20weight", "#{selfdir}/the.small.result", nil, ["title"])
  end

  def teardown
    stop
  end

end
