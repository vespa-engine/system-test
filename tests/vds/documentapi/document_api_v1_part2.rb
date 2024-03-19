require 'uri'
require 'vds/documentapi/document_api_v1_base'

class DocumentApiVdsPart2 < DocumentApiV1Base

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
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_array[0].lastname":{"assign":"Seinfeld"}}}')
    # ...Newman...! But with element match syntax. Replace the whole struct element.
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"person_array":{"match":{"element":2,"assign":{"lastname":"Newman"}}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    arrayData = JSON.parse(response)['fields']['person_array']
    assert_equal([{ 'firstname' => 'Jerry', 'lastname' => 'Seinfeld' },
                  { 'firstname' => 'Cosmo', 'lastname' => 'Kramer' },
                  { 'lastname' => 'Newman' }], arrayData)
  end

  def test_nested_array_of_array_of_weightedset_updates
    api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested":[[],[{"first":1},{"second":2}]]}}')
    # Let's change to 0-indexing, and add a third element ...
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested[1][0]{first}":{"increment":-1}}}')
    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested[1][1]{second}":{"assign":1}}}')
    # FIXME: this is bugged, FP to wset assumes array add ???
    # api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested[1][0]":{"add":{"third":2}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    puts("/document/v1 response: #{response}")
    arrayData = JSON.parse(response)['fields']['nested']
    # FIXME: where'd the first, empty element go!?
    # assert_equal([[], [{ 'first' => 0}, {'second' => 1}]], arrayData)
    assert_equal([[{ 'first' => 0}, {'second' => 1}]], arrayData)

    # ... reset the document ...
    api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested":[[],[{"first":1},{"second":2}]]}}')
    # ... and then do the same with match syntax.
    # FIXME: fails in docproc
    # api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested":{"match":{"element":1,"match":{"element":0,"match":{"element":"first","increment":-1}}}}}}')
    # api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested":{"match":{"element":1,"match":{"element":1,"match":{"element":"second","assign":1}}}}}}')
    # add not implemented for match syntax
    # api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"nested":{"match":{"element":1,"match":{"element":0,"add":{"third":2}}}}}}')

    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    puts("/document/v1 response: #{response}")
    arrayData = JSON.parse(response)['fields']['nested']
    # FIXME: where'd the first, empty element go!?
    # assert_equal([[], [{ 'first' => 0}, {'second' => 1}]], arrayData)
    assert_equal([[{ 'first' => 1}, {'second' => 2}]], arrayData)
  end

  def test_array_of_position_can_be_assigned
    api_http_post('/document/v1/storage_test/music/number/2/9', '{"fields":{"position_array": ["N41o40\'51;W72o56\'19", "N31o30\'41;W62o56\'18"]}}')
    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    array_field = JSON.parse(response)['fields']['position_array']
    assert_equal([{"lat"=>41.680833, "lng"=>-72.938611}, {"lat"=>31.511388, "lng"=>-62.938333}], array_field)

    api_http_put('/document/v1/storage_test/music/number/2/9', '{"fields":{"position_array":{"assign":["N42o42\'52;W82o66\'29"]}}}')
    response = api_http_get('/document/v1/storage_test/music/number/2/9')
    array_field = JSON.parse(response)['fields']['position_array']
    assert_equal([{"lat"=>42.714444, "lng"=>-83.108055}], array_field)
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

  def test_update_with_create_and_test_and_set_implicitly_creates_document
    set_owner('vekterli')
    set_description('An update with create=true and test-and-set will implicitly create a ' +
                    'missing document from scratch even if the condition does not match')

    api_http_put("/document/v1/storage_test/music/number/2/9?condition=#{CGI.escape('music.person.lastname=="Costanza"')}",
                 '{"create":true,"fields":{"title":{"assign":"A Festivus for the rest of us"}, "person.lastname":{"assign":"Costanza"}}}')
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'A Festivus for the rest of us', 'person' => {'lastname' => 'Costanza'}}, fields)

    # Now that the document _does_ exist, a mismatching TaS update should NOT go through
    assert_fails_with_precondition_violation {
      api_http_put("/document/v1/storage_test/music/number/2/9?condition=#{CGI.escape('music.person.lastname!="Costanza"')}",
                   '{"create":true,"fields":{"title":{"assign":"Serenity now!!"}}}')
    }
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'A Festivus for the rest of us', 'person' => {'lastname' => 'Costanza'}}, fields)

    # A matching selection should still update the document
    api_http_put("/document/v1/storage_test/music/number/2/9?condition=#{CGI.escape('music.person.lastname=="Costanza"')}",
                 '{"create":true,"fields":{"title":{"assign":"Serenity now!!"}}}')
    fields = JSON.parse(api_http_get('/document/v1/storage_test/music/number/2/9'))['fields']
    assert_equal({'title' => 'Serenity now!!', 'person' => {'lastname' => 'Costanza'}}, fields)
  end

end

