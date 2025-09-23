# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class LiteralBoost < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir+"literalboost.sd"))
    start
  end

  def compare(query, file)
    assert_field(query, selfdir+file, "uri", false)
  end

  def test_literalboost
    feed_and_wait_for_docs("literalboost", 2, { :file => selfdir+"input.2.json", :maxpending => "1" })

    puts "run queries"
    compare("query=content:book",    "book.result")
    compare("query=content:booked",  "booked.result")
    compare("query=content:booked&filter=bogo", "booked-filter.result")

    result = vespa.adminserver.execute('vespa-visit --maxpendingsuperbuckets 1 --maxpending 1 --fieldset [all]')
    assert_equal(File.read(selfdir+"fullvisit.json"), result)
    result = vespa.adminserver.execute('vespa-visit --maxpendingsuperbuckets 1 --maxpending 1')
    assert_equal(File.read(selfdir+"documentvisit.json"), result)
  end


end
