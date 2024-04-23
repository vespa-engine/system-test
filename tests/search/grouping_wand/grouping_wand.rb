# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'document_set'
require 'indexed_streaming_search_test'

class GroupingWand < IndexedStreamingSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("bjorncs")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_grouping_wand
    docs = DocumentSet.new
    (1..10).each do |a|
      (1..10).each do |b|
        (1..10).each do |c|
          doc = Document.new("test", "id:ns:test::a#{a}b#{b}c#{c}")
          doc.add_field("a", a)
          doc.add_field("b", b)
          doc.add_field("c", c)
          doc.add_field("wset", {"a#{a}" => 1, "b#{b}" => 1, "c#{c}" => 1})
          doc.add_field("n", docs.documents.length)
          docs.add(doc)
        end
      end
    end
    feedfile = dirs.tmpdir + "input.json"
    docs.write_json(feedfile)

    num_docs = docs.documents.length
    feed_and_wait_for_docs("test", num_docs, :file => feedfile)

    query      = "/search/?wand.heapSize=#{num_docs}&wand.field=wset"
    wand_a     = "wand.tokens=%7Ba1:1%7D"
    wand_ab    = "wand.tokens=%7Ba1:1,b1:1%7D"
    wand_abc   = "wand.tokens=%7Ba1:1,b1:1,c1:1%7D"
    select_a   = "select=all%28group%28a%29each%28output%28count%28%29%29%29%29"
    select_ab  = "select=all%28group%28a%29each%28group%28b%29each%28output%28count%28%29%29%29%29%29"
    select_abc = "select=all%28group%28a%29each%28group%28b%29each%28group%28c%29each%28output%28count%28%29%29%29%29%29%29"

    check_query("#{query}&#{wand_a}&#{select_a}",
                "#{selfdir}/result_wa_sa.xml")
    check_query("#{query}&#{wand_ab}&#{select_a}",
                "#{selfdir}/result_wab_sa.xml")
    check_query("#{query}&#{wand_abc}&#{select_a}",
                "#{selfdir}/result_wabc_sa.xml")

    check_query("#{query}&#{wand_a}&#{select_ab}",
                "#{selfdir}/result_wa_sab.xml")
    check_query("#{query}&#{wand_ab}&#{select_ab}",
                "#{selfdir}/result_wab_sab.xml")
    check_query("#{query}&#{wand_abc}&#{select_ab}",
                "#{selfdir}/result_wabc_sab.xml")

    check_query("#{query}&#{wand_a}&#{select_abc}",
                "#{selfdir}/result_wa_sabc.xml")
    check_query("#{query}&#{wand_ab}&#{select_abc}",
                "#{selfdir}/result_wab_sabc.xml")
    check_query("#{query}&#{wand_abc}&#{select_abc}",
                "#{selfdir}/result_wabc_sabc.xml")
  end

  def check_query(query, file)
    puts "QUERY = " + query
    if (SAVE_RESULT)
      save_result(query, file);
    end
    assert_xml_result_with_timeout(4.0, query, file)
  end

  def teardown
    stop
  end

end
