# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class AttributeSearch < IndexedSearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("geirst")

    # values for numeric attributes
    @ints = [100000, -200000, 300000, -400000, 500000, 1000, -2000]
    @longs = [10000000000, -20000000000, 30000000000, -40000000000, 50000000000, 10000, -20000]
    @bytes = [10, 20, 30, 40, 50, 24, 26]
    @floats = [10.5, -20.5, 30.5, -40.5, 50.5, 1.5, -2.5]
    @doubles = [100.5, -200.5, 300.5, -400.5, 500.5, 10.5, -20.5]
  end

  def extract_relevance(result)
    result.json.elements[1].elements["field[@name='relevancy']"].get_text.to_s
  end

  def check_result(query, field, field_values)
    do_check_result(query, {field => field_values}, field)
  end

  def do_check_result(query, expected, sortfield)
    result_file = dirs.tmpdir + "result.tmp"
    file = File.open(result_file, "w")
    file.write("<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n")
    file.write("<result total-hit-count=\"#{expected.values[0].length}\">\n")
    for i in 0...expected.values[0].length
      file.write("<hit>\n")
      expected.each_pair do |field, values|
        file.write("<field name=\"#{field}\">#{values[i]}</field>\n")
      end
      file.write("</hit>\n")
    end
    file.write("</result>")
    file.close();

    puts "query #{query}"
    poll_compare(query, result_file, sortfield, expected.keys)
  end

  # helper method
  def a_r_w_e(word, resnam, explain)
    assert_result("query=title:#{word}", selfdir + "case.#{resnam}.result.json", nil, nil, 0, explain)
    assert_result("query=fstitle:#{word}", selfdir + "case.#{resnam}.result.json", nil, nil, 0, explain)
  end

  # helper method
  def expect_fail(word, explain)
    # explain is not used, just present as documentation of test similiar to a_r_w_e method.
    assert_hitcount("query=title:#{word}", 0)
    assert_hitcount("query=fstitle:#{word}", 0)
  end

  def test_attributesearch_uncased
    deploy_app(SearchApp.new.sd(selfdir+"uncased/test.sd"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir+"docs_casing.xml")

    puts "test uncased (case insenitive search)"

    a_r_w_e("lower",    "lower",          "lowercase search failed")
    a_r_w_e("shouting", "upper",          "lowercase search failed")
    a_r_w_e("name",     "firstupper",     "lowercase search failed")
    a_r_w_e("plus",     "mixedcase",      "lowercase search failed")
    a_r_w_e("more",     "intermixedcase", "lowercase search failed")

    a_r_w_e("LoWeR",    "lower", "uppercase search for lowercase word failed")

    a_r_w_e("UPPER",          "upper",          "uppercase search failed")
    a_r_w_e("Firstupper",     "firstupper",     "first-uppercase search failed")
    a_r_w_e("MixedCase",      "mixedcase",      "mixedcase search failed")
    a_r_w_e("interMixedCase", "intermixedcase", "intermixedcase search failed")

    a_r_w_e("upper",    "upper",                   "lowercase search for uppercase search failed")
    a_r_w_e("firstupper",    "firstupper",         "lowercase search for uppercase search failed")
    a_r_w_e("mixedcase",    "mixedcase",           "lowercase search for uppercase search failed")
    a_r_w_e("intermixedcase",    "intermixedcase", "lowercase search for uppercase search failed")
  end

  def run_cased_search
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir+"docs_casing.xml")


    a_r_w_e("lower",    "lower",          "lowercase search failed")
    a_r_w_e("shouting", "upper",          "lowercase search failed")
    a_r_w_e("name",     "firstupper",     "lowercase search failed")
    a_r_w_e("plus",     "mixedcase",      "lowercase search failed")
    a_r_w_e("more",     "intermixedcase", "lowercase search failed")

    expect_fail("LoWeR", "uppercase search for lowercase word failed")

    a_r_w_e("UPPER",          "upper",          "uppercase search failed")
    a_r_w_e("Firstupper",     "firstupper",     "first-uppercase search failed")
    a_r_w_e("MixedCase",      "mixedcase",      "mixedcase search failed")
    a_r_w_e("interMixedCase", "intermixedcase", "intermixedcase search failed")

    expect_fail("upper",          "lowercase search for uppercase search failed")
    expect_fail("firstupper",     "lowercase search for uppercase search failed")
    expect_fail("mixedcase",      "lowercase search for uppercase search failed")
    expect_fail("intermixedcase", "lowercase search for uppercase search failed")
  end

  def test_attributesearch_cased_hash
    puts "Test cased search for hashed dictionaries"
    deploy_app(SearchApp.new.sd(selfdir+"cased_hash/test.sd"))
    run_cased_search
  end

  def test_attributesearch_cased_btree
    puts "Test cased search for btree dictionaries"
    deploy_app(SearchApp.new.sd(selfdir+"cased_btree/test.sd"))
    run_cased_search
  end

  def test_attributesearch_single_value
    deploy_app(SearchApp.new.sd(selfdir+"attrsingle.sd"))
    start
    feed_and_wait_for_docs("attrsingle", 5, :file => selfdir+"attrsingle.xml")

    numeric = Hash.new
    numeric["intfield"] = @ints
    numeric["longfield"] = @longs
    numeric["bytefield"] = @bytes
    numeric["floatfield"] = @floats
    numeric["doublefield"] = @doubles

    numeric["fsintfield"] = @ints
    numeric["fslongfield"] = @longs
    numeric["fsbytefield"] = @bytes
    numeric["fsfloatfield"] = @floats
    numeric["fsdoublefield"] = @doubles

    # exact match with unsigned numbers
    numeric.each do |field, values|
      check_result("/?query=#{field}:[#{values[0]}%3B#{values[0]}]", "body", ["doc0"])
      check_result("/?query=#{field}:#{values[0]}", "body", ["doc0"])
    end


    # exact match with signed numbers
    numeric.each do |field, values|
      check_result("/?query=#{field}:[#{values[1]}%3B#{values[1]}]", "body", ["doc1"])
      check_result("/?query=#{field}:#{values[1]}", "body", ["doc1"])
    end


    # numeric range queries
    numeric.each do |field, values|
      if not field.include?("byte")
        check_result("/?query=#{field}:<#{values[0]}", "body", ["doc1","doc3"])
        check_result("/?query=#{field}:[%3B#{values[0]}]", "body", ["doc0", "doc1","doc3"])
        check_result("/?query=#{field}:>#{values[0]}", "body", ["doc2","doc4"])
        check_result("/?query=#{field}:[#{values[0]}%3B]", "body", ["doc0", "doc2","doc4"])
        check_result("/?query=#{field}:<#{values[1]}", "body", ["doc3"])
        check_result("/?query=#{field}:[%3B#{values[1]}]", "body", ["doc1", "doc3"])
        check_result("/?query=#{field}:>#{values[1]}", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:[#{values[1]}%3B]", "body", ["doc0","doc1","doc2","doc4"])
        check_result("/?query=#{field}:[#{values[1]}%3B#{values[2]}]", "body", ["doc0","doc1","doc2"])
      else
        check_result("/?query=#{field}:<#{values[2]}", "body", ["doc0","doc1"])
        check_result("/?query=#{field}:[%3B#{values[2]}]", "body", ["doc0","doc1","doc2"])
        check_result("/?query=#{field}:>#{values[2]}", "body", ["doc3","doc4"])
        check_result("/?query=#{field}:[#{values[2]}%3B]", "body", ["doc2","doc3","doc4"])
        check_result("/?query=#{field}:[#{values[2]}%3B#{values[4]}]", "body", ["doc2","doc3","doc4"])
      end
    end

    check_result("/?query=intfield:[0%3B10000]", "body", [])
    check_result("/?query=fsintfield:[0%3B10000]", "body", [])

    check_result("/?query=longfield:[-20000%3B0]", "body", [])
    check_result("/?query=fslongfield:[-20000%3B0]", "body", [])

    check_result("/?query=bytefield:[60%3B100]", "body", [])
    check_result("/?query=fsbytefield:[60%3B100]", "body", [])

    check_result("/?query=floatfield:[0.5%3B5.5]", "body", [])
    check_result("/?query=fsfloatfield:[0.5%3B5.5]", "body", [])

    check_result("/?query=doublefield:[-20.5%3B0.5]", "body", [])
    check_result("/?query=fsdoublefield:[-20.5%3B0.5]", "body", [])

    strings = ["stringfield", "fsstringfield"]

    # string queries
    strings.each do |field|
      check_result("/?query=#{field}:attribute0", "body", ["doc0"])
      check_result("/?query=#{field}:attribute1", "body", ["doc1"])
      check_result("/?query=#{field}:attribute", "body", [])
      check_result("/?query=#{field}:attribute*", "body", ["doc0", "doc1", "doc2", "doc3", "doc4"])
      check_result("/?query=#{field}:attr", "body", [])
      check_result("/?query=#{field}:attr*", "body", ["doc0", "doc1", "doc2", "doc3", "doc4"])
    end

    check_result("/?query=floatinstring:10.5", "body", ["doc0"])
    check_result("/?query=floatinstring:-20.5", "body", ["doc1"])
    check_result("/?query=floatinstring:30.5", "body", ["doc2"])
    check_result("/?query=floatinstring:-40.5", "body", ["doc3"])
    check_result("/?query=floatinstring:50.5", "body", ["doc4"])


    # AND queries
    check_result("/?query=select%20%2A%20from%20sources%20%2A%20where%20%28range%28intfield%2C%20-200000%2C%20500000%29%20AND%20longfield%20%3E%200%20AND%20range%28bytefield%2C%2010%2C%2030%29%29%3B&type=yql",
                 "body", ["doc0","doc2"])
    check_result("/?query=select%20%2A%20from%20sources%20%2A%20where%20%28floatfield%20%3E%200.0%20AND%20doublefield%20%3C%20500.5%29%3B&type=yql", "body", ["doc0","doc2"])
    check_result("/?query=select%20%2A%20from%20sources%20%2A%20where%20%28stringfield%20contains%20%28%5B%7B%22prefix%22%3A%20true%7D%5D%22attribute%22%29%20AND%20intfield%20%3C%200%29%3B&type=yql", "body", ["doc1","doc3"])


    # OR queries
    check_result("/?query=select%20%2A%20from%20sources%20%2A%20where%20%28range%28intfield%2C%20100000%2C%20100000%29%20OR%20range%28longfield%2C%20-20000000000L%2C%20-20000000000L%29%20OR%20range%28bytefield%2C%2030%2C%2030%29%29%3B&type=yql",
                 "body", ["doc0","doc1","doc2"])
    check_result("/?query=select%20%2A%20from%20sources%20%2A%20where%20%28range%28floatfield%2C%20-40.5%2C%20-40.5%29%20OR%20range%28doublefield%2C%20500.5%2C%20500.5%29%29%3B&type=yql",
                 "body", ["doc3","doc4"])
    check_result("/?query=select%20%2A%20from%20sources%20%2A%20where%20%28stringfield%20contains%20%22attribute0%22%20OR%20stringfield%20contains%20%22attribute1%22%29%3B&type=yql", "body", ["doc0","doc1"])


    # AND queries with both attribute and index hits
    numeric.each do |field, values|
      if not field.include?("byte")
        check_result("/?query=#{field}:>#{values[3]}+title:vespa", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:[#{values[3]}%3B]+title:vespa", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:>#{values[0]}+title:vespa", "body", ["doc2","doc4"])
        check_result("/?query=#{field}:[#{values[0]}%3B]+title:vespa", "body", ["doc0","doc2","doc4"])
      else
        check_result("/?query=#{field}:>0+title:vespa", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:[0%3B]+title:vespa", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:>#{values[2]}+title:vespa", "body", ["doc4"])
        check_result("/?query=#{field}:[#{values[2]}%3B]+title:vespa", "body", ["doc2","doc4"])
      end
    end

    strings.each do |field|
      check_result("/?query=#{field}:attribute*+title:vespa", "body", ["doc0","doc2","doc4"])
      check_result("/?query=#{field}:attribute0+title:vespa", "body", ["doc0"])
    end


    # OR queries with both attribute and index hits
    numeric.each do |field, values|
      if not field.include?("byte")
        check_result("/?query=#{field}:>#{values[0]}+doc0&type=any", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:[#{values[0]}%3B]+doc0&type=any", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:<#{values[0]}+doc4&type=any", "body", ["doc1","doc3", "doc4"])
        check_result("/?query=#{field}:[%3B#{values[0]}]+doc4&type=any", "body", ["doc0","doc1","doc3","doc4"])
      end
    end

  end

  def test_attributesearch_array
    deploy_app(SearchApp.new.sd(selfdir+"attrarray/attrmulti.sd"))
    start
    feed_and_wait_for_docs("attrmulti", 5, :file => selfdir+"attrarray/attrmulti.xml")

    check_attributesearch_multivalue(true)
  end

  def test_attributesearch_weightedset
    deploy_app(SearchApp.new.sd(selfdir+"attrweighted/attrmulti.sd"))
    start
    feed_and_wait_for_docs("attrmulti", 5, :file => selfdir+"attrweighted/attrmulti.xml")

    check_attributesearch_multivalue(false)
  end

  def check_attributesearch_multivalue(has_float_fields)
    numeric = Hash.new
    numeric["mvintfield"] = @ints
    numeric["mvlongfield"] = @longs
    numeric["mvbytefield"] = @bytes
    if has_float_fields
      numeric["mvfloatfield"] = @floats
      numeric["mvdoublefield"] = @doubles
    end

    numeric["mvfsintfield"] = @ints
    numeric["mvfslongfield"] = @longs
    numeric["mvfsbytefield"] = @bytes
    if has_float_fields
      numeric["mvfsfloatfield"] = @floats
      numeric["mvfsdoublefield"] = @doubles
    end

    numeric.each do |field, values|
      if not field.include?("byte")
        check_result("/?query=#{field}:[#{values[6]}%3B#{values[5]}]", "body", ["doc0","doc1","doc2","doc3","doc4"])
        check_result("/?query=#{field}:[#{values[6]}%3B#{values[5]}]%20-mvfsbytefield:25", "body", ["doc0","doc1","doc2","doc3","doc4"])
        check_result("/?query=#{field}:[#{values[6]}%3B#{values[5]}]%20-mvfsbytefield:25&parallel=false", "body", ["doc0","doc1","doc2","doc3","doc4"])
        check_result("/?query=#{field}:<#{values[6]}", "body", ["doc1","doc3"])
        check_result("/?query=#{field}:[%3B#{values[6]}]", "body", ["doc1","doc3"])
        check_result("/?query=#{field}:>#{values[5]}", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:[#{values[5]}%3B]", "body", ["doc0","doc2","doc4"])
        check_result("/?query=#{field}:>#{values[4]}", "body", [])
        check_result("/?query=#{field}:[#{0.01+values[4]}%3B]", "body", [])
        check_result("/?query=#{field}:[#{values[4]}%3B]", "body", ["doc4"])
      else
        check_result("/?query=#{field}:[24%3B26]", "body", ["doc0","doc1","doc2","doc3","doc4"])
        check_result("/?query=#{field}:<24", "body", ["doc0","doc1"])
        check_result("/?query=#{field}:[%3B24]", "body", ["doc0","doc1"])
        check_result("/?query=#{field}:>26", "body", ["doc2","doc3","doc4"])
        check_result("/?query=#{field}:[26%3B]", "body", ["doc2","doc3","doc4"])
        check_result("/?query=#{field}:>50", "body", [])
        check_result("/?query=#{field}:[50%3B]", "body", ["doc4"])
        check_result("/?query=#{field}:[51%3B]", "body", [])
      end
    end

    stringfields = ["mvstringfield", "mvfsstringfield"]

    stringfields.each do |field|
      check_result("/?query=#{field}:vespa", "body", ["doc0","doc2","doc4"])
      check_result("/?query=#{field}:search", "body", ["doc1","doc3"])
      check_result("/?query=#{field}:attribute", "body", [])
      check_result("/?query=#{field}:attribute*", "body", ["doc0", "doc1", "doc2", "doc3", "doc4"])
      check_result("/?query=#{field}:attribute0", "body", ["doc0"])
      check_result("/?query=#{field}:attribute1", "body", ["doc1"])
      check_result("/?query=#{field}:attribute2", "body", ["doc2"])
      check_result("/?query=#{field}:attribute3", "body", ["doc3"])
      check_result("/?query=#{field}:attribute4", "body", ["doc4"])
    end

  end

  def verify_prefix_common(field)
    fields=["title", "documentid"]
    assert_result("query=#{field}:tTtTtTtT*&hits=100", selfdir + "prefix1.result.json", nil, fields, 0, "prefix search failed")
    assert_result("query=#{field}:UuU*&hits=100", selfdir + "prefix2.result.json", nil, fields, 0, "prefix search failed")
    assert_hitcount("query=#{field}:U*", 4)
    assert_hitcount("query=#{field}:Uu*", 3)
    assert_hitcount("query=#{field}:UuU*", 2)
    assert_hitcount("query=#{field}:UuUu*", 1)
  end

  def verify_prefix_uncased(field)
    puts "test attribute prefix uncased #{field}"
    verify_prefix_common(field)
    fields=["title", "documentid"]
    assert_result("query=#{field}:tttttttt*&hits=100", selfdir + "prefix1.result.json", nil, fields, 0, "prefix search failed")
    assert_result("query=#{field}:TTTTTTTT*&hits=100", selfdir + "prefix1.result.json", nil, fields, 0, "prefix search failed")
    assert_result("query=#{field}:uuu*&hits=100", selfdir + "prefix2.result.json", nil, fields, 0, "prefix search failed")
    assert_result("query=#{field}:UUU*&hits=100", selfdir + "prefix2.result.json", nil, fields, 0, "prefix search failed")
  end

  def verify_prefix_cased(field)
    puts "test attribute prefix cased #{field}"
    verify_prefix_common(field)
    assert_hitcount("query=#{field}:tttttttt*", 0)
    assert_hitcount("query=#{field}:TTTTTTTT*", 0)
    assert_hitcount("query=#{field}:u*", 0)
    assert_hitcount("query=#{field}:uu*", 0)
    assert_hitcount("query=#{field}:uuu*", 0)
    assert_hitcount("query=#{field}:uuuu*", 0)
    assert_hitcount("query=#{field}:U*", 4)
    assert_hitcount("query=#{field}:UU*", 0)
    assert_hitcount("query=#{field}:UUU*", 0)
    assert_hitcount("query=#{field}:UUUU*", 0)
  end

  def test_attribute_prefix
    deploy_app(SearchApp.new.sd(selfdir+"prefix.sd"))
    start
    feed_and_wait_for_docs("prefix", 20, :file => selfdir+"prefix.xml")

    verify_prefix_uncased("scan_uncased")
    verify_prefix_uncased("btree_uncased")
    verify_prefix_cased("scan_cased")
    verify_prefix_cased("btree_cased")
    verify_prefix_cased("hash_cased")
  end

  def test_flag_attribute
    set_description("Test the byte range of the flag attribute (array<byte>, fast-search)")
    deploy_app(SearchApp.new.sd(selfdir+"attrflag/test.sd"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir+"attrflag/feed.xml")
    assert_hitcount("query=flag:-128", 1)
    assert_hitcount("query=flag:127", 1)
    assert_hitcount("query=flag:>-128", 4)
    assert_hitcount("query=flag:<127", 4)
    assert_hitcount("query=flag:[-128%3B-8]", 2)
    assert_hitcount("query=flag:[-8%3B8]", 2)
    assert_hitcount("query=flag:[8%3B127]", 3)
    assert_hitcount("query=flag:[-129%3B-8]", 2)
    assert_hitcount("query=flag:[8%3B128]", 3)
    assert_result("query=sddocname:test", selfdir+"attrflag/result.json", "documentid")
  end

  def teardown
    stop
  end

end
