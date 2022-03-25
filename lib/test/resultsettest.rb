# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "test/unit"
require "test/mocks/resultset_generator"
require "resultset"
require "hit"

class ResultsetTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test

  def test_empty
    resultset = Resultset.new(nil, nil)
    assert_equal(nil, resultset.hitcount)
    assert_equal(0, resultset.hit.size)
  end

  def test_read_xml
    puts Dir.getwd
    str = IO.read(File.join(File.dirname(__FILE__), "music.10.result.xml"))
    resultset = Resultset.new(str, nil)
    assert_equal(10, resultset.hitcount)
    resultset.setcomparablefields(["title"])
    resultset.hit.each { |hit|
      assert_equal(["title"], hit.comparable_fields.keys)
    }

    assert_not_nil(resultset.xmldata)
  end

  def test_read_json
    puts Dir.getwd
    str = IO.read(File.join(File.dirname(__FILE__), "music.result.json"))

    resultset = Resultset.new(str, nil)
    assert_equal(5, resultset.hitcount)

    hits_as_str = resultset.to_s
    assert(hits_as_str =~ /Bad Religion/)
    assert(hits_as_str =~ /Michael Jackson/)
    assert(hits_as_str =~ /Bad English/)
    assert(hits_as_str =~ /Bad Company/)
    assert(hits_as_str =~ /Eminem/)

    resultset.setcomparablefields(["documentid","source","relevancy"])
    resultset.hit.each { |hit|
      assert(hit.comparable_fields.keys.include?('documentid'))
      assert(hit.comparable_fields.keys.include?('source'))
      assert(hit.comparable_fields.keys.include?('relevancy'))
    }

    assert_not_nil(resultset.xmldata) # Converts on-the-fly

    assert_equal(resultset.hit.size    , resultset.hitcount)
    assert_equal('id:tutorial:music::5', resultset.hit[0].field['documentid'])
    assert_equal('music'               , resultset.hit[0].field['source'])
    assert_equal(0.38186238359951247   , resultset.hit[0].field['relevancy'])
    assert_equal('id:tutorial:music::1', resultset.hit[1].field['documentid'])
    assert_equal('music'               , resultset.hit[1].field['source'])
    assert_equal(0.254574922399675     , resultset.hit[1].field['relevancy'])
    assert_equal('id:tutorial:music::4', resultset.hit[2].field['documentid'])
    assert_equal('music'               , resultset.hit[2].field['source'])
    assert_equal(0.254574922399675     , resultset.hit[2].field['relevancy'])
    assert_equal('id:tutorial:music::8', resultset.hit[3].field['documentid'])
    assert_equal('music'               , resultset.hit[3].field['source'])
    assert_equal(0.254574922399675     , resultset.hit[3].field['relevancy'])
    assert_equal('id:tutorial:music::2', resultset.hit[4].field['documentid'])
    assert_equal('music'               , resultset.hit[4].field['source'])
    assert_equal(0.05447959677335429   , resultset.hit[4].field['relevancy'])
  end

  def test_hits
    generator = ResultsetGenerator.new
    resultset = generator.get_resultset

    assert_equal(10, resultset.hit.size)
    assert_equal("0", resultset.hit[0].field["relevancy"])
    assert_equal("9", resultset.hit[9].field["relevancy"])

    resultset.sort_results_by("artist")
    assert_equal("9", resultset.hit[0].field["relevancy"])
    assert_equal("0", resultset.hit[9].field["relevancy"])

    resultset.sort_results_by("title")
    assert_equal("0", resultset.hit[0].field["relevancy"])
    assert_equal("9", resultset.hit[9].field["relevancy"])

    resultset.setcomparablefields(["title"])
    resultset.hit.each { |hit|
      assert_equal(["title"], hit.comparable_fields.keys)
    }
  end

  def test_that_it_is_possible_to_construct_with_json_data_and_get_json_object
    resultset = Resultset.new('{ "message" : "Hello world"}', nil)
    json = resultset.json
    assert_equal('Hello world', json['message'])
  end

  def test_that_xml_input_is_detected_as_xml_and_not_json
    result1 = Resultset.new(' <?xml version="1.0" encoding="UTF-8"?>\n
                              <note>\n
                              {curly} says hello</note>', nil)
    result2 = Resultset.new('<oops>I forgot to\n
                             [insert] the xml header</oops>', nil)

    assert(result1.is_xml?)
    assert(result2.is_xml?)

    assert(!result1.is_json?)
    assert(!result2.is_json?)
  end

  def test_that_json_input_is_detected_as_json_and_not_xml
    j0 = '{"message":"simple json", "value":1}'
    j1 = '  { "message" : "I am valid json with a newline",' + "\n" + '"value": 100 }'
    j2 = '{ "message" : "I have a < for you on a newline :\n<", "value": 100 }'

    result0 = Resultset.new(j0, nil)
    result1 = Resultset.new(j1, nil)
    result2 = Resultset.new(j2, nil)

    assert(result0.is_json?)
    assert(result1.is_json?)
    assert(result2.is_json?)

    assert(!result0.is_xml?)
    assert(!result1.is_xml?)
    assert(!result2.is_xml?)

  end

  def test_approx_cmp_epsilon
    h1 = { :a => 1.0, :b => 1.000001, :c => 'c' }
    h2 = { :a => 0.999999, :b => 1.0, :c => 'c' }
    h3 = { :a => 0.999998, :b => 1.0, :c => 'c' }
    h4 = { :a => 1.0, :b => 1.000003, :c => 'c' }
    h5 = { :a => 1.0, :b => 1.000001, :c => 'not c' }
    assert(Resultset.approx_cmp(h1, h2))
    assert(Resultset.approx_cmp(h2, h3))
    assert(!Resultset.approx_cmp(h1, h3, "test hash"))
    assert(!Resultset.approx_cmp(h1, h4, "test hash"))
    assert(!Resultset.approx_cmp(h1, h5, "test hash"))
    a1 = [ 1.0, 2.0, 3.0 ]
    a2 = [ 1.000001, 1.999999, 3.0 ]
    a3 = [ 1.0, 2.000002, 3.0 ]
    assert(Resultset.approx_cmp(a1, a2))
    assert(!Resultset.approx_cmp(a1, a3, "test array")) 
    complex1 = { "foo" => a1, "bar" => h1 }
    complex2 = { "foo" => a2, "bar" => h2 }
    assert(Resultset.approx_cmp(complex1, complex2))
    complex2 = { "foo" => a3, "bar" => h2 }
    assert(!Resultset.approx_cmp(complex1, complex2, "test complex"))
    complex2 = { "foo" => a2, "bar" => h3 }
    assert(!Resultset.approx_cmp(complex1, complex2, "test complex"))
    h1 = { :a => 'a', :b => nil, :c => false }
    h2 = { :c => false, :a => 'a', :b => nil }
    assert(Resultset.approx_cmp(h1, h2, "false/nil test"))
    h3 = { :a => 'a', :b => false, :c => false }
    assert(!Resultset.approx_cmp(h1, h3, "false/nil test"))
    h3 = { :a => 'a', :b => nil, :c => nil }
    assert(!Resultset.approx_cmp(h1, h3, "false/nil test"))
    h3 = { :a => 'a', :b => nil }
    assert(!Resultset.approx_cmp(h1, h3, "false/nil test"))
    h3 = { :a => 'a', :b => nil, :c => false, :d => nil }
    assert(!Resultset.approx_cmp(h1, h3, "false/nil test"))
  end
end
