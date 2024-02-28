# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Bolding < IndexedStreamingSearchTest

  def def_expected()

    @bolding_exp = [
      {
        "documentid" => "id:test:bolding::/shopping?id=1807865264",
        "song" => "random random random random random random random random random random <hi>Electrics</hi> random random random random random random random random random random random random random random",
        "title" => "random random random random random random random random random random <hi>Electrics</hi> random random random random random random random random random random random random random random random random random random random random random random random random random FUBAR"
      }, {
        "documentid" => "id:test:bolding::/shopping?id=1807865261",
        "song" => "<hi>Electrics</hi> Blues",
        "title" => "<hi>Electrics</hi> Blues songs numbers eight and on"
      }
    ]
    @notrybolding_exp = [
      {
        "documentid" => "id:test:bolding::/shopping?id=1807865264",
        "song" => "random random random random random random random random random random Electrics random random random random random random random random random random random random random random",
        "title" => "random random random random random random random random random random Electrics random random random random random random random random random random random random random random random random random random random random random random random random random"
      }, {
        "documentid" => "id:test:bolding::/shopping?id=1807865261",
        "song" => "Electrics Blues",
        "title" => "Electrics Blues songs numbers eight and on"
      }
    ]
    @nobolding_exp = [
      {
        "documentid" => "id:test:bolding::/shopping?id=1807865264",
        "song" => "random random random random random random random random random random Electrics random random random random random random random random random random random random random random",
        "title" => "random random random random random random random random random random Electrics random random random random random random random random random random random random random random random random random random random random random random random random random FUBAR"
      }, {
        "documentid" => "id:test:bolding::/shopping?id=1807865261",
        "song" => "Electrics Blues",
        "title" => "Electrics Blues songs numbers eight and on"
      }
    ]
    @elarge_exp = [
      {
        "song" => "random random random random random random random random random random <hi>Electrics</hi> random random random random random random random random random random random random random random"
      }, {
        "song" => "<hi>Electrics</hi> Blues",
      }
    ]
  end

  def check_result(q, fn)
    fnam = selfdir+@subdir+"/"+fn+".result.json"
    puts "checking #{fnam}"
    # save_result("query=#{q}", fnam)
    assert_result("query=#{q}", fnam)
  end

  def setup
    set_owner("arnej")
  end

  def test_bolding
    def_expected()
    testname = "stemming-none"
    deploy_app(SearchApp.new.sd(selfdir+testname+"/bolding.sd"))
    start
    do_test(testname)

    if not is_streaming
      testname = "stemming-shortest"
      redeploy(SearchApp.new.sd(selfdir+testname+"/bolding.sd").validation_override("indexing-change"))
      do_test_stemmed(testname)

      testname = "stemming-multiple"
      redeploy(SearchApp.new.sd(selfdir+testname+"/bolding.sd").validation_override("indexing-change"))
      do_test_stemmed(testname)
    end
  end

  def verify_bolding(query, expected)
    res = search(query)
    puts "res = " + res.to_s
    assert(res.hit.length() == expected.length())
    res.hit.length.times do |i|
      exp_hit = expected[i]
      exp_hit.each do |field, value|
        puts "#{i}: #{field}: " + res.hit[i].field[field] + " == " + value
	assert(res.hit[i].field[field].include? value)
      end
    end
  end

  def do_test(testname)
    @subdir = testname

    puts "Description: Bolding of words from query in displayed summary"
    puts "Component: Config, Indexing, Search etc"
    puts "Feature: Bolding"

    feed_and_wait_for_docs("bolding", 10, :file => selfdir + "input.xml")

    puts "Query: sanity check"
    assert_hitcount("query=sddocname:bolding", 10)

    puts "Query: bolding checks"
    check_result("chicago",                                 "chicago")
    check_result("title:chicago",                           "title-chicago")
    check_result("song:chicago",                            "song-chicago")
    check_result("chicago&bolding=false",                   "chicagonb")
    verify_bolding("electrics",                             @bolding_exp)
    verify_bolding("sddocname:bolding&filter=%2Belectrics", @notrybolding_exp)
    verify_bolding("electrics&bolding",                     @bolding_exp)
    verify_bolding("electrics&bolding=true",                @bolding_exp)
    verify_bolding("electrics&bolding=false",               @nobolding_exp)

    puts "Query: bolding with summary-to checks"
    check_result("chicago&summary=small",                  "csmall")
    check_result("chicago&summary=large",                  "clarge")
    check_result("electrics&summary=small",                "esmall")
    verify_bolding("electrics&summary=large",              @elarge_exp)
  end

  def do_test_stemmed(testname)
    do_test(testname)
    verify_bolding("electric",                              @bolding_exp)
    verify_bolding("sddocname:bolding&filter=%2Belectric",  @notrybolding_exp)
    verify_bolding("electric&bolding",                      @bolding_exp)
    verify_bolding("electric&bolding=true",                 @bolding_exp)
    verify_bolding("electric&bolding=false",                @nobolding_exp)
    check_result("electric&summary=small",                  "esmall")
    verify_bolding("electrics&summary=large",               @elarge_exp)
  end

  def test_bolding_in_addition_to_advanced_search_operators
    set_owner("geirst")
    set_description("Test the combination of bolding in addition to advanced search operators in the query")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed(:file => selfdir + "doc.json")
    exp_title_field = "Best of <hi>Metallica</hi>"

    result = search("?query=select+*+from+sources+*+where+title+contains+'Metallica'%3B&type=yql")
    assert_equal(exp_title_field, result.hit[0].field['title'])
    result = search("?query=select+*+from+sources+*+where+title+contains+'Metallica' and weightedSet(year,{'2001':1})%3B&type=yql")
    assert_equal(exp_title_field, result.hit[0].field['title'])
    result = search("?query=select+*+from+sources+*+where+title+contains+'Metallica'and+artist+matches+'metallica'%3B&type=yql")
    assert_equal(exp_title_field, result.hit[0].field['title'])
  end

  def teardown
    stop
  end

end
