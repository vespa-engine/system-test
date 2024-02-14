# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Bug_401679 < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Use index info for all document types in a cluster.")
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new("shortcuts").
                       sd("#{selfdir}/newssummary.sd").
                       doc_type('newssummary', 'newssummary.where=="shortcut"')).
               cluster(SearchCluster.new("normal").
                       sd("#{selfdir}/newssummary.sd").
                       sd("#{selfdir}/newsarticle.sd").
                       doc_type('newssummary', 'newssummary.where=="norm"').
                       doc_type('newsarticle')))
    start
  end

  def test_correct_indexinfo
    feed_and_wait_for_docs("newsarticle", 3, :file => "#{selfdir}/all.xml", 
                           :cluster => "shortcuts")

    puts "Query: sanity checks"
    wait_for_hitcount("query=sddocname:newsarticle", 3); # 3 from shortcuts
    wait_for_hitcount("query=sddocname:newssummary", 3); # 3 from normal

    assert_hitcount("query=title:x", 1);
    assert_hitcount("query=title:stash", 1);
    assert_hitcount("query=title:dollar", 1);
    assert_hitcount("query=title:adventures", 1);
    assert_hitcount("query=title:murder", 1);
    assert_hitcount("query=title:hate", 1);

    assert_hitcount("query=city:dallas.tx&search=newsarticle", 1);
    assert_hitcount("query=city:michael.douglas&search=newsarticle", 1);
    assert_hitcount("query=city:viggo.mortensen&search=newsarticle", 1);
    assert_hitcount("query=city:%22Dexter+Brown%22&search=newsarticle", 1);
    assert_hitcount("query=city:%22Julia+Stiles%22&search=newsarticle", 1);

    assert_hitcount("query=city:dallas.tx&search=normal", 1);
    assert_hitcount("query=city:michael.douglas&search=normal", 1);
    assert_hitcount("query=city:viggo.mortensen&search=normal", 1);
    assert_hitcount("query=city:%22Dexter+Brown%22&search=normal", 1);
    assert_hitcount("query=city:%22Julia+Stiles%22&search=normal", 1);

  end

  def teardown
    stop
  end

end
