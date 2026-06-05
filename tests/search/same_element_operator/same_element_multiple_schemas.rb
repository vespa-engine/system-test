# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

require 'json'

class SameElementMultipleSchemas < IndexedStreamingSearchTest

  def setup
    set_owner('boeker')
    @query_simple = {'yql' => "select * from sources * where simple_string_field contains 'f1'"}
    @query_same_element = {'yql' => "select * from sources * where custom_fields_string contains sameElement(key contains 'f1', value contains 'hello')"}
  end

  def self.final_test_methods
    ['test_multiple_schemas_when_indexed',
     'test_multiple_schemas_when_streaming']
  end

  def feed_and_wait
    # Feed document
    vespa.document_api_v1.put(Document.new("id:withfield:withfield::0").add_field("custom_fields_string", {"f1" => "hello"}).add_field("simple_string_field", "f1"))
    wait_for_hitcount("?query=sddocname:withfield", 1)
  end

  def test_multiple_schemas_when_indexed
    @params = { :search_type => "INDEXED" }
    set_description('Use sameElement operator with multiple schemas where only one contains the searched field')
    deploy_app(SearchApp.new.sd(selfdir + 'multiple_schemas/withfield.sd').sd(selfdir + 'multiple_schemas/withoutfield.sd'))
    start

    feed_and_wait

    # Queries with and without sameElement that search both the schema containing the field and the schema not containing the field
    assert_result_contains_no_errors(@query_simple)
    assert_result_contains_no_errors(@query_same_element)
  end

  def test_multiple_schemas_when_streaming
    @params = { :search_type => "STREAMING" }
    set_description('Use sameElement operator with multiple schemas where only one contains the searched field')
    deploy_app(SearchApp.new.sd(selfdir + 'multiple_schemas/withfield.sd').sd(selfdir + 'multiple_schemas/withoutfield.sd'))
    start

    feed_and_wait

    # Queries with and without sameElement that search both the schema containing the field and the schema not containing the field
    assert_result_contains_errors(@query_simple)
    assert_result_contains_errors(@query_same_element)
  end

  def assert_result_contains_no_errors(query)
    puts "Sending query: #{query}"
    result = search(query)
    puts JSON.pretty_generate(result.json)

    # Make sure that the no error is produced by the schema without the field
    assert(!result.json['root'].key?('errors'))
  end

  def assert_result_contains_errors(query)
    puts "Sending query: #{query}"
    result = search(query)
    puts JSON.pretty_generate(result.json)

    # Make sure that an error is produced by the schema without the field
    assert(result.json['root'].key?('errors'))
  end

end
