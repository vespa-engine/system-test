# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Bug6581037Test < IndexedStreamingSearchTest

  def setup
    set_owner('balder')
    @feed_file = dirs.tmpdir + "feed.json"
  end

  def timeout_seconds
    1200
  end


  def test_uca_chinese
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    verify_uca_sorting("zh", 157)
    verify_uca_sorting("ar", 34)
  end

  def verify_uca_sorting(lang, count)
    system("cat " + selfdir + "input-" + lang + ".txt | " + selfdir + "generatefeed.sh " + lang + " > " + @feed_file)
    feed(:file => @feed_file)

    for i in 1...3  do
      search_with_timeout(20, gen_query(lang, count))
    end

    verify(lang, count, count)
    for i in 1...count do
        verify(lang, count, i)
    end
  end

  def gen_query(lang, hits)
    "sddocname:test lang:" + lang + "&sorting=uca(title," + lang + ",PRIMARY) %2Bid&hits=" + hits.to_s + "&format=json"
  end

  def verify(lang, total, hits)
    puts "Verifying sortorder for hits = " + hits.to_s
    fields = ["id", "title"]
    system("cat " + selfdir + "input-" + lang + ".txt | " + selfdir + "generateresult.sh "+ total.to_s + " " + hits.to_s + " > " + dirs.tmpdir + "result.xml")
    assert_result(gen_query(lang, hits), dirs.tmpdir + "result.xml", nil, fields)
  end

end
