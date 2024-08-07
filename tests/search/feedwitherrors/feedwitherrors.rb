# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class FeedWithErrors < IndexedStreamingSearchTest

  def setup
    set_owner("valerijf")
    set_description("Feed docs with errors, check that docproc reports correctly")
    deploy_app(SearchApp.new.sd(selfdir + "errordoc.sd"))
    start
  end

  def test_feedwitherrors
    feedoutput = feed(:file => selfdir + "errorfeed.10.json", :exceptiononfailure => false, :stderr => true)
    wait_for_atleast_hitcount("query=sddocname:errordoc", 1)
    assert_correct_output([ "Illegal base64 character",
                            "Illegal hex value 'ziggystardusthex'",
                            "NumberFormatException"],
                          feedoutput)
    assert_log_matches(Regexp.compile(".*Illegal base64 character 40.*"))
    assert_log_matches(Regexp.compile(".*Illegal hex value 'ziggystardusthex'.*"))
    assert_log_matches(Regexp.compile(".*For input string: \"foobar\".*NumberFormatException.*"))
  end

  def teardown
    stop
  end

end
