# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'json'

class ScanSpecifiedPackages < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that users can specify single packages to scan from a Jersey bundle.")

    add_bundle_dir(selfdir + 'components', 'multiple-packages')
    deploy(selfdir + "app")
    start
  end

  def test_scan_specified_packages
    result = vespa.container.values.first.search("/rest-api/scanned")
    assert_equal('I have been scanned, like I should!', result.xmldata, "Did not get expected response.")

    result = vespa.container.values.first.search("/rest-api/unscanned")
    puts "RESPONSE CODE: #{result.responsecode}"
    assert_equal("404", result.responsecode, "The package that should not have been scanned, was scanned anyway.")

    #response = Net::HTTP.get_response(URI.parse(uri))
    #assert_equal("404", response.code, response.body)
  end

  def teardown
    stop
  end

end
