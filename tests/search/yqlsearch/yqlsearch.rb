# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class YqlSearch < IndexedSearchTest

  # This is in search because this test needs to be expanded with
  # "funky stuff" which needs to be tested in a search context.

  def setup
    set_owner("arnej")
    set_description("Test searching with YQL+")
  end

  def test_yqlsearch
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(selfdir+"music.sd"))
    start_feed_and_check
  end

  def start_feed_and_check
    start
    feed_and_check
  end

  def feed_and_check
    feed(:file => selfdir+"music.3.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 3)


    assert_hitcount("query=select%20ignoredfield%20from%20ignoredsource%20where%20default%20contains%20%22country%22%3B&type=yql", 1)
    assert_hitcount("query=select%20ignoredfield%20from%20ignoredsource%20where%20score%20%3D%202%3B&type=yql", 1)
    assert_hitcount("query=select%20ignoredfield%20from%20ignoredsource%20where%20default%20contains%20%28%5B%7B%22distance%22%3A1%7D%5Dnear%28%22modern%22%2C%22electric%22%29%29%3B&type=yql&tracelevel=1", 1)

    assert_result_matches("query=select%20ignoredfield%20from%20ignoredsource%20where%20wand%28name%2C%7B%22electric%22%3A10%2C%22modern%22%3A20%7D%29%3B&ranking=weightedSet&type=yql&tracelevel=1", selfdir + "result.xml", "field name=\"relevancy\"" )


    # YQL: select * from sources * where rank(title contains "blues",title contains "country") | all(group(score)each(output(count())));

    yql = 'select+%2A+from+sources+%2A+where+rank%28title+contains+%22blues%22%2Ctitle+contains+%22country%22%29+%7C+all%28group%28score%29each%28output%28count%28%29%29%29%29%3B'
    assert_result_matches("/search/?yql=#{yql}", selfdir + "group-result.xml")
  end

  def teardown
    stop
  end

end
