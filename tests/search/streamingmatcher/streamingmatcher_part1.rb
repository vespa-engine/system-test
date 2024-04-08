# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search/streamingmatcher/streaming_matcher'

class StreamingMatcherPart1 < StreamingMatcher

  def test_streaming_mailchecksum
    set_owner("vekterli")
    set_description("Simple test for streaming matcher (config model and basic functionality)")
    deploy_app(singlenode_streaming_2storage(selfdir+"musicsearch.sd"))
    start
    feedfile(selfdir+"feed_checksum.json")

    result = search("query=sddocname:musicsearch&streaming.userid=1234&select=all(group(folder) each(output(count(), xor(md5(cat(docidnsspecific(),folder,sort(flags)), 64)) as(checksum))))&format=xml")
    exp_checksum = "<output label=\"checksum\">2451403077069017125<\/output>"
    assert(result.xmldata.match(exp_checksum) != nil, "Expected #{exp_checksum} in result")
  end

  def test_streaming_splitbucket
    set_owner("vekterli")
    set_description("Test for streaming search with split bucket")
    app = singlenode_streaming_2storage(selfdir+"musicsearch.sd")
    deploy_app(app)
    start
    num_docs=5000

    num_docs.times { |i|
      docid = "id:storage_test:musicsearch:n=1234:" + i.to_s
      # Make the docs a bit larger.
      doc = Document.new("musicsearch", docid).
        add_field("title", "Well, in Amsterdam, you can buy" +
                       "beer in a movie theatre.  And I " +
                       "don\'t mean in a paper cup either." +
                       "They give you a glass of beer, like " +
                       "in a bar.  In Paris, you can buy " +
                       "beer at MacDonald\'s.  Also, you "+
                       "know what they call a Quarter " +
                       "Pounder with Cheese in Paris?")
      vespa.document_api_v1.put(doc)
    }

    cnt = 0

    # Wait until both nodes have some bucket splits.
    while cnt < 30
      if content_node_bucket_count(0) >= 2 and content_node_bucket_count(1) >= 2
        break
      end

      cnt = cnt + 1
      sleep 1
    end
    assert(cnt < 30, "No bucket splits observed")
    puts "node 0 has #{content_node_bucket_count(0)} buckets, Node 1 has #{content_node_bucket_count(1)} buckets"

    wait_for_hitcount("query=Quarter+Pounder&streaming.userid=1234", num_docs)
  end

  def test_document_with_massive_token_does_not_trigger_segfault
    set_owner("vekterli")
    set_description("Regression test for streaming search with massive " +
                    "tokens that are multi-megabyte in size (VESPA-447)")
    deploy_app(singlenode_streaming_2storage(selfdir+"musicsearch.sd"))
    start

    big_token = 'abc' * 1024*1024;
    2.times { |i|
      docid = "id:storage_test:musicsearch:n=1234:#{i}"
      doc = Document.new("musicsearch", docid).
        add_field("title", big_token)
      vespa.document_api_v1.put(doc)
    }
    # Can only reproduce this regression using suffix searches.
    # Since a suffix search for a token that gets truncated won't return any
    # results (for obvious reasons), just do a non-asserted search.
    search_with_timeout(60, "query=%2Aabc&streaming.userid=1234")
    # Test will fail if valgrind complains.
  end


  def test_simple_ranking
    set_owner("balder")
    set_description("Simple test for streaming matcher using the new relevancy framework for rank calculation")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"musicsearch.sd"))
    start
    feedfile(selfdir+"feed2.json")
    wait_for_hitcount("query=b&streaming.userid=1", 2)

    assert_hitcount("query=title:a&streaming.userid=1", 1)
    assert_hitcount("query=title:b&streaming.userid=1", 2)
    assert_hitcount("query=title:c&streaming.userid=1", 1)
    assert_hitcount("query=title:x+title:b&streaming.userid=1", 2)

    ##### test ranking #####
    # test firstPosition
    assert_rank(1, 0, "title:a", "title-0-fp")
    assert_rank(2, 0, "title:b", "title-0-fp")
    assert_rank(1, 1, "title:b", "title-0-fp")
    assert_rank(2, 0, "title:x+title:b", "title-1-fp")
    assert_rank(1, 1, "title:x+title:b", "title-1-fp")
    # search in default index
    assert_rank(1, 0, "a", "title-0-fp")
    assert_rank(2, 0, "b", "title-0-fp")
    assert_rank(1, 1, "b", "title-0-fp")
    assert_rank(2, 0, "x+b", "title-1-fp")
    assert_rank(1, 1, "x+b", "title-1-fp")

    # test occurrences
    assert_rank(2, 0, "title:a", "title-0-occ")
    assert_rank(2, 0, "title:b", "title-0-occ")
    assert_rank(3, 1, "title:b", "title-0-occ")
    assert_rank(2, 0, "title:x+title:b", "title-1-occ")
    assert_rank(3, 1, "title:x+title:b", "title-1-occ")
    assert_rank(0, 0, "title:a", "lyrics-0-occ")
    assert_rank(0, 1, "title:c", "lyrics-0-occ")
    # search in default index
    assert_rank(2, 0, "a", "title-0-occ")
    assert_rank(2, 0, "b", "title-0-occ")
    assert_rank(3, 1, "b", "title-0-occ")
    assert_rank(2, 0, "x+b", "title-1-occ")
    assert_rank(3, 1, "x+b", "title-1-occ")
    assert_rank(0, 0, "x", "lyrics-0-occ")
    assert_rank(0, 1, "x", "lyrics-0-occ")

    # test firstPosition
    assert_rank(1000000, 0, "title:a", "lyrics-0-fp")
    assert_rank(1000000, 1, "title:c", "lyrics-0-fp")
    # search in default index
    assert_rank(1000000, 0, "x", "lyrics-0-fp")
    assert_rank(1000000, 1, "x", "lyrics-0-fp")


    ##### test summary features #####
    # search in default index
    assert_ftm(1, 2, 2, 3, 0, "a&ranking=sf", "summaryfeatures")
    assert_ftm(2, 2, 3, 3, 0, "b&ranking=sf", "summaryfeatures")
    assert_ftm(1, 3, 2, 4, 1, "b&ranking=sf", "summaryfeatures")
    assert_ftm(2, 3, 3, 4, 1, "c&ranking=sf", "summaryfeatures")

    # search in field 'title'
    assert_ftm(2, 2, 1000000, 0, 0, "title:b&ranking=sf", "summaryfeatures")
    assert_ftm(1, 3, 1000000, 0, 1, "title:b&ranking=sf", "summaryfeatures")


    ##### test rank features #####
    # search in default index
    assert_ftm(1, 2, 2, 3, 0, "a&rankfeatures", "rankfeatures")
    assert_ftm(2, 2, 3, 3, 0, "b&rankfeatures", "rankfeatures")
    assert_ftm(1, 3, 2, 4, 1, "b&rankfeatures", "rankfeatures")
    assert_ftm(2, 3, 3, 4, 1, "c&rankfeatures", "rankfeatures")

    # search in field 'title'
    assert_ftm(2, 2, 1000000, 0, 0, "title:b&rankfeatures", "rankfeatures")
    assert_ftm(1, 3, 1000000, 0, 1, "title:b&rankfeatures", "rankfeatures")

    ##### test attribute rank in first phase #####
    assert_rank(2008, 0, "year:%3E2000", "year")
    assert_rank(2009, 1, "year:%3E2000", "year")
  end

  def test_twophase_ranking
    set_owner("balder")
    set_description("Test for streaming matcher using twophase ranking")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"musicsearch.sd"))
    start
    feedfile(selfdir + "twophase.json")
    wait_for_hitcount("query=title:a&streaming.userid=1", 4)

    # test basic two-phase ranking (both expressions are executed before adding to the heap)
    assert_rank(40, 3, "title:a", "twophase")
    assert_rank(30, 2, "title:a", "twophase")
    assert_rank(20, 1,  "title:a", "twophase")
    assert_rank(10, 0,  "title:a", "twophase")
    # we should have summary features for all returned hits
    assert_first_phase(4, 3, "title:a", "twophase")
    assert_first_phase(3, 2, "title:a", "twophase")
    assert_first_phase(2, 1, "title:a", "twophase")
    assert_first_phase(1, 0, "title:a", "twophase")

    # we should only see the result from the 2. phase expression (no more scaling)
    assert_rank(40, 3, "title:a", "twophase-scaling")
    assert_rank(30, 2, "title:a", "twophase-scaling")
    assert_rank(20, 1, "title:a", "twophase-scaling")
    assert_rank(10, 0, "title:a", "twophase-scaling")
    # we should have summary features for all returned hits
    assert_first_phase(400, 3, "title:a", "twophase-scaling")
    assert_first_phase(300, 2, "title:a", "twophase-scaling")
    assert_first_phase(200, 1, "title:a", "twophase-scaling")
    assert_first_phase(100, 0, "title:a", "twophase-scaling")
  end

  def test_struct
    set_owner("balder")
    set_description("Simple test for streaming matcher using different struct types")
    add_bundle(selfdir + "StructDocProc.java")
    deploy_app(SearchApp.new.streaming.sd(selfdir + "structtest.sd").
	              container(Container.new.
				search(Searching.new).
				docproc(DocumentProcessing.new.
					chain(Chain.new.add(DocProc.new("com.yahoo.vespatest.StructDocProc"))))))
    start
    feedfile(selfdir+"feedstruct.json")
    wait_for_hitcount("query=ssf1:ssf1&streaming.userid=1", 1)

    puts "queries for ssf1"
    assert_hitcount("query=ssf1.s1:ssf1&streaming.userid=1", 1)
    assert_hitcount("query=ssf1.s1:foo&streaming.userid=1", 0)
    assert_hitcount("query=ssf1.i1:1&streaming.userid=1", 1)
    assert_hitcount("query=ssf1.i1:0&streaming.userid=1", 0)
    assert_hitcount("query=ssf1.l1:1122334455667788991&streaming.userid=1", 1)
    assert_hitcount("query=ssf1.l1:1122334455667788990&streaming.userid=1", 0)
    assert_hitcount("query=ssf1.d1:81.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf1.d1:80.79&streaming.userid=1", 0)
    assert_hitcount("query=ssf1.as1:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf1.as1:espen&streaming.userid=1", 0)
    assert_hitcount("query=ssf1.al1:11223344556677881&streaming.userid=1", 1)
    assert_hitcount("query=ssf1.al1:11223344556677882&streaming.userid=1", 0)
    assert_hitcount("query=ssf1:ssf1&streaming.userid=1", 1)
    assert_hitcount("query=ssf1:1&streaming.userid=1", 1)
    assert_hitcount("query=ssf1:1122334455667788991&streaming.userid=1", 1)
    assert_hitcount("query=ssf1:81.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf1:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf1:11223344556677881&streaming.userid=1", 1)

    puts "queries for ssf2"
    assert_hitcount("query=ssf2.s1:ssf2&streaming.userid=1", 1)
    assert_hitcount("query=ssf2.s1:foo&streaming.userid=1", 0)
    assert_hitcount("query=ssf2.i1:2&streaming.userid=1", 1)
    assert_hitcount("query=ssf2.i1:1&streaming.userid=1", 0)
    assert_hitcount("query=ssf2.l1:1122334455667788992&streaming.userid=1", 1)
    assert_hitcount("query=ssf2.l1:1122334455667788991&streaming.userid=1", 0)
    assert_hitcount("query=ssf2.d1:82.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf2.d1:81.79&streaming.userid=1", 0)
    assert_hitcount("query=ssf2.as1:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf2.as1:espen&streaming.userid=1", 0)
    assert_hitcount("query=ssf2.al1:11223344556677881&streaming.userid=1", 1)
    assert_hitcount("query=ssf2.al1:11223344556677882&streaming.userid=1", 0)
    assert_hitcount("query=ssf2:ssf2&streaming.userid=1", 1)
    assert_hitcount("query=ssf2:2&streaming.userid=1", 1)
    assert_hitcount("query=ssf2:1122334455667788992&streaming.userid=1", 1)
    assert_hitcount("query=ssf2:82.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf2:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf2:11223344556677881&streaming.userid=1", 1)

    puts "queries for ssf4"
    assert_hitcount("query=ssf4.s1:ssf4&streaming.userid=1", 1)
    assert_hitcount("query=ssf4.i1:4&streaming.userid=1", 0)
    assert_hitcount("query=ssf4.l1:1122334455667788994&streaming.userid=1", 1)
    assert_hitcount("query=ssf4.d1:84.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf4.as1:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf4.al1:11223344556677881&streaming.userid=1", 0)

    puts "queries for ssf5"
    # TODO: do not use default-index when support for nested index names are added to query parser
    assert_hitcount("query=ssf5&default-index=ssf5.nss1.s1&streaming.userid=1", 1)
    assert_hitcount("query=foo&default-index=ssf5.nss1.s1&streaming.userid=1", 0)
    assert_hitcount("query=5&default-index=ssf5.nss1.i1&streaming.userid=1", 1)
    assert_hitcount("query=1&default-index=ssf5.nss1.i1&streaming.userid=1", 0)
    assert_hitcount("query=1122334455667788995&default-index=ssf5.nss1.l1&streaming.userid=1", 1)
    assert_hitcount("query=1122334455667788991&default-index=ssf5.nss1.l1&streaming.userid=1", 0)
    assert_hitcount("query=85.79&default-index=ssf5.nss1.d1&streaming.userid=1", 1)
    assert_hitcount("query=81.79&default-index=ssf5.nss1.d1&streaming.userid=1", 0)
    assert_hitcount("query=paal&default-index=ssf5.nss1.as1&streaming.userid=1", 1)
    assert_hitcount("query=espen&default-index=ssf5.nss1.as1&streaming.userid=1", 0)
    assert_hitcount("query=11223344556677881&default-index=ssf5.nss1.al1&streaming.userid=1", 1)
    assert_hitcount("query=11223344556677882&default-index=ssf5.nss1.al1&streaming.userid=1", 0)
    assert_hitcount("query=ssf5.nss1:ssf5&streaming.userid=1", 1)
    assert_hitcount("query=ssf5.nss1:5&streaming.userid=1", 1)
    assert_hitcount("query=ssf5.nss1:1122334455667788995&streaming.userid=1", 1)
    assert_hitcount("query=ssf5.nss1:85.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf5.nss1:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf5.nss1:11223344556677881&streaming.userid=1", 1)
    assert_hitcount("query=ssf5.s2:s2&streaming.userid=1", 1)
    assert_hitcount("query=ssf5:ssf5&streaming.userid=1", 1)
    assert_hitcount("query=ssf5:s2&streaming.userid=1", 1)

    puts "queries for ssf6"
    # TODO: do not use default-index when support for nested index names are added to query parser
    assert_hitcount("query=ssf6&default-index=ssf6.nss1.s1&streaming.userid=1", 1)
    assert_hitcount("query=foo&default-index=ssf6.nss1.s1&streaming.userid=1", 0)
    assert_hitcount("query=6&default-index=ssf6.nss1.i1&streaming.userid=1", 1)
    assert_hitcount("query=1&default-index=ssf6.nss1.i1&streaming.userid=1", 0)
    assert_hitcount("query=1122334455667788996&default-index=ssf6.nss1.l1&streaming.userid=1", 1)
    assert_hitcount("query=1122334455667788991&default-index=ssf6.nss1.l1&streaming.userid=1", 0)
    assert_hitcount("query=86.79&default-index=ssf6.nss1.d1&streaming.userid=1", 1)
    assert_hitcount("query=81.79&default-index=ssf6.nss1.d1&streaming.userid=1", 0)
    assert_hitcount("query=paal&default-index=ssf6.nss1.as1&streaming.userid=1", 1)
    assert_hitcount("query=espen&default-index=ssf6.nss1.as1&streaming.userid=1", 0)
    assert_hitcount("query=11223344556677881&default-index=ssf6.nss1.al1&streaming.userid=1", 1)
    assert_hitcount("query=11223344556677882&default-index=ssf6.nss1.al1&streaming.userid=1", 0)
    assert_hitcount("query=ssf6.nss1:ssf6&streaming.userid=1", 1)
    assert_hitcount("query=ssf6.nss1:6&streaming.userid=1", 1)
    assert_hitcount("query=ssf6.nss1:1122334455667788996&streaming.userid=1", 1)
    assert_hitcount("query=ssf6.nss1:86.79&streaming.userid=1", 1)
    assert_hitcount("query=ssf6.nss1:paal&streaming.userid=1", 1)
    assert_hitcount("query=ssf6.nss1:11223344556677881&streaming.userid=1", 1)
    assert_hitcount("query=ssf6.s2:s2&streaming.userid=1", 1)
    assert_hitcount("query=ssf6:ssf6&streaming.userid=1", 1)
    assert_hitcount("query=ssf6:s2&streaming.userid=1", 1)

    puts "queries for ssf8"
    # TODO: do not use default-index when support for nested index names are added to query parser
    assert_hitcount("query=ssf8&default-index=ssf8.nss1.s1&streaming.userid=1", 1)
    assert_hitcount("query=8&default-index=ssf8.nss1.i1&streaming.userid=1", 0)
    assert_hitcount("query=1122334455667788998&default-index=ssf8.nss1.l1&streaming.userid=1", 1)
    assert_hitcount("query=88.79&default-index=ssf8.nss1.d1&streaming.userid=1", 1)
    assert_hitcount("query=paal&default-index=ssf8.nss1.as1&streaming.userid=1", 1)
    assert_hitcount("query=11223344556677881&default-index=ssf8.nss1.al1&streaming.userid=1", 0)

    puts "queries for asf1"
    assert_hitcount("query=asf1.s1:asf1&streaming.userid=1", 1)
    assert_hitcount("query=asf1.s1:foo&streaming.userid=1", 0)
    assert_hitcount("query=asf1.i1:14&streaming.userid=1", 1)
    assert_hitcount("query=asf1.i1:16&streaming.userid=1", 0)
    assert_hitcount("query=asf1.d1:75.79&streaming.userid=1", 1)
    assert_hitcount("query=asf1.d1:75.78&streaming.userid=1", 0)
    assert_hitcount("query=asf1.l1:1122334455667788994&streaming.userid=1", 1)
    assert_hitcount("query=asf1.l1:1122334455667788996&streaming.userid=1", 0)
    assert_hitcount("query=asf1.as1:paal&streaming.userid=1", 1)
    assert_hitcount("query=asf1.as1:espen&streaming.userid=1", 0)
    assert_hitcount("query=asf1.al1:11223344556677881&streaming.userid=1", 1)
    assert_hitcount("query=asf1.al1:11223344556677882&streaming.userid=1", 0)
    assert_hitcount("query=asf1:asf1&streaming.userid=1", 1)
    assert_hitcount("query=asf1:14&streaming.userid=1", 1)
    assert_hitcount("query=asf1:75.79&streaming.userid=1", 1)
    assert_hitcount("query=asf1:1122334455667788994&streaming.userid=1", 1)
    assert_hitcount("query=asf1:paal&streaming.userid=1", 1)
    assert_hitcount("query=asf1:11223344556677881&streaming.userid=1", 1)

    puts "queries for asf2"
    assert_hitcount("query=asf2.s1:asf2&streaming.userid=1", 1)
    assert_hitcount("query=asf2.s1:foo&streaming.userid=1", 0)
    assert_hitcount("query=asf2.i1:16&streaming.userid=1", 1)
    assert_hitcount("query=asf2.i1:18&streaming.userid=1", 0)
    assert_hitcount("query=asf2.d1:77.79&streaming.userid=1", 1)
    assert_hitcount("query=asf2.d1:77.78&streaming.userid=1", 0)
    assert_hitcount("query=asf2.l1:1122334455667788996&streaming.userid=1", 1)
    assert_hitcount("query=asf2.l1:1122334455667788998&streaming.userid=1", 0)
    assert_hitcount("query=asf2.as1:paal&streaming.userid=1", 1)
    assert_hitcount("query=asf2.as1:espen&streaming.userid=1", 0)
    assert_hitcount("query=asf2.al1:11223344556677881&streaming.userid=1", 1)
    assert_hitcount("query=asf2.al1:11223344556677882&streaming.userid=1", 0)
    assert_hitcount("query=asf2:asf2&streaming.userid=1", 1)
    assert_hitcount("query=asf2:16&streaming.userid=1", 1)
    assert_hitcount("query=asf2:77.79&streaming.userid=1", 1)
    assert_hitcount("query=asf2:1122334455667788996&streaming.userid=1", 1)
    assert_hitcount("query=asf2:paal&streaming.userid=1", 1)
    assert_hitcount("query=asf2:11223344556677881&streaming.userid=1", 1)

    puts "check document summary"
    actual = search("query=sddocname:structtest&streaming.userid=1&format=xml")
    expected = create_resultset(selfdir + "structtest.result")
    fields = ["ssf1","ssf4","ssf5","ssf8","asf1"]
    fields.each do |field|
      puts "check field #{field}"
      assert_equal(expected.hit[0].field[field], actual.hit[0].field[field])
    end
  end

  def test_field_types
    set_owner("balder")
    set_description("Simple test for streaming matcher using different field types")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"fieldtypetest.sd"))
    start
    feedfile(selfdir + "feedfieldtypetest.json")
    wait_for_hitcount("query=teststring:teststring1&streaming.userid=1", 1)

    assert_hitcount("query=teststring:teststring1&streaming.userid=1", 1)
    assert_hitcount("query=teststring:teststring2&streaming.userid=1", 1)

    assert_hitcount("query=testexactmatch:testexactmatch1&streaming.userid=1", 1)
    assert_hitcount("query=testexactmatch:testexactmatch2&streaming.userid=1", 1)

    assert_hitcount("query=testint:0&streaming.userid=1", 1)
    assert_hitcount("query=testint:2147483647&streaming.userid=1", 1)
    assert_hitcount("query=testint:%3C1&streaming.userid=1", 1)
    assert_hitcount("query=testint:%3E1&streaming.userid=1", 1)
    assert_hitcount("query=testint:%3E2147483646&streaming.userid=1", 1)
    assert_hitcount("query=testint:%3E2147483647&streaming.userid=1", 0)
    assert_hitcount("query=testint:%3C2147483647&streaming.userid=1", 1)
    assert_hitcount("query=testint:[1%3B2147483646]&streaming.userid=1", 0)
    assert_hitcount("query=testint:[0%3B2147483647]&streaming.userid=1", 2)

    assert_hitcount("query=testlong:0&streaming.userid=1", 1)
    assert_hitcount("query=testlong:2147483647&streaming.userid=1", 1)

    assert_hitcount("query=testbyte:0&streaming.userid=1", 1)
    assert_hitcount("query=testbyte:127&streaming.userid=1", 1)

    assert_hitcount("query=testfloat:0.0&streaming.userid=1", 1)
    assert_hitcount("query=testfloat:%3C1&streaming.userid=1", 1)
    assert_hitcount("query=testfloat:%3E1&streaming.userid=1", 1)
    assert_hitcount("query=testfloat:5.678&streaming.userid=1", 1)

    assert_hitcount("query=testdouble:0.0&streaming.userid=1", 1)
    assert_hitcount("query=testdouble:%3C1&streaming.userid=1", 1)
    assert_hitcount("query=testdouble:%3E1&streaming.userid=1", 1)
    assert_hitcount("query=testdouble:12345.6789&streaming.userid=1", 1)

    assert_hitcount("query=testuri:http://www.testuri1.no/&streaming.userid=1", 1)
    assert_hitcount("query=testuri:no&streaming.userid=1", 1)
    assert_hitcount("query=testuri:testuri1&streaming.userid=1", 1)
    assert_hitcount("query=testuri:www&streaming.userid=1", 1)
    assert_hitcount("query=testuri:http&streaming.userid=1", 2)

    assert_hitcount("query=testtermboost:term1&streaming.userid=1", 2)

    assert_hitcount("query=testcontent:testcontent1&streaming.userid=1", 1)
    assert_hitcount("query=testcontent:testcontent2&streaming.userid=1", 1)

    assert_hitcount("query=testarraybyte:1&streaming.userid=1", 1)
    assert_hitcount("query=testarraybyte:2&streaming.userid=1", 1)
    assert_hitcount("query=testarraybyte:3&streaming.userid=1", 1)
    assert_hitcount("query=testarraybyte:4&streaming.userid=1", 1)
    assert_hitcount("query=testarraybyte:5&streaming.userid=1", 1)
    assert_hitcount("query=testarraybyte:6&streaming.userid=1", 1)

    assert_hitcount("query=testarrayint:1&streaming.userid=1", 1)
    assert_hitcount("query=testarrayint:2&streaming.userid=1", 1)
    assert_hitcount("query=testarrayint:3&streaming.userid=1", 1)
    assert_hitcount("query=testarrayint:4&streaming.userid=1", 1)
    assert_hitcount("query=testarrayint:5&streaming.userid=1", 1)
    assert_hitcount("query=testarrayint:6&streaming.userid=1", 1)

    assert_hitcount("query=testarraylong:1&streaming.userid=1", 1)
    assert_hitcount("query=testarraylong:2&streaming.userid=1", 1)
    assert_hitcount("query=testarraylong:3&streaming.userid=1", 1)
    assert_hitcount("query=testarraylong:4&streaming.userid=1", 1)
    assert_hitcount("query=testarraylong:5&streaming.userid=1", 1)
    assert_hitcount("query=testarraylong:6&streaming.userid=1", 1)

    assert_hitcount("query=testarraydouble:1&streaming.userid=1", 1)
    assert_hitcount("query=testarraydouble:2&streaming.userid=1", 1)
    assert_hitcount("query=testarraydouble:3&streaming.userid=1", 1)
    assert_hitcount("query=testarraydouble:4&streaming.userid=1", 1)
    assert_hitcount("query=testarraydouble:5&streaming.userid=1", 1)
    assert_hitcount("query=testarraydouble:6&streaming.userid=1", 1)

    assert_hitcount("query=testarraystring:item0&streaming.userid=1", 0)
    assert_hitcount("query=testarraystring:item1&streaming.userid=1", 1)
    assert_hitcount("query=testarraystring:item2&streaming.userid=1", 2)
    assert_hitcount("query=testarraystring:item3&streaming.userid=1", 1)

    assert_hitcount("query=testarrayfloat:1&streaming.userid=1", 1)
    assert_hitcount("query=testarrayfloat:2&streaming.userid=1", 1)
    assert_hitcount("query=testarrayfloat:3&streaming.userid=1", 1)
    assert_hitcount("query=testarrayfloat:4&streaming.userid=1", 1)
    assert_hitcount("query=testarrayfloat:5&streaming.userid=1", 1)
    assert_hitcount("query=testarrayfloat:6&streaming.userid=1", 1)

    assert_hitcount("query=testwsetbyte:1&streaming.userid=1", 1)
    assert_hitcount("query=testwsetbyte:2&streaming.userid=1", 1)
    assert_hitcount("query=testwsetbyte:3&streaming.userid=1", 1)
    assert_hitcount("query=testwsetbyte:4&streaming.userid=1", 1)
    assert_hitcount("query=testwsetbyte:5&streaming.userid=1", 1)
    assert_hitcount("query=testwsetbyte:6&streaming.userid=1", 1)

    assert_hitcount("query=testwsetint:1&streaming.userid=1", 1)
    assert_hitcount("query=testwsetint:2&streaming.userid=1", 1)
    assert_hitcount("query=testwsetint:3&streaming.userid=1", 1)
    assert_hitcount("query=testwsetint:4&streaming.userid=1", 1)
    assert_hitcount("query=testwsetint:5&streaming.userid=1", 1)
    assert_hitcount("query=testwsetint:6&streaming.userid=1", 1)

    assert_hitcount("query=testwsetlong:1&streaming.userid=1", 1)
    assert_hitcount("query=testwsetlong:2&streaming.userid=1", 1)
    assert_hitcount("query=testwsetlong:3&streaming.userid=1", 1)
    assert_hitcount("query=testwsetlong:4&streaming.userid=1", 1)
    assert_hitcount("query=testwsetlong:5&streaming.userid=1", 1)
    assert_hitcount("query=testwsetlong:6&streaming.userid=1", 1)

    assert_hitcount("query=testwsetstring:item0&streaming.userid=1", 0)
    assert_hitcount("query=testwsetstring:item1&streaming.userid=1", 1)
    assert_hitcount("query=testwsetstring:item2&streaming.userid=1", 2)
    assert_hitcount("query=testwsetstring:item3&streaming.userid=1", 1)

    assert_hitcount("query=testweightedset:item0&streaming.userid=1", 0)
    assert_hitcount("query=testweightedset:item1&streaming.userid=1", 1)
    assert_hitcount("query=testweightedset:item2&streaming.userid=1", 2)
    assert_hitcount("query=testweightedset:item3&streaming.userid=1", 1)

    assert_hitcount("query=testtag:item0&streaming.userid=1", 0)
    assert_hitcount("query=testtag:item1&streaming.userid=1", 1)
    assert_hitcount("query=testtag:item2&streaming.userid=1", 2)
    assert_hitcount("query=testtag:item3&streaming.userid=1", 1)
    assert_hitcount("query=testbool:true&streaming.userid=1", 1)
    assert_hitcount("query=testbool:false&streaming.userid=1", 1)

    # save_result("query=teststring:teststring2&streaming.userid=1&format=xml", selfdir + "fieldtypetest_teststring2.result")
    assert_result("query=teststring:teststring2&streaming.userid=1&format=xml", selfdir + "fieldtypetest_teststring2.result")

    # TODO: Should maybe test more features from indexed search?

  end

  def test_many_fields
    set_owner("balder")
    set_description("Test for streaming matcher using many fields (>32)")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"manyfields.sd"))
    start
    feed(:file => selfdir + "manyfields.json")
    wait_for_hitcount("query=f1:a&streaming.userid=1", 1)
    npos = 1000000

    # query=f1:a
    assert_first_position(0,    "f1",  "f1:a")
    assert_first_position(npos, "f2",  "f1:a")
    assert_first_position(npos, "f32", "f1:a")
    assert_first_position(npos, "f33", "f1:a")

    # query=f33:a
    assert_first_position(npos, "f1",  "f33:a")
    assert_first_position(npos, "f2",  "f33:a")
    assert_first_position(npos, "f32", "f33:a")
    assert_first_position(7,    "f33", "f33:a")

    # query=a
    assert_first_position(0,    "f1",  "a")
    assert_first_position(1,    "f2",  "a")
    assert_first_position(2,    "f3",  "a")
    assert_first_position(3,    "f4",  "a")
    assert_first_position(npos, "f5",  "a")
    assert_first_position(npos, "f29", "a")
    assert_first_position(4,    "f30", "a")
    assert_first_position(5,    "f31", "a")
    assert_first_position(6,    "f32", "a")
    assert_first_position(7,    "f33", "a")
  end

  def test_attribute_rank_features
    set_owner("balder")
    set_description("Test for streaming matcher using attribute rank features")
    deploy_app(SearchApp.new.streaming().sd(selfdir+"attrrank.sd"))
    start
    feed(:file => selfdir + "attrrank.json")
    wait_for_hitcount("query=ss:first&streaming.userid=1", 1)

    assert_attribute_rank(100.0,      "si")
    assert_attribute_rank(55.5,       "sf")
    assert_attribute_rank(1.7409184128169565e-43, "ss")
  end

end
