# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document_set'
require 'indexed_streaming_search_test'

class WeakAndOperator < IndexedStreamingSearchTest

  def setup
  end

  def gen_docs(tfn)
    puts "generating feed in #{tfn}"
    docs = DocumentSet.new
    (11111..33333).each do |num|
      doc = Document.new("foo", "id:foo:foo::bar." + num.to_s).
              add_field("title", num.to_s)
      d = ""
      (2..9).each do |x|
        if (num % x == 0)
          d += " #{x}"
        end
      end
      (1111..1113).each do |x|
        if (num % x == 0)
          d += " #{x}"
        end
      end
      doc.add_field("desc", d).
        add_field("tstamp", 1000000+num)
      docs.add(doc)
    end
    docs.write_json(tfn)
  end

  def check_rank(query, savedresultfile, explanationstring="")
    qrserver_id = 0
    fieldstocompare = [ "relevancy" ]
    if explanationstring != ""
      explanationstring=explanationstring + ": "
    end
    result = search(query, qrserver_id)
    result.setcomparablefields(fieldstocompare)
    saved_result = create_resultset(savedresultfile)
    saved_result.setcomparablefields(fieldstocompare)

    # check that the hits are equal to the saved hits
    saved_result.hit.each_index do |i|
      assert_equal(saved_result.hit[i], result.hit[i], explanationstring + "At hit " + i.to_s + ". Answer file: #{savedresultfile}")
    end
  end

  def check_qlist(q)
    wq = "select+*+from+sources+*+where+weakAnd(default+%3D+" + q.join("+,+default+%3D+") + ")%3B&type=yql"
    oq = "select+*+from+sources+*+where+default+%3D+" + q.join("+OR+default+%3D+")   + "%3B&type=yql"
    puts "running query: #{wq}"
    save_result(wq, dirs.tmpdir+"wand-result.xml")
    puts "running query: #{oq}"
    save_result(oq, dirs.tmpdir+"or-result.xml")
    check_rank(wq, dirs.tmpdir+"or-result.xml")
    ohc = search(oq).hitcount
    whc = search(wq).hitcount
    if (whc != ohc)
        puts "WeakAnd hit count: #{whc}"
        puts "   OR   hit count: #{ohc}"
        assert(whc > 99)
        assert(whc < ohc)
    end
    puts "compares OK: #{oq} vs #{wq}"
  end

  def test_wand_operator
    set_owner("arnej")
    set_description("test WeakAnd operator searching")
    deploy_app(SearchApp.new.sd(selfdir + "foo.sd"))
    start
    tfn = dirs.tmpdir + "temp-wandfeed.json"
    gen_docs(tfn)
    feed(:file => tfn)
    wait_for_hitcount("2", 11111)
    assert_hitcount("8", 2778)
    assert_hitcount("9", 2469)
    assert_hitcount("select+*+from+sources+*+where+default+%3D+8+OR+default+%3D+9%3B&type=yql", 4939)
    assert_hitcount("tstamp:1022222", 1)

    assert_hitcount("select+*+from+sources+*+where+default+%3D+1111+or+default+%3D+1112%3B&type=yql", 40)
    assert_hitcount("select+*+from+sources+*+where+weakAnd(default+%3D+1111,+default+%3D+1112)%3B&type=yql", 40)

    q = [ 1111, 1112, 1113 ]
    check_qlist(q)

    q = [ 8, 9 ]
    check_qlist(q)

    q = [ 2, 3, 4, 5, 6, 7, 8, 9 ]
    check_qlist(q)
  end

  def teardown
    stop
  end

end
