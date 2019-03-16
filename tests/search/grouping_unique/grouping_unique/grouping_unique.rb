# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'document_set'
require 'indexed_search_test'
require 'uri'

class GroupingUnique < IndexedSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("bjorncs")
    search_chain = SearchChain.new.add(Searcher.new("com.yahoo.search.grouping.UniqueGroupingSearcher",
                                                    nil, nil, nil, "container-search-and-docproc"))
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd").search_chain(search_chain))
    start
  end

  def test_grouping_unique
    docs = DocumentSet.new
    (1..5).each do |a|
      (1..10).each do |b|
        (1..15).each do |c|
          doc = Document.new("test", "id:ns:test::a#{a}b#{b}c#{c}")
          doc.add_field("a", a.to_s)
          doc.add_field("b", b.to_s)
          doc.add_field("c", c.to_s)
          doc.add_field("n", docs.documents.length.to_s)
          docs.add(doc)
        end
      end
    end
    feedfile = dirs.tmpdir + "input.xml"
    docs.write_xml(feedfile)

    feed_and_wait_for_docs("test", 750, :file => feedfile)
    assert_hitcount("query=sddocname:test&unique=a", 5)
    assert_hitcount("query=sddocname:test&unique=b", 10)
    assert_hitcount("query=sddocname:test&unique=c", 15)

    check_query("/?query=sddocname:test&hits=10&unique=a&sortspec=%2Bn", "#{selfdir}/result_ab.xml")
    check_query("/?query=sddocname:test&hits=10&unique=a&sortspec=%2Dn", "#{selfdir}/result_dc.xml")
  end

  def check_query(query, file)
    puts "Performing query: " + query
    if (SAVE_RESULT)
      save_result(query, file);
    end
    assert_xml_result_withtimeout(2.0, query, file)
  end

  def teardown
    stop
  end

end
