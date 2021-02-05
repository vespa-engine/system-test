require 'vds/documentapi/document_api_v1_base'

class DocumentApiVdsPart1 < DocumentApiV1Base

  def test_get_with_number
    response = api_http_get('/document/v1/storage_test/music/number/1/8')
    assert_json_string_equal(
      '{"fields":{"title":"title"},"id":"id:storage_test:music:n=1:8","pathId":"/document/v1/storage_test/music/number/1/8"}',
      response)
  end

  def test_visit_with_number
    response = api_http_get('/document/v1/storage_test/music/docid/')
    # Visit completes before covering the entire global bucket space, hence the continuation token.
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}}],"documentCount":1,' +
      '"pathId":"/document/v1/storage_test/music/docid/",' +
      '"continuation":"AAAACAAAAAAAAACCAAAAAAAAAIEAAAAAAAABAAAAAAEgAAAAAAAAgQAAAAAAAAAA"}',
      response)
    response = api_http_get('/document/v1/storage_test/music/number/1/')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}}],"documentCount":0,' +
      '"pathId":"/document/v1/storage_test/music/number/1/"}',
      response)
  end

  def test_visit_with_wanted_document_count_greater_than_doc_count_exhausts_bucket_space
    set_description('Test that Document V1 API visit wantedDocumentCount greater than the number ' +
                    'of available documents should exhaust the bucket space and return no continuation token')

    response = api_http_get('/document/v1/storage_test/music/docid/?wantedDocumentCount=2')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}}],"documentCount":1,' +
      '"pathId":"/document/v1/storage_test/music/docid/"}',
      response)
  end

  def test_visit_with_wanted_documents_respects_chunking
    set_description('Test that Document V1 visit wantedDocumentCount constrains the number of buckets returned, ' +
                    'and that the returned continuation token represents the next in-order bucket(s)')
    # Create 4 buckets in total
    feed_single(2, 1, 'Tango for two and a half')
    feed_single(3, 1, 'Beethoven, dubstep edition')
    feed_single(4, 1, 'Ibiza hitz 4 pensionerz')

    # First two buckets
    response = api_http_get('/document/v1/storage_test/music/docid/?wantedDocumentCount=2')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=4:1", "fields":{"title":"Ibiza hitz 4 pensionerz"}},' +
      '{"id":"id:storage_test:music:n=2:1", "fields":{"title":"Tango for two and a half"}}],"documentCount":2,' +
      '"pathId":"/document/v1/storage_test/music/docid/",' +
       '"continuation":"AAAACAAAAAAAAABCAAAAAAAAAEEAAAAAAAABAAAAAAEgAAAAAAAAggAAAAAAAAAA"}',
      response)

    # Last two buckets
    response = api_http_get('/document/v1/storage_test/music/docid/?wantedDocumentCount=2' +
                                       '&continuation=AAAACAAAAAAAAABCAAAAAAAAAEEAAAAAAAABAAAAAAEgAAAAAAAAggAAAAAAAAAA')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}},' +
      '{"id":"id:storage_test:music:n=3:1", "fields":{"title":"Beethoven, dubstep edition"}}],"documentCount":2,' +
      '"pathId":"/document/v1/storage_test/music/docid/",' +
       '"continuation":"AAAACAAAAAAAAADCAAAAAAAAAMEAAAAAAAABAAAAAAEgAAAAAAAAgwAAAAAAAAAA"}',
      response)

    # Bucket space is exhausted, empty result set returned with no continuation token
    response = api_http_get('/document/v1/storage_test/music/docid/?wantedDocumentCount=2' +
                                       '&continuation=AAAACAAAAAAAAADCAAAAAAAAAMEAAAAAAAABAAAAAAEgAAAAAAAAgwAAAAAAAAAA')
    assert_json_string_equal(
      '{"documents":[],"documentCount":0,"pathId":"/document/v1/storage_test/music/docid/"}',
      response)
  end

  def test_map_to_struct
    feed_single(2, 9)
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_by_age{2}":{"assign": {"firstname":"mr"}}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_by_age{2}.lastname": {"assign": "dude"}}}')

    # Verify
    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    arrayData = JSON.parse(response)['fields']['person_by_age']
    assert_equal({'2' => {'firstname' => 'mr', 'lastname' => 'dude'}}, arrayData)
  end

  def test_adding_element_to_map
    feed_single(2, 9)
    # Add two elements to the map
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{some_key}":{"assign": "magic_one"}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{some_key2}":{"assign": "magic_two"}}}')
    # Overwrite value of the first element
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{some_key}":{"assign": "magic_one_enhanced"}}}')

    # Add a new element and delete it twice
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{some_key3}":{"assign": "magic_one"}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{some_key3}":{"remove": 0}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{some_key3}":{"remove": 0}}}')

    # Verify total map
    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    my_map = JSON.parse(response)['fields']['string_string_map']
    assert_equal({'some_key' => 'magic_one_enhanced', 'some_key2' => 'magic_two'}, my_map)

    # Overwrite whole map
    api_http_put('/document/v1/storage_test/music/number/2/9',
        '{"fields":{"string_string_map":{"assign": {"fookey":"foovalue","fookey2":"foovalue2"}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    # Verify the overwrite
    new_map = JSON.parse(response)['fields']['string_string_map']
    assert_equal({'fookey' => 'foovalue', 'fookey2' => 'foovalue2'}, new_map)


    # Overwrite whole map, verify we can use old format for feeding
    api_http_put('/document/v1/storage_test/music/number/2/9',
        '{"fields":{"string_string_map":{"assign": [{"key":"fookey", "value":"foovalueold"},{"key":"fookey2","value":"foovalue2old"}]}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    # Verify the overwrite
    new_map = JSON.parse(response)['fields']['string_string_map']
    assert_equal({'fookey' => 'foovalueold', 'fookey2' => 'foovalue2old'}, new_map)
  end

  def test_update_map_element_with_escaped_map_key
    api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map":{"a \'fancy\\" key":"not so fancy value"}}}')
    # Replace existing element
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{\"a \'fancy\\\\\" key\"}":{"assign": "more fancy value"}}}')
    # Add new element with escaped key
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_string_map{\"here be dragons\"}":{"assign": "value with lots of dragons"}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    new_map = JSON.parse(response)['fields']['string_string_map']
    assert_equal({'a \'fancy" key' => 'more fancy value', 'here be dragons' => 'value with lots of dragons'}, new_map)
  end

  def test_adding_element_to_weightedset
    feed_single(2, 9, 'title')
    # Add two elements to the set
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age{alice}":{"assign": "7"}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age{bob}":{"assign": "42"}}}')
    # Overwrite value of the first element
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age{alice}":{"assign": "8"}}}')

    # Add a new element and delete it
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age{eve}":{"assign": "45"}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age{eve}":{"remove": 0}}}')

    # Verify total set
    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    assert_json_string_equal('{"fields":{"title":"title","person_to_age":{"alice":8, "bob":42}},'+
      '"id":"id:storage_test:music:n=2:9",'+
      '"pathId":"/document/v1/storage_test/music/number/2/9"}', response)

    # Overwrite whole set
    api_http_put('/document/v1/storage_test/music/number/2/9',
        '{"fields":{"person_to_age":{"assign": {"dan":"10","frank":"11"}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    assert_json_string_equal('{"fields":{"title":"title","person_to_age":{"frank":11, "dan":10}},'+
      '"id":"id:storage_test:music:n=2:9",'+
      '"pathId":"/document/v1/storage_test/music/number/2/9"}', response)

    # Add using key/value syntax instead of fieldpath (note: "add" instead of "assign")
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age":{"add":{"alice":8,"frank":12}}}}')
    wset = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']['person_to_age']
    assert_equal({'alice' => 8, 'frank' => 12, 'dan' => 10}, wset)
  end

  def test_can_remove_weighted_set_entries_with_legacy_syntax
    feed_single(2, 9, 'title')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age":{"assign":{"alice":8,"frank":12}}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age":{"remove":{"frank":0}}}}')

    wset = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']['person_to_age']
    assert_equal({'alice' => 8}, wset)
  end

end
