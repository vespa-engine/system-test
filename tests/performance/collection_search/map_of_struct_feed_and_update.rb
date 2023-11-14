# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'collection_perf_test_base'

class MapOfStructFeedAndUpdatePerformanceTest < CollectionPerfTestBase

  BASELINE_FEED    = 'baseline_feed'
  REPLACE_UPDATE   = 'replace_update'
  FIELDPATH_UPDATE = 'fieldpath_update'

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner('vekterli')
  end

  def teardown
    super
  end

  def test_map_of_struct_feeding_and_updates
    set_description('Test feeding, field and element-wise partial updates for map of struct')
    [false, true].each do |fast_search|
      run_map_of_struct_test_cases(fast_search: fast_search)
    end
  end

  class GeneratorBase

    def initialize(field_value_gen)
      @fv = field_value_gen
      @rand = Random.new(123456789) # Want deterministic PRNG output
    end

    def arbitrary_struct_element_data
      # This is very hardcoded to our schema, but then again so is the rest of the test.
      {
        'f1' => @fv.any_mismatching_int,
        'f2' => @fv.any_mismatching_string,
        'f3' => @fv.any_mismatching_int,
        'f4' => @fv.any_mismatching_string,
        'f5' => @fv.any_mismatching_int
      }
    end

  end

  class MapOfStructsInitialFeedGenerator < GeneratorBase

    def initialize(elements_per_doc:, field_value_gen:)
      super(field_value_gen)
      @elems_per_doc = elements_per_doc
    end

    def emit_fields(n)
      fields = {}
      @elems_per_doc.times do |i|
        # For now, let all entries have a globally unique key
        fields["@#{n}-#{i}"] = arbitrary_struct_element_data
      end
      "\"struct_map\":#{fields.to_json}"
    end

  end

  class MapOfStructsFullFieldUpdateGenerator < GeneratorBase

    def initialize(elements_per_doc:, field_value_gen:)
      super(field_value_gen)
      @elems_per_doc = elements_per_doc
    end

    def emit_fields(n)
      fields = {}
      @elems_per_doc.times do |i|
        fields["@#{n}-#{i}"] = arbitrary_struct_element_data
      end
      "\"struct_map\":{\"assign\":#{fields.to_json}}"
    end

  end

  class MapOfStructsFieldPathUpdateGenerator < GeneratorBase

    def initialize(elements_per_doc:, field_value_gen:)
      super(field_value_gen)
      @elems_per_doc = elements_per_doc
    end

    def emit_fields(n)
      key = "@#{n}-#{@rand.rand(@elems_per_doc)}"
      "\"struct_map{#{key}}\":{\"assign\":#{arbitrary_struct_element_data.to_json}\}"
    end

  end

  def run_map_of_struct_test_cases(fast_search:)
    fancy_puts "run_map_of_struct_tests(fast_search: #{fast_search})"
    wipe_indexes_and_deploy(with_fast_search: fast_search)

    MAP_OF_STRUCT_ELEMENT_TEST_CASES.each do |elements_per_doc|
      fv = FieldValueGenerator.new(max_string_fields: 2, max_int_fields: 3, max_matches_per_doc: 0)

      feed_baseline(fv, fast_search, elements_per_doc)
      update_replace_all_map_fields(fv, fast_search, elements_per_doc)
      field_path_update_element_in_all_maps(fv, fast_search, elements_per_doc)
    end
  end

  def feed_baseline(fv, fast_search, elements_per_doc)
    feed_file = generate_feed('put', MapOfStructsInitialFeedGenerator.new(elements_per_doc: elements_per_doc, field_value_gen: fv),
                              "map_of_struct_baseline_feed-#{elements_per_doc}.json")
    feed_with_profiling(feed_file, BASELINE_FEED, fast_search, elements_per_doc)
  end

  def update_replace_all_map_fields(fv, fast_search, elements_per_doc)
    feed_file = generate_feed('update', MapOfStructsFullFieldUpdateGenerator.new(elements_per_doc: elements_per_doc, field_value_gen: fv),
                              "map_of_struct_full_update-#{elements_per_doc}.json")
    feed_with_profiling(feed_file, REPLACE_UPDATE, fast_search, elements_per_doc)
  end

  def field_path_update_element_in_all_maps(fv, fast_search, elements_per_doc)
    feed_file = generate_feed('update', MapOfStructsFieldPathUpdateGenerator.new(elements_per_doc: elements_per_doc, field_value_gen: fv),
                              "map_of_struct_fieldpath_update-#{elements_per_doc}.json")
    feed_with_profiling(feed_file, FIELDPATH_UPDATE, fast_search, elements_per_doc)
  end

end

