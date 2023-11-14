# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class Bug6581037Test < SearchTest

  def setup
    set_owner('balder')
  end

  def timeout_seconds
    1200
  end

  def teardown
    stop
  end

  def test_uca_chinese
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    verify_uca_sorting("zh", 157)
    verify_uca_sorting("ar", 34)
    
  end

  def verify_uca_sorting(lang, count)

    system("cat " + selfdir + "input-" + lang + ".txt | " + selfdir + "generatefeed.sh " + lang + " > " + dirs.tmpdir + "feed.xml")
    feed(:file => dirs.tmpdir + "feed.xml")

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
