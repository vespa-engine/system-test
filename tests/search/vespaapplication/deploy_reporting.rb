# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class DeployReporting < IndexedSearchTest

  def setup
    set_owner("gjoranv")
    set_description("Test that application package problems are reported")
  end

  def test_deploy_bad_sdfile
    begin
      err = deploy_app(SearchApp.new.sd(selfdir + "bad.sd"))
    rescue ExecuteError => e
      err = e.output
      msg = e.message
    end
    puts "deploying application with problems in .sd file, output:"
    puts msg
    puts err
    puts "(should contain FAILSTATUS=)"
    assert_match(/non-zero exit status/, msg, "deploy should return error")
    assert_match(/deploy/, msg, "deploy should return error")
    puts "(should contain 'is not a valid stemming setting')"
    assert_match(/'bad' is not a valid stemming setting/, err,
                 "error message did not contain required text")
  end

  def teardown
    stop
  end

end
