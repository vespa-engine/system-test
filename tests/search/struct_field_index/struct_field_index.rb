# coding: utf-8
# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

# Tests struct fields with 'indexing: index' in array of struct and map fields (indexed search),
# alone and combined with struct field attributes in sameElement.
class StructFieldIndex < IndexedOnlySearchTest

  def setup
    set_owner('arnej')
  end

  def test_struct_field_index
    set_description('Test indexes of struct fields in array of struct and map fields, also with sameElement')
    deploy_and_feed
    assert_queries
    # Restart without flushing, so the memory index is rebuilt by replaying the transaction log
    restart_proton('test', 2, skip_trigger_flush: true)
    assert_queries
    vespa.search['search'].first.trigger_flush
    assert_queries # now from disk index
    assert_updates
    assert_remove
  end

  def test_struct_field_index_element_assign
    set_description('Test assigning a whole element of an array of struct field with struct field indexes')
    deploy_and_feed
    assert_element_assign
  end

  # Disabled: other field path updates into fields with struct field indexes (map entries, and struct fields
  # of elements) are rejected by the indexing docproc, as the updated values would not be tokenized.
  # Enable when the indexing pipeline supports them.
  def no_test_struct_field_index_field_path_updates
    set_description('Test field path updates into array of struct and map fields with struct field indexes')
    deploy_and_feed
    assert_field_path_updates
  end

  def deploy_and_feed
    # Struct field indexes are rejected at deployment unless enabled by this flag
    set_feature_flag(vespa.nodeproxies.values.first, 'allow-struct-field-index', ['value' => 'allow'])
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_docs
  end

  def feed_docs
    # The maps have several entries, so that sameElement must find the right entry, and the entries
    # must have the same element ids in the indexes and the attributes.
    put_doc(0,
            [{ 'name' => 'John Smith', 'year' => 1980 }, { 'name' => 'Jane Doe', 'year' => 1990 }],
            { 'Red Color' => 'Bright Sun', 'blue' => 'Night' },
            { 'a' => { 'name' => 'Alice Smith', 'year' => 2000 }, 'c' => { 'name' => 'Carol Jones', 'year' => 1960 } },
            [{ 'plain' => 'Bright Day', 'nostem' => 'Smith Cafés', 'nonorm' => 'café', 'exact' => 'Red Color' }],
            [{ 'a' => 1, 'b' => 17, 'c' => 'Foo Bar Baz', 'd' => 'The quick brown Fox'}])

    # The second element has no name, which must not shift the element ids of the name index
    # relative to the year attribute. The years differ, so a shift would change the hits.
    put_doc(1,
            [{ 'name' => 'John Doe', 'year' => 1990 }, { 'year' => 1980 }, { 'name' => 'Jane Smith', 'year' => 1985 }],
            { 'blue' => 'Dark Sky' },
            { 'b' => { 'name' => 'Bob Doe', 'year' => 1970 } },
            [{ 'plain' => 'Café', 'exact' => 'Red' }],
            [{ 'a' => 1, 'b' => 17, 'c' => 'Bar Baz', 'd' => 'The quick brown Fox'},
             { 'a' => 1, 'b' => 17, 'c' => 'Foo Bar Baz', 'd' => 'The quick Fox'}])
    wait_for_hitcount('?query=sddocname:test', 2)
  end

  def put_doc(id, persons, tags, people, entries, metadata = [])
    doc = Document.new("id:test:test::#{id}").
            add_field('id', id).
            add_field('persons', persons).
            add_field('tags', tags).
            add_field('people', people).
            add_field('entries', entries).
            add_field('metadata', metadata)
    vespa.document_api_v1.put(doc)
  end

  def assert_queries
    # Array of struct
    assert_ids('persons.name contains "smith"', [0, 1])
    assert_ids('persons.name contains "jane"', [0, 1])
    assert_ids('persons.name contains phrase("john", "smith")', [0])
    assert_ids('persons.name contains "nobody"', [])
    assert_ids('persons.name contains "john" and persons.name contains "doe"', [0, 1])
    assert_ids('persons contains sameElement(name contains "john", name contains "doe")', [1])
    # Struct field index combined with struct field attribute
    assert_ids('persons contains sameElement(name contains "john", year = 1980)', [0])
    assert_ids('persons contains sameElement(name contains "jane", year = 1990)', [0])
    assert_ids('persons contains sameElement(name contains "jane", year = 1985)', [1])
    assert_ids('persons contains sameElement(name contains "jane", year = 1980)', [])
    assert_ids('persons contains sameElement(name contains "john", year = 1970)', [])
    assert_ids('metadata contains sameElement(a=1, range(b, 10, 20), c contains "foo", d contains "brown")', [0])
    # Positions do not run across elements
    assert_ids('persons.name contains phrase("smith", "jane")', [])

    # Map of primitive types, with indexed key and value
    assert_ids('tags.key contains "red"', [0])
    assert_ids('tags.key contains "color"', [0])
    assert_ids('tags.value contains "sky"', [1])
    # Struct field indexes are stemmed like other indexes ("reds" stems to "red"; "colors" is not stemmed at all)
    assert_ids('tags.key contains "reds"', [0])
    assert_ids('persons.name contains "smiths"', [0, 1])
    assert_ids('tags contains sameElement(key contains "red", value contains "sun")', [0])
    assert_ids('tags contains sameElement(key contains "blue", value contains "night")', [0])
    assert_ids('tags contains sameElement(key contains "blue", value contains "sky")', [1])
    # Key and value from different entries of the same map
    assert_ids('tags contains sameElement(key contains "blue", value contains "sun")', [])
    assert_ids('tags contains sameElement(key contains "red", value contains "night")', [])

    # Map of struct
    assert_ids('people.value.name contains "smith"', [0])
    assert_ids('people contains sameElement(key contains "b", value.name contains "bob")', [1])
    assert_ids('people contains sameElement(key contains "a", value.name contains "bob")', [])
    assert_ids('people contains sameElement(value.name contains "alice", value.year = 2000)', [0])
    assert_ids('people contains sameElement(value.name contains "alice", value.year = 1970)', [])
    assert_ids('people contains sameElement(key contains "c", value.name contains "carol")', [0])
    assert_ids('people contains sameElement(key contains "a", value.name contains "carol")', [])
    assert_ids('people contains sameElement(value.name contains "carol", value.year = 1960)', [0])
    assert_ids('people contains sameElement(value.name contains "carol", value.year = 2000)', [])

    # Fieldset of struct field indexes
    assert_ids('names contains "alice"', [0])
    assert_ids('names contains "doe"', [0, 1])

    assert_matching_elements('persons contains sameElement(name contains "jane", year = 1990)', { '1' => 1.0 })
    assert_matched_elements_only
    assert_index_settings
  end

  # Settings given in a struct-field block apply both when indexing and when querying the struct field index
  def assert_index_settings
    # stemming: none
    assert_ids('entries.nostem contains "smith"', [0])
    assert_ids('entries.nostem contains "smiths"', [])
    assert_ids('entries.nostem contains "cafés"', [0])
    assert_ids('entries.nostem contains "café"', [])

    # normalizing: none keeps accents, while the default removes them
    assert_ids('entries.nonorm contains "café"', [0])
    assert_ids('entries.nonorm contains "cafe"', [])
    assert_ids('entries.plain contains "cafe"', [1])
    assert_ids('entries.plain contains "café"', [1])

    # match: exact matches the whole (lowercased) value
    assert_ids('entries.exact contains "red color"', [0])
    assert_ids('entries.exact contains "Red Color"', [0])
    assert_ids('entries.exact contains "red"', [1])
    assert_ids('entries.exact contains "color"', [])
    assert_ids('entries contains sameElement(exact contains "red color", plain contains "bright")', [0])
    assert_ids('entries contains sameElement(exact contains "red", plain contains "bright")', [])
  end

  def assert_matched_elements_only
    john_smith = { 'name' => 'John Smith', 'year' => 1980 }
    jane_doe = { 'name' => 'Jane Doe', 'year' => 1990 }
    john_doe = { 'name' => 'John Doe', 'year' => 1990 }
    no_name = { 'year' => 1980 }
    jane_smith = { 'name' => 'Jane Smith', 'year' => 1985 }
    alice = { 'name' => 'Alice Smith', 'year' => 2000 }
    carol = { 'name' => 'Carol Jones', 'year' => 1960 }
    bob = { 'name' => 'Bob Doe', 'year' => 1970 }
    # Note: Empty arrays and empty maps are not rendered in search results
    empty = nil

    # sameElement over struct field indexes only
    assert_matched(1, 'persons contains sameElement(name contains "john", name contains "doe")', 'persons_meo', [john_doe])
    assert_matched(0, 'tags contains sameElement(key contains "blue", value contains "night")', 'tags_meo', { 'blue' => 'Night' })
    # sameElement over struct field indexes and attributes
    assert_matched(0, 'persons contains sameElement(name contains "jane", year = 1990)', 'persons_meo', [jane_doe])
    assert_matched(1, 'persons contains sameElement(name contains "jane", year = 1985)', 'persons_meo', [jane_smith])
    assert_matched(0, 'people contains sameElement(key contains "c", value.name contains "carol")', 'people_meo', { 'c' => carol })
    assert_matched(0, 'people contains sameElement(value.name contains "alice", value.year = 2000)', 'people_meo', { 'a' => alice })

    # Single term on a struct field index
    assert_matched(0, 'persons.name contains "jane"', 'persons_meo', [jane_doe])
    assert_matched(1, 'persons.name contains "jane"', 'persons_meo', [jane_smith])
    assert_matched(1, 'persons.name contains "doe" or persons.name contains "smith"', 'persons_meo', [john_doe, jane_smith])
    assert_matched(0, 'tags.key contains "red"', 'tags_meo', { 'Red Color' => 'Bright Sun' })
    assert_matched(1, 'tags.value contains "sky"', 'tags_meo', { 'blue' => 'Dark Sky' })
    assert_matched(0, 'people.value.name contains "smith"', 'people_meo', { 'a' => alice })
    # Single term on a struct field attribute (baseline). The element without a name must not shift the element ids.
    assert_matched(0, 'persons.year = 1980', 'persons_meo', [john_smith])
    assert_matched(1, 'persons.year = 1980', 'persons_meo', [no_name])
    assert_matched(1, 'people.key contains "b"', 'people_meo', { 'b' => bob })

    # near / onear on a struct field index
    assert_matched(0, 'persons.name contains near("smith", "john")', 'persons_meo', [john_smith])
    assert_matched(0, 'persons.name contains onear("jane", "doe")', 'persons_meo', [jane_doe])

    # Fieldset of struct field indexes, matching in two complex fields
    assert_matched(1, 'names contains "doe"', 'persons_meo', [john_doe])
    assert_matched(1, 'names contains "doe"', 'people_meo', { 'b' => bob })
    assert_matched(0, 'names contains "doe"', 'people_meo', empty)

    # No elements matched in the other fields
    assert_matched(0, 'persons.name contains "jane"', 'tags_meo', empty)
    assert_matched(0, 'persons.name contains "jane"', 'people_meo', empty)
    assert_matched(0, 'tags.key contains "red"', 'persons_meo', empty)

    # select-elements-by a summary feature over the complex field
    assert_matched(0, 'persons contains sameElement(name contains "jane", year = 1990)', 'persons_sel', [jane_doe])
    assert_matched(1, 'persons contains sameElement(name contains "john", name contains "doe")', 'persons_sel', [john_doe])
  end

  # Checks the summary field in summary 'matched' for the document with the given id, among the hits for 'where'.
  def assert_matched(id, where, field, exp_value)
    yql = "select * from sources * where (#{where}) and id = #{id}"
    result = search({ 'yql' => yql, 'summary' => 'matched', 'hits' => '10' })
    children = result.json['root']['children'] || []
    assert_equal(1, children.size, "Unexpected hits for: #{yql}")
    assert_equal(exp_value, children[0]['fields'][field], "Unexpected #{field} for: #{yql}")
  end

  # Checks the elements of 'persons' matched in the only hit, as seen from ranking.
  def assert_matching_elements(where, exp_cells)
    result = search({ 'yql' => "select * from sources * where #{where}", 'hits' => '10' })
    children = result.json['root']['children'] || []
    assert_equal(1, children.size, "Unexpected hits for: #{where}")
    feature = children[0]['fields']['matchfeatures']['elementwise(matches(persons),x,double)']
    assert_equal('tensor(x{})', feature['type'], "Unexpected feature for: #{where}")
    assert_equal(exp_cells, feature['cells'], "Unexpected matching elements for: #{where}")
  end

  def assert_updates
    # Adding elements and assigning the whole field are indexed
    upd = DocumentUpdate.new('test', 'id:test:test::1')
    upd.addOperation('add', 'persons', [{ 'name' => 'Carl Smith', 'year' => 2020 }])
    vespa.document_api_v1.update(upd)
    assert_ids('persons contains sameElement(name contains "carl", year = 2020)', [1])
    assert_ids('persons contains sameElement(name contains "jane", year = 1985)', [1])

    # Removing elements is indexed
    upd = DocumentUpdate.new('test', 'id:test:test::1')
    upd.addOperation('remove', 'persons', [{ 'name' => 'Carl Smith', 'year' => 2020 }])
    vespa.document_api_v1.update(upd)
    assert_ids('persons.name contains "carl"', [])
    assert_ids('persons contains sameElement(name contains "jane", year = 1985)', [1])

    upd = DocumentUpdate.new('test', 'id:test:test::0')
    upd.addOperation('assign', 'persons', [{ 'name' => 'Eve Stone', 'year' => 1995 }, { 'name' => 'Frank Doe', 'year' => 1980 }])
    vespa.document_api_v1.update(upd)
    assert_ids('persons contains sameElement(name contains "eve", year = 1995)', [0])
    assert_ids('persons contains sameElement(name contains "frank", year = 1995)', [])
    assert_ids('persons contains sameElement(name contains "frank", year = 1980)', [0])
    assert_ids('persons.name contains "john"', [1])

    upd = DocumentUpdate.new('test', 'id:test:test::0')
    upd.addOperation('assign', 'tags', { 'green' => 'Grass' })
    vespa.document_api_v1.update(upd)
    assert_ids('tags contains sameElement(key contains "green", value contains "grass")', [0])
    assert_ids('tags.key contains "red"', [])
  end

  def assert_remove
    assert_ids('persons.name contains "jane"', [1])
    vespa.document_api_v1.remove('id:test:test::1')
    wait_for_hitcount('?query=sddocname:test', 1)
    assert_ids('persons.name contains "jane"', [])
    assert_ids('persons contains sameElement(name contains "jane", year = 1985)', [])
    assert_ids('tags.value contains "sky"', [])
    assert_ids('tags contains sameElement(key contains "blue", value contains "sky")', [])
    assert_ids('people.value.name contains "bob"', [])
    assert_ids('people contains sameElement(key contains "b", value.name contains "bob")', [])
    assert_ids('names contains "bob"', [])
    # The other document is still there
    assert_ids('people contains sameElement(key contains "c", value.name contains "carol")', [0])
  end

  # Assigns of whole array elements, on the documents from feed_docs. The assigned element must be tokenized
  # and indexed like when assigning the whole field, and line up with the struct field attributes.
  def assert_element_assign
    field_path_update('persons[0]', { 'name' => 'Dan Doe', 'year' => 2021 })
    assert_ids('persons contains sameElement(name contains "dan", year = 2021)', [0])
    assert_ids('persons contains sameElement(name contains "john", year = 1980)', [])
    assert_ids('persons contains sameElement(name contains "jane", year = 1990)', [0])
    assert_ids('persons.name contains "john"', [1])
    assert_matched(0, 'persons.name contains "dan"', 'persons_meo', [{ 'name' => 'Dan Doe', 'year' => 2021 }])

    # Also from the disk index
    vespa.search['search'].first.trigger_flush
    assert_ids('persons contains sameElement(name contains "dan", year = 2021)', [0])
    assert_ids('persons.name contains "john"', [1])

    # Assign the element without a name in the other document
    field_path_update('persons[1]', { 'name' => 'Erin Doe', 'year' => 1980 }, 'assign', 1)
    assert_ids('persons contains sameElement(name contains "erin", year = 1980)', [1])
    assert_ids('persons contains sameElement(name contains "jane", year = 1985)', [1])
    assert_matched(1, 'persons.name contains "doe"', 'persons_meo',
                   [{ 'name' => 'John Doe', 'year' => 1990 }, { 'name' => 'Erin Doe', 'year' => 1980 }])
  end

  # Field path updates of single elements, struct fields of elements, and map entries, on the documents
  # from feed_docs. The updated values must be tokenized and indexed like when assigning the whole field.
  def assert_field_path_updates
    # Add a map entry, then change and remove it
    field_path_update('tags{green}', 'Lawn')
    assert_ids('tags contains sameElement(key contains "green", value contains "lawn")', [0])
    field_path_update('tags{green}', 'Grass')
    assert_ids('tags contains sameElement(key contains "green", value contains "grass")', [0])
    assert_ids('tags.value contains "lawn"', [])
    field_path_update('tags{green}', 0, 'remove')
    assert_ids('tags.key contains "green"', [])
    assert_ids('tags.value contains "grass"', [])
    assert_ids('tags contains sameElement(key contains "red", value contains "sun")', [0])

    # Assign a whole array element
    field_path_update('persons[0]', { 'name' => 'Dan Doe', 'year' => 2021 })
    assert_ids('persons contains sameElement(name contains "dan", year = 2021)', [0])
    assert_ids('persons contains sameElement(name contains "john", year = 1980)', [])
    assert_ids('persons contains sameElement(name contains "jane", year = 1990)', [0])

    # Assign a struct field in an array element
    field_path_update('persons[1].name', 'Erin Doe')
    assert_ids('persons contains sameElement(name contains "erin", year = 1990)', [0])
    assert_ids('persons contains sameElement(name contains "jane", year = 1990)', [])
    assert_ids('persons.name contains "jane"', [1])

    # Assign a struct field in a map value
    field_path_update('people{a}.name', 'Ann Smith')
    assert_ids('people contains sameElement(key contains "a", value.name contains "ann")', [0])
    assert_ids('people contains sameElement(value.name contains "ann", value.year = 2000)', [0])
    assert_ids('people.value.name contains "alice"', [])
  end

  def field_path_update(field_path, value, operation = 'assign', id = 0)
    upd = DocumentUpdate.new('test', "id:test:test::#{id}")
    upd.addOperation(operation, field_path, value)
    vespa.document_api_v1.update(upd)
  end

  def assert_ids(where, expected_ids)
    result = search({ 'yql' => "select * from sources * where #{where}", 'hits' => '10' })
    children = result.json['root']['children'] || []
    ids = children.map { |hit| hit['fields']['id'] }.sort
    assert_equal(expected_ids, ids, "Unexpected hits for: #{where}")
  end

end
