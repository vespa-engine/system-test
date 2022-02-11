# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DistanceRanking < IndexedSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("arnej")
    set_description("Test distance ranking")
  end

  def initialize(*args)
    super(*args)
  end

  def test_distance_ranking
    deploy_app(SearchApp.new.sd(selfdir+"local.sd"))
    start_feed_and_check
  end

  def start_feed_and_check
    start
    feed_and_wait_for_docs("local", 54, :file => selfdir+"local-docs.xml")

    puts "Query: sanity checks"
    assert_hitcount("query=sddocname:local", 54);

    loc = "2,98987987,12123123,5500,4,10000,1"
    run_query("query=something&location=(#{loc},4199183343)", selfdir+"some.result.json")
    run_query("query=something&location=(#{loc},CalcLatLon)", selfdir+"some.result.json")
    run_query("query=something&pos.ll=N12.123123%3BE98.987987", selfdir+"some.result.json")

    # no ranking, so sort results by id
    qq = "query=poi&hits=99"
    run_query("#{qq}&sorting=id", selfdir+"allhits.result.json")

    loc = "location=[2,-118000000,33000000,-116000000,34000000]"
    run_query("#{qq}&#{loc}", selfdir+"dist_cutoff.result.json", "id")
    run_query("#{qq}&#{loc}", selfdir+"dist_cutoff.result.json", "id")

    # ranked results

    # x,y,radius
    # 2d, x, y, radius, ranktable 3, rankmultiplier 2000, rankreplace=true, optional aspectratio
    loc = "-117752900,33544000,30000,3,2000,1"
    run_query("#{qq}&location=(2,#{loc})", selfdir+"distranking.result.json")
    run_query("#{qq}&location=(2,#{loc},3579690824)", selfdir+"aspectranking.result.json")
    run_query("#{qq}&location=(2,#{loc},CalcLatLon)", selfdir+"aspectranking.result.json")

    loc = "pos.ll=N33.544000%3BW117.752900"
    run_query("#{qq}&#{loc}&ranking=default", selfdir+"dist2a.result.json")
    run_query("#{qq}&#{loc}&ranking=nearby",  selfdir+"dist2b.result.json")
    run_query("#{qq}&#{loc}&ranking=combine", selfdir+"dist2c.result.json")
  end

  def run_query(query, file, field = nil)
    if (SAVE_RESULT)
      save_result(query, file)
    else
      assert_result(query, file, field)
    end
  end

  def teardown
    stop
  end

end
