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
    @esmall_exp = [
      {
        "title" => "random random random random random random random random random random <hi>Electrics</hi> random random random random random random random random random random random random random random random random random random random random random random random random random FUBAR"
      }, {
        "title" => "<hi>Electrics</hi> Blues songs numbers eight and on"
      }
    ]
    @csmall_exp = [ { "title" => "<hi>Chicago</hi> Blues the number is increasing" } ]
    @clarge_exp = [ { "song" => "<hi>Chicago</hi> Blues" } ]
    @chicago_exp = [
      {
        "song" => "<hi>Chicago</hi> Blues",
        "title" => "<hi>Chicago</hi> Blues the number is increasing",
        "documentid" => "id:test:bolding::/shopping?id=1804905710",
      }
    ]
    @song_chicago_exp = [
      {
        "song" => "<hi>Chicago</hi> Blues",
        "title" => "Chicago Blues the number is increasing",
        "documentid" => "id:test:bolding::/shopping?id=1804905710",
      }
    ]
    @title_chicago_exp = [
      {
	"song" => "Chicago Blues",
        "title" => "<hi>Chicago</hi> Blues the number is increasing",
        "documentid" => "id:test:bolding::/shopping?id=1804905710",
      }
    ]
    @chicagonb_exp = [
      {
	"song" => "Chicago Blues",
        "title" => "Chicago Blues the number is increasing",
        "documentid" => "id:test:bolding::/shopping?id=1804905710",
      }
    ]
  end

  def setup
    set_owner("arnej")
  end

  def test_bolding
    def_expected()
    deploy_app(SearchApp.new.sd(selfdir+"stemming-none/bolding.sd"))
    start
    do_test()

    if not is_streaming
      redeploy(SearchApp.new.sd(selfdir+"stemming-shortest/bolding.sd").validation_override("indexing-change"))
      do_test_stemmed()

      redeploy(SearchApp.new.sd(selfdir+"stemming-multiple/bolding.sd").validation_override("indexing-change"))
      do_test_stemmed()
    end
  end

  def verify_bolding(query, expected)
    res = search(query)
    assert(res.hit.length() == expected.length())
    res.hit.length.times do |i|
      exp_hit = expected[i]
      exp_hit.each do |field, value|
	assert(res.hit[i].field[field].include? value)
      end
    end
  end

  def do_test()

    puts "Description: Bolding of words from query in displayed summary"
    puts "Component: Config, Indexing, Search etc"
    puts "Feature: Bolding"

    feed_and_wait_for_docs("bolding", 10, :file => selfdir + "input.xml")

    puts "Query: sanity check"
    assert_hitcount("query=sddocname:bolding", 10)

    puts "Query: bolding checks"
    verify_bolding("chicago",                               @chicago_exp)
    verify_bolding("title:chicago",                         @title_chicago_exp)
    verify_bolding("song:chicago",                          @song_chicago_exp)
    verify_bolding("chicago&bolding=false",                 @chicagonb_exp)
    verify_bolding("electrics",                             @bolding_exp)
    verify_bolding("sddocname:bolding&filter=%2Belectrics", @notrybolding_exp)
    verify_bolding("electrics&bolding",                     @bolding_exp)
    verify_bolding("electrics&bolding=true",                @bolding_exp)
    verify_bolding("electrics&bolding=false",               @nobolding_exp)

    puts "Query: bolding with summary-to checks"
    verify_bolding("chicago&summary=small",                 @csmall_exp)
    verify_bolding("chicago&summary=large",                 @clarge_exp)
    verify_bolding("electrics&summary=small",               @esmall_exp)
    verify_bolding("electrics&summary=large",               @elarge_exp)
  end

  def do_test_stemmed()
    do_test()
    verify_bolding("electric",                              @bolding_exp)
    verify_bolding("sddocname:bolding&filter=%2Belectric",  @notrybolding_exp)
    verify_bolding("electric&bolding",                      @bolding_exp)
    verify_bolding("electric&bolding=true",                 @bolding_exp)
    verify_bolding("electric&bolding=false",                @nobolding_exp)
    verify_bolding("electric&summary=small",                @esmall_exp)
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
