require 'multi_provider_storage_test'
require 'uri'

class DocumentApiVds < MultiProviderStorageTest

  def setup
    set_owner('valerijf')

    deploy_app(default_app.sd(selfdir+'music.sd').distribution_bits(8))

    start

    # Just to make it possible to run test repeatedly without taking down cluster
    vespa.document_api_v1.http_delete('/document/v1/storage_test/music/number/1/8')
    vespa.document_api_v1.http_delete('/document/v1/storage_test/music/number/2/9')

    feed_single(1, 8)
  end

  def self.testparameter
    { 'PROTON' => { :provider => 'PROTON' } }
  end

  def api_http_post(path, content, headers={})
    vespa.document_api_v1.http_post(path, content, {}, headers)
  end

  def api_http_put(path, content, headers={})
    vespa.document_api_v1.http_put(path, content, {}, headers)
  end

  def api_http_get(path)
    response = vespa.document_api_v1.http_get(path)
    vespa.document_api_v1.assert_response_ok(response)
    response.body
  end

  def test_get_with_number
    response = api_http_get('/document/v1/storage_test/music/number/1/8')
    assert_json_string_equal(
      '{"fields":{"title":"title"},"id":"id:storage_test:music:n=1:8","pathId":"/document/v1/storage_test/music/number/1/8"}',
      response)
  end

  def test_visit_with_number
    response = api_http_get('/document/v1/storage_test/music/number/')
    # Visit completes before covering the entire global bucket space, hence the continuation token.
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}}],"pathId":"/document/v1/storage_test/music/number/",' +
      '"continuation":"AAAACAAAAAAAAACCAAAAAAAAAIEAAAAAAAABAAAAAAEgAAAAAAAAgQAAAAAAAAAA"}',
      response)
    response = api_http_get('/document/v1/storage_test/music/number/1/')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}}],"pathId":"/document/v1/storage_test/music/number/1/"}',
      response)
  end

  def test_visit_with_wanted_document_count_greater_than_doc_count_exhausts_bucket_space
    set_owner('vekterli')
    set_description('Test that Document V1 API visit wantedDocumentCount greater than the number ' +
                    'of available documents should exhaust the bucket space and return no continuation token')

    response = api_http_get('/document/v1/storage_test/music/number/?wantedDocumentCount=2')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}}],' +
      '"pathId":"/document/v1/storage_test/music/number/"}',
      response)
  end

  def feed_single(uid, doc_num, title = 'title')
    response = api_http_post("/document/v1/storage_test/music/number/#{uid}/#{doc_num}", "{\"fields\":{\"title\":\"#{title}\"}}")
    assert_json_string_equal(
      "{\"id\":\"id:storage_test:music:n=#{uid}:#{doc_num}\",\"pathId\":\"/document/v1/storage_test/music/number/#{uid}/#{doc_num}\"}",
      response)
    response
  end

  def test_visit_with_wanted_documents_respects_chunking
    set_owner('vekterli')
    set_description('Test that Document V1 visit wantedDocumentCount constrains the number of buckets returned, ' +
                    'and that the returned continuation token represents the next in-order bucket(s)')
    # Create 4 buckets in total
    feed_single(2, 1, 'Tango for two and a half')
    feed_single(3, 1, 'Beethoven, dubstep edition')
    feed_single(4, 1, 'Ibiza hitz 4 pensionerz')

    # First two buckets
    response = api_http_get('/document/v1/storage_test/music/number/?wantedDocumentCount=2')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=4:1", "fields":{"title":"Ibiza hitz 4 pensionerz"}},' +
      '{"id":"id:storage_test:music:n=2:1", "fields":{"title":"Tango for two and a half"}}],' +
      '"pathId":"/document/v1/storage_test/music/number/",' +
       '"continuation":"AAAACAAAAAAAAABCAAAAAAAAAEEAAAAAAAABAAAAAAEgAAAAAAAAggAAAAAAAAAA"}',
      response)

    # Last two buckets
    response = api_http_get('/document/v1/storage_test/music/number/?wantedDocumentCount=2' +
                                       '&continuation=AAAACAAAAAAAAABCAAAAAAAAAEEAAAAAAAABAAAAAAEgAAAAAAAAggAAAAAAAAAA')
    assert_json_string_equal(
      '{"documents":[{"id":"id:storage_test:music:n=1:8", "fields":{"title":"title"}},' +
      '{"id":"id:storage_test:music:n=3:1", "fields":{"title":"Beethoven, dubstep edition"}}],' +
      '"pathId":"/document/v1/storage_test/music/number/",' +
       '"continuation":"AAAACAAAAAAAAADCAAAAAAAAAMEAAAAAAAABAAAAAAEgAAAAAAAAgwAAAAAAAAAA"}',
      response)

    # Bucket space is exhausted, empty result set returned with no continuation token
    response = api_http_get('/document/v1/storage_test/music/number/?wantedDocumentCount=2' +
                                       '&continuation=AAAACAAAAAAAAADCAAAAAAAAAMEAAAAAAAABAAAAAAEgAAAAAAAAgwAAAAAAAAAA')
    assert_json_string_equal(
      '{"documents":[],"pathId":"/document/v1/storage_test/music/number/"}',
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

  def test_assigning_struct_field_sets_all_sub_fields
    feed_single(2, 9)
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person":{"assign":{"firstname":"George","lastname":"Costanza"}}}}')
    field = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']['person']
    assert_equal({'firstname' => 'George', 'lastname' => 'Costanza'}, field)

    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person":{"assign":{"firstname":"Cosmo","lastname":"Kramer"}}}}')
    field = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']['person']
    assert_equal({'firstname' => 'Cosmo', 'lastname' => 'Kramer'}, field)
  end

  def test_can_clear_field_with_null_assign
    feed_single(2, 9)
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"title":{"assign":null}}}')
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({}, fields)
  end

  def test_fieldpath_struct
    feed_single(2, 9)
    # Add two elements to the set
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person.firstname":{"assign": "bob"}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person.lastname":{"assign": "the plumber"}}}')
    # Overwrite value of the first element
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person.firstname":{"assign": "Bob"}}}')

    # Verify total set
    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    data = JSON.parse(response)['fields']['person']
    assert_equal({'firstname' => 'Bob', 'lastname' => 'the plumber'}, data)
  end

  def test_fieldpath_array
    feed_single(2, 9)
    # Add an element outside array, for some reason this is a 200.
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array[2]":{"assign": "zoombie"}}}')

    # add a few elements
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array":{"add": ["dog", "frog"]}}}')

    # rewrite first element
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array[0]":{"assign": "bob"}}}')

    # Verify total array
    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    arrayData = JSON.parse(response)['fields']['string_array']
    assert_equal(['bob', 'frog'], arrayData)
  end

  def test_array_of_struct_updates
    api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_array": [{"firstname":"Jerry"},{"firstname":"Comso"}, {"firstname":"???"}]}}')
    # Whoops we typoed, let's fix that with an update
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_array[1]":{"assign":{"firstname": "Cosmo","lastname":"Kramer"}}}}')
    # Should be able to give Jerry a last name as well
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_array[0].lastname":{"assign":"Seinfeld"}}}}')
    # ...Newman...! But with element match syntax. Replace the whole struct element.
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_array":{"match":{"element":2,"assign":{"lastname":"Newman"}}}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    arrayData = JSON.parse(response)['fields']['person_array']
    assert_equal([{ 'firstname' => 'Jerry', 'lastname' => 'Seinfeld' },
                  { 'firstname' => 'Cosmo', 'lastname' => 'Kramer' },
                  { 'lastname' => 'Newman' }], arrayData)
  end

  def test_array_element_match_update_affects_specified_index
    response = api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array": ["foo", "bar", "baz"]}}')
    assert_json_string_equal(
      '{"id":"id:storage_test:music:n=2:9","pathId":"/document/v1/storage_test/music/number/2/9"}',
      response)

    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array":{"match":{"element": 1, "assign": "blorg"}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    arrayData = JSON.parse(response)['fields']['string_array']
    assert_equal(['foo', 'blorg', 'baz'], arrayData)
  end

  def test_array_update_to_invalid_index_is_ignored
    response = api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array": ["foo"]}}')
    # Array element 1 does not exist. Update is silently ignored.
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"string_array":{"match":{"element": 1, "assign": "blorg"}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    arrayData = JSON.parse(response)['fields']['string_array']
    assert_equal(['foo'], arrayData)
  end

  def test_fieldpath_arithmetic
    feed_single(2, 9)
    # Create a struct with int value
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":' +
      '{"person.firstname":{"assign": "bob"},"person.salary":{"assign": 1000}}}')

    # Give bob a 5% raise!
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person.salary":{"multiply": 1.05}}}')

    # Populate a weightedset
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":' +
      '{"person_to_age":{"assign": {"eve": 44, "alice": 12}}}}')

    # Increment undefined number, for some reason this is a 200.
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_to_age{bob}":{"increment": 1}}}')

    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":'+
      '{"person_to_age{eve}":{"divide": 4}, "person_to_age{alice}":{"decrement": 5}}}')

    # Verify
    response = api_http_get('/document/v1/storage_test/music/number/2/9')

    data = JSON.parse(response)['fields']
    assert_equal({'firstname' => 'bob', 'salary' => 1050}, data['person'])
    assert_equal({'alice' => 7, 'bob' => 1, 'eve' => 11}, data['person_to_age'])
  end

  def test_update_with_create_set_implicitly_creates_document
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"create":true,"fields":{"title":{"assign":"Mackinaw peaches, Jerry!"}}}')
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'Mackinaw peaches, Jerry!'}, fields)
  end

  def assert_fails_with_precondition_violation
    begin
      yield
      flunk('Expected operation to fail with an exception')
    rescue HttpResponseError => e
      assert_equal(412, e.response_code) # HTTP 412 Precondition Failed
    end
  end

  def test_update_with_create_and_test_and_set_implicitly_creates_document
    set_owner('vekterli')
    set_description('An update with create=true and test-and-set will implicitly create a ' +
                    'missing document from scratch even if the condition does not match')

    api_http_put("/document/v1/storage_test/music/number/2/9?condition=#{URI.escape('music.person.lastname=="Costanza"')}",
                 '{"create":true,"fields":{"title":{"assign":"A Festivus for the rest of us"}, "person.lastname":{"assign":"Costanza"}}}')
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'A Festivus for the rest of us', 'person' => {'lastname' => 'Costanza'}}, fields)

    # Now that the document _does_ exist, a mismatching TaS update should NOT go through
    assert_fails_with_precondition_violation {
      api_http_put("/document/v1/storage_test/music/number/2/9?condition=#{URI.escape('music.person.lastname!="Costanza"')}",
                   '{"create":true,"fields":{"title":{"assign":"Serenity now!!"}}}')
    }
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'A Festivus for the rest of us', 'person' => {'lastname' => 'Costanza'}}, fields)

    # A matching selection should still update the document
    api_http_put("/document/v1/storage_test/music/number/2/9?condition=#{URI.escape('music.person.lastname=="Costanza"')}",
                 '{"create":true,"fields":{"title":{"assign":"Serenity now!!"}}}')
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'Serenity now!!', 'person' => {'lastname' => 'Costanza'}}, fields)
  end

  def teardown
    stop
  end
end

