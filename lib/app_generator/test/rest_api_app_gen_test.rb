# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test/unit'
require 'app_generator/container_app'
require 'app_generator/rest_api'

class RestApiAppGenTest < Test::Unit::TestCase
  include AppGenerator

  def test_jetty_is_set_true
    actual =
        Container.new.
            rest_api(RestApi.new("my-path")).
            to_xml("")

    expected_substr =
        '<container id="default" jetty="true"'

    assert_substring_ignore_whitespace(actual, expected_substr)

  end

  def test_basic_rest_api
    actual =
        Container.new.
            rest_api(RestApi.new("my-path").
                         jersey1(true).
                         bundle(Bundle.new("my-bundle"))).
            to_xml("")

    expected_substr =
      '<rest-api path="my-path">
        <components bundle="my-bundle" />
       </rest-api>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_jersey2
    actual =
        Container.new.
            rest_api(RestApi.new("my-path").
                         bundle(Bundle.new("my-bundle"))).
            to_xml("")

    expected_substr =
      '<rest-api jersey2="true" path="my-path">
        <components bundle="my-bundle" />
       </rest-api>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_two_rest_apis
    actual =
        Container.new.
            rest_api(RestApi.new("path1").
                         jersey1(true).
                         bundle(Bundle.new("bundle1"))).
            rest_api(RestApi.new("path2").
                         jersey1(true).
                         bundle(Bundle.new("bundle2"))).
            to_xml("")

    expected_substr =
      '<rest-api path="path1">
        <components bundle="bundle1" />
       </rest-api>
       <rest-api path="path2">
        <components bundle="bundle2" />
       </rest-api>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_specific_package_scanning
    actual =
        Container.new.
            rest_api(RestApi.new("my-path").
                         jersey1(true).
                         bundle(Bundle.new("my-bundle").
                                    package(Package.new("com.yahoo.foo")).
                                    package(Package.new("com.yahoo.bar")))).
            to_xml("")

    expected_substr =
      '<rest-api path="my-path">
        <components bundle="my-bundle">
          <package>com.yahoo.foo</package>
          <package>com.yahoo.bar</package>
        </components>
       </rest-api>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def assert_substring_ignore_whitespace(actual, expected_substr)
    assert(actual.split(/[\s]+/).join(' ').
               include?(expected_substr.split(/[\s]+/).join(' ')),
           actual)
  end

end
