# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class LiteralBoost < IndexedSearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir+"literalboost.sd"))
    start
  end

  def compare(query, file)
    assert_field(query, selfdir+file, "uri", false)
  end

  def test_literalboost
    feed_and_wait_for_docs("literalboost", 3, { :file => selfdir+"input.3.xml", :maxpending => "1" })

    puts "run queries"
    compare("query=content:booking", "booking.result")
    compare("query=content:book",    "book.result")
    compare("query=content:books",   "books.result")
    compare("query=content:booked",  "booked.result")
    puts "now verify that bug 333048 is fixed"
    compare("query=content:books&filter=bogo", "333048.result")

    result = vespa.adminserver.execute('vespa-visit --xmloutput --maxpendingsuperbuckets 1 --maxpending 1')
    assert_xml(result, selfdir+"fullvisit.xml")
    result = vespa.adminserver.execute('vespa-visit --xmloutput --maxpendingsuperbuckets 1 --maxpending 1 --fieldset literalboost:[document]')
    assert_xml(result, selfdir+"documentvisit.xml")
  end

  def teardown
    stop
  end

end
