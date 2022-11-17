# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class SanitizerGuardTest < IndexedSearchTest

  def setup
    set_owner('havardpe')
  end

  def test_sanitizer_none
    set_description('Make sure we are not compiled with any sanitizers')
    deploy_app(SearchApp.new.sd(selfdir + 'dummy.sd'))
    searchnode = vespa.search['search'].first
    command="#{Environment.instance.vespa_home}/bin/vespa-print-default sanitizers"
    (exitcode, output) = searchnode.execute(command, {:exitcode => true, :exceptiononfailure => false})
    assert_equal(0, exitcode.to_i)
    assert_equal("none", output.chomp)
  end

  def teardown
    stop
  end

end
