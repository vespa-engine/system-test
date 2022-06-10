# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# -*- coding: utf-8 -*-
require 'indexed_search_test'

class TagsAccents < IndexedSearchTest

  @@fctr = Process.pid * 100

  @@vals = [ "x", \
             "À", "Æ", "AE", "Ç", "C", "È", "E", "É", "E",  \
             "Ê", "E", "Ë", "E", "Ì", "I", "Í", "I", "Î",   \
             "I", "Ï", "I", "Ð", "D", "Ñ", "N", "Ò", "O",   \
             "Ó", "O", "Ô", "O", "Õ", "O", "Ö", "OE", "Ø",  \
             "OE", "Ù", "U", "Ú", "U", "Û", "U", "Ü", "UE", \
             "Ý", "Y", "Þ", "TH", "ß", "ss", "à", "a", "á", \
             "a", "â", "a", "ã", "a", "ä", "ae", "å", "aa", \
             "æ", "ae", "ç", "c", "è", "e", "é", "e", "ê",  \
             "e", "ë", "e", "ì", "i", "í", "i", "î", "i",   \
             "ï", "i", "ð", "d", "ñ", "n", "ò", "o", "ó",   \
             "o", "ô", "o", "õ", "o", "ö", "oe", "ø", "oe", \
             "ù", "u", "ú", "u", "û", "u", "ü", "ue", "ý",  \
             "y", "þ", "th", "ÿ", "y" \
           ]


  @@vals = [ "x", \
             "À", "Æ", "AE", "Ç", "C", "È", "E", "É", "E",  \
             "ù", "u", "ú", "u", "û", "u", "ü", "ue", "ý",  \
             "y", "þ", "th", "ÿ", "y" \
           ]

  def dwrite(tmp, val)
    @docid += 1
    tmp << "<document type=\"tagsaccents\" documentid=\"id:test:tagsaccents::#{@docid}\">\n"
    tmp << "  <title>doc #{@docid}</title>\n"
    [ "sfield1", "sfield2", "sfield3", "sfield4", "sfield5" ].each do |fn|
      tmp << "  <#{fn}>#{val}</#{fn}>\n"
    end
    [ "wfield1", "wfield2", "wfield3", "wfield4", "wfield5" ].each do |fn|
      tmp << "  <#{fn}>\n"
      tmp << "    <item weight=\"17\">#{val}</item>\n"
      tmp << "    <item weight=\"33\">#{val}#{val}#{val}</item>\n"
      tmp << "  </#{fn}>\n"
    end
    tmp << "  <wpref>#{val} #{val}</wpref>\n"
    tmp << "</document>\n"
  end

  def generate_feed(type)
    @@fctr += 1
    @docid = 0
    tmp_file = dirs.tmpdir+"#{type}.#{@@fctr}.xml"
    File.open(tmp_file, "w") do |tmp|
      @@vals.each { |val| dwrite(tmp, val) }
    end
    return tmp_file
  end

  def timeout_seconds
    return 1800
  end

  def setup
    set_owner("arnej")
    set_description("tag searching must work with accented chars")
    deploy_app(SearchApp.new.sd(selfdir+"tagsaccents.sd"))
    start
  end

  def test_tagsaccents
    file = generate_feed("foo")
    feed_and_wait_for_docs("tagsaccents", @docid, :file => file)
    File.delete(file)

    docidnum = 0
    @@vals.each do |x|
      docidnum += 1
      urlcoded = ""
      x.each_byte { |byte| urlcoded += ( "%%%02x" % byte ) }
      puts "query for #{x} => #{urlcoded}"
      assert_hitcount("#{docidnum}", 1)
      [ "sfield1", "sfield2", "sfield3", "sfield4", "sfield5" ].each do |field|
        doc = search("query=#{field}:#{urlcoded}&tracelevel=1&type=all")
        hitcount = doc.hitcount
        if (hitcount == 0)
          puts "tried query=#{field}:#{urlcoded}&tracelevel=1"
          puts "missing in #{field}: '#{x}'"
          puts "got: #{doc.xmldata}"
        end
        assert(hitcount > 0)
        assert_hitcount("query=#{field}:#{urlcoded}+#{docidnum}&tracelevel=1&type=all", 1)
      end
      [ "wfield1", "wfield2", "wfield3", "wfield4", "wfield5" ].each do |field|
        hitcount = search("query=#{field}:#{urlcoded}&tracelevel=1&type=all").hitcount
        if (hitcount == 0)
          puts "missing in #{field}: '#{x}'"
        end
        assert(hitcount > 0)
        assert_hitcount("query=#{field}:#{urlcoded}+#{docidnum}&tracelevel=1&type=all", 1)
        assert_hitcount("query=#{field}:#{urlcoded}#{urlcoded}#{urlcoded}+#{docidnum}&tracelevel=1&type=all", 1)
      end
      [ "wpref" ].each do |field|
        hitcount = search("query=#{field}:#{urlcoded} #{urlcoded}&tracelevel=1&type=all").hitcount
        if (hitcount == 0)
          puts "missing in #{field}: '#{x}'"
        end
        assert(hitcount > 0)
        assert_hitcount("query=#{field}:#{urlcoded} #{urlcoded}@+#{docidnum}&tracelevel=1&type=all", 1)
        assert_hitcount("query=#{field}:#{urlcoded} @*+#{docidnum}&tracelevel=1&type=all", 1)
        assert_hitcount("query=#{field}:#{urlcoded}@*+#{docidnum}&tracelevel=1&type=all", 1)
      end
    end
  end

  def teardown
    stop
  end

end
