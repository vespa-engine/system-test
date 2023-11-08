# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class XmlFieldReader < IndexedSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test com.yahoo.vespaxmlparser.VespaXmlFieldReader " +
                    "in a deployed environment.")
  end

  def test_basicsearch
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start

    result = feedfile("#{selfdir}/bad_byte.xml",
                      :exceptiononfailure => false, :stderr => true)
    assert_match(Regexp.new(/Field 'my_byte': Invalid/), result)

    result = feedfile("#{selfdir}/bad_byte_update.xml",
                      :exceptiononfailure => false, :stderr => true)
    assert_match(Regexp.new(/Field 'my_byte': Invalid/), result)

    result = feedfile("#{selfdir}/bad_byte_arr.xml",
                      :exceptiononfailure => false, :stderr => true)
    assert_match(Regexp.new(/Field 'my_byte_arr': Invalid/), result)

    result = feedfile("#{selfdir}/bad_byte_arr_update.xml",
                      :exceptiononfailure => false, :stderr => true)
    assert_match(Regexp.new(/Field 'my_byte_arr': Invalid/), result)
  end

  def teardown
    stop
  end

end
