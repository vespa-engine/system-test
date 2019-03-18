# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class TwoResourceBundles < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that jersey resources from a bundle not containing JerseyHandler can be included.")
  end

  def test_two_resource_bundles_in_one_rest_api
    add_bundle_dir("#{selfdir}/main_bundle", "main_bundle")
    add_bundle_dir("#{selfdir}/other_bundle", "other_bundle")

    deploy(selfdir + "app_one_rest_api")
    start

    container = vespa.container.values.first

    result = container.search("/rest-api/hello1")
    assert_match(Regexp.new("Hello from resource 1"), result.xmldata, "Could not find expected message in response.")

    result = container.search("/rest-api/hello2")
    assert_match(Regexp.new("Hello from resource 2"), result.xmldata, "Could not find expected message in response.")
  end

  def test_two_rest_apis
    add_bundle_dir("#{selfdir}/main_bundle", "main_bundle")
    add_bundle_dir("#{selfdir}/other_bundle", "other_bundle")

    deploy(selfdir + "app_two_rest_apis")
    start

    container = vespa.container.values.first

    result = container.search("/rest1/hello1")
    assert_match(Regexp.new("Hello from resource 1"), result.xmldata, "Could not find expected message in response.")

    result = container.search("/rest2/hello2")
    assert_match(Regexp.new("Hello from resource 2"), result.xmldata, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
