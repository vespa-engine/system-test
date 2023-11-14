# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class TestAndSetTest < SearchTest
  def setup
    set_owner("nobody")
    set_description("Test test and set functionality in Vespa")
    deploy_app(SearchApp.new.
                sd(selfdir + "weather.sd").
                enable_document_api)
    start
  end

  def test_with_json_feed_format
    run_tests(->(feedfile) {
      feed(:file => feed_filename(feedfile, :json))
    })
  end

  def test_with_vespa_http_client
    run_tests(->(feedfile) {
      feed(:file => feed_filename(feedfile, :json), :client => :vespa_feed_client, :port => 19020)
    })
  end

  def run_tests(feeder)
    conditional_put_not_executed_on_condition_mismatch(feeder)
    conditional_put_executed_on_condition_match(feeder)
    conditional_remove_not_executed_on_condition_mismatch(feeder)
    conditional_remove_executed_on_condition_match(feeder)
    conditional_update_not_executed_on_condition_mismatch(feeder)
    conditional_update_executed_on_condition_match(feeder)
    invalid_document_selection_should_fail(feeder)
    non_existing_document_should_fail(feeder)
    document_field_path_syntax_in_condition_should_not_fail_getting_the_attribute_name(feeder)
  end

  def conditional_put_not_executed_on_condition_mismatch(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_put_fail")
    query = query_by_field_values(timestamp: 1000, revision: 3)
    wait_for_hitcount(query, 0, 120)
    query = query_by_field_values(timestamp: 1000, revision: 1)
    wait_for_hitcount(query, 1, 120)
  end

  def conditional_put_executed_on_condition_match(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_put_success")
    query = query_by_field_values(timestamp: 1000, revision: 2)
    wait_for_hitcount(query, 1, 120)
  end

  def conditional_remove_not_executed_on_condition_mismatch(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_remove_fail")
    query = query_by_field_values(timestamp: 1000, revision: 1)
    wait_for_hitcount(query, 1, 120)
  end

  def conditional_remove_executed_on_condition_match(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_remove_success")
    query = query_by_field_values(timestamp: 1000, revision: 1)
    wait_for_hitcount(query, 0, 120)
  end

  def conditional_update_not_executed_on_condition_mismatch(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_update_fail")
    query = query_by_field_values(timestamp: 1000, revision: 3)
    wait_for_hitcount(query, 0, 120)
  end

  def conditional_update_executed_on_condition_match(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_update_success")
    query = query_by_field_values(timestamp: 1000, revision: 2)
    wait_for_hitcount(query, 1, 120)
  end
  
  def invalid_document_selection_should_fail(feeder)
    print_method(binding)
    feeder.call("weather")

    expect_illegal_parameters {
      doc = Document.new("weather", "id:weather:weather::0").
      add_field("timestamp", 1000).
      add_field("forecast", "snowing").
      add_field("snowstats", { "height" => 80, "fluffyness" => 3 }).
      add_field("revision", 2)
      vespa.document_api_v1.put(doc, :condition => "bjarne")
    }
  end

  def non_existing_document_should_fail(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_non_existing_document")
    assert_hitcount_withouttimeout("sddocname:weather", 4)
  end
  
  def document_field_path_syntax_in_condition_should_not_fail_getting_the_attribute_name(feeder)
    print_method(binding)
    feeder.call("weather")

    feeder.call("weather_update_map_condition")
    query = query_by_field_values(timestamp: 1002, revision: 2)
    wait_for_hitcount(query, 1, 120)
  end

  def teardown
    stop
  end

  def feed_filename(name, type)
    selfdir + name + "." + type.to_s
  end
end

def query_by_field_values(field_values)
  query_str = field_values.map { |field, value| "#{field}:#{value}" }.join "+"
  "query=#{query_str}&type=all"
end

# Prints method(param1 = value1, param2 = value2, ...)
def print_method(context)
  m = method(eval("__method__", context)) 
  params = m.parameters.map { |param| param[1] }
  param_list = params.map { |param| "#{param} = #{eval(param.to_s, context)}" }.join(', ')
  puts "#{m.name.to_s}(#{param_list})"
end

def expect_illegal_parameters
  begin
    yield
  rescue RuntimeError => ex
    # Rethrow exception if the error wasn't ILLEGAL_PARAMETERS,
    # otherwise, ignore the exception
    throw ex if (ex.message =~ /\(ILLEGAL_PARAMETERS,/) == nil
  else
    throw RuntimeError.new("Expected an exception after feeding")
  end
end
