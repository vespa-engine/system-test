# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'collection_perf_test_base'

class SameElementPerformanceTest < CollectionPerfTestBase

  FBENCH_RUNTIME = 30
  FBENCH_CLIENTS = 20

  COLLECTION_TYPE = 'collection_type'
  MAP_OF_STRUCT   = 'map_of_struct'
  MAP_OF_STRING   = 'map_of_string'
  ARRAY_OF_STRUCT = 'array_of_struct'

  def initialize(*args)
    super(*args)
    @num_docs_with_matches = @num_docs_total / 10
  end

  def setup
    super
    set_owner('vekterli')
  end

  def teardown
    super
  end

  def test_same_element_operator_with_map_of_struct
    set_description('Test use of sameElement() operator for map of struct with varying number of elements per map')
    @query_file_name = file_in_tmp('queries.txt')
    puts "Using query file: '#{@query_file_name}'"
    [false, true].each do |fast_search|
      run_map_of_struct_same_element_test_cases(fast_search: fast_search)
    end
  end

  def run_map_of_struct_same_element_test_cases(fast_search:)
    fancy_puts "run_map_of_struct_same_element_test_cases(fast_search: #{fast_search})"

    wipe_indexes_and_deploy(with_fast_search: fast_search)

    MAP_OF_STRUCT_ELEMENT_TEST_CASES.each do |elements_per_doc|
      feed_and_query_map_of_struct(fast_search: fast_search, elements_per_doc: elements_per_doc)
    end
  end

  class MapOfStructsFeedGenerator

    def initialize(total_doc_count:, docs_with_matches:, elems_per_doc:, matches_per_doc:)
      if elems_per_doc < matches_per_doc
        raise "elems_per_doc(#{elems_per_doc}) cannot be < matches_per_doc(#{matches_per_doc})"
      end
      @elems_per_doc = elems_per_doc
      @matches_per_doc = matches_per_doc
      @fv = CollectionPerfTestBase::FieldValueGenerator.new(max_string_fields: 2, max_int_fields: 3, max_matches_per_doc: matches_per_doc)
      @is_match_vector = uniformly_distributed_bit_vector(total_doc_count, docs_with_matches)
    end

    def uniformly_distributed_bit_vector(total, num_true)
      # Calling this a 'bit vector' is a bit (heh!) of a stretch, but Ruby has no built in data structure for this.
      vec = Array.new(num_true, true).concat(Array.new(total - num_true, false))
      vec.shuffle!
      vec
    end

    # struct fields in SD file:
    #  f1: int
    #  f2: string
    #  f3: int
    #  f4: string
    #  f5: int
    def matching_struct_element
      {
        'f1' => @fv.matching_ints[0],
        'f2' => @fv.matching_strings[0],
        'f3' => @fv.matching_ints[1],
        'f4' => @fv.matching_strings[1],
        'f5' => @fv.matching_ints[2]
     }
    end

    def mismatching_struct_element
      {
        'f1' => @fv.any_mismatching_int,
        'f2' => @fv.any_mismatching_string,
        'f3' => @fv.any_mismatching_int,
        'f4' => @fv.any_mismatching_string,
        'f5' => @fv.any_mismatching_int
      }
    end

    def emit_fields(n)
      fields = {}
      matches = @is_match_vector[n] ? @matches_per_doc : 0
      matches.times do |n|
        fields['@' + @fv.matching_strings[n]] = matching_struct_element
      end
      (@elems_per_doc - matches).times do |n|
        fields['@' + @fv.any_mismatching_string] = mismatching_struct_element
      end
      "\"struct_map\":#{fields.to_json}"
    end
  end

  def same_element_yql_query(field, same_element)
    "select * from sources * where #{field} contains sameElement(#{same_element})"
  end

  def write_query_to_disk(query)
    File.open(@query_file_name, 'w') do |f|
      f.puts('/search/?yql=' + CGI::escape(query))
    end
  end

  def copy_query_to_container(query, container)
    write_query_to_disk(query)
    copy_query_file(container)
  end

  def copy_query_file(container)
    container.copy(@query_file_name, File.dirname(@query_file_name))
  end

  MapOfStructDataSet = Struct.new(:feed_file, :matching_query)

  def generate_initial_map_of_struct_feed(elements_per_doc:)
    gen = MapOfStructsFeedGenerator.new(total_doc_count: @num_docs_total,
                                        docs_with_matches: @num_docs_with_matches,
                                        elems_per_doc: elements_per_doc,
                                        matches_per_doc: 1)
    feed_file = generate_feed('put', gen)

    m = gen.matching_struct_element
    # We only match on values, not on the key. All looks and smells the same for the backend.
    same_element = "value.f1 contains '#{m['f1']}', " +
                   "value.f2 contains '#{m['f2']}', " +
                   "value.f3 contains '#{m['f3']}', " +
                   "value.f4 contains '#{m['f4']}', " +
                   "value.f5 contains '#{m['f5']}'"
    query = same_element_yql_query('struct_map', same_element)

    MapOfStructDataSet.new(feed_file, query)
  end

  def feed_and_query_map_of_struct(fast_search:, elements_per_doc:)
    fancy_puts "feed_and_query_map_of_struct(fast_search: #{fast_search}, elements_per_doc: #{elements_per_doc})"

    data_set = generate_initial_map_of_struct_feed(elements_per_doc: elements_per_doc)

    feed_without_profiling(data_set.feed_file) # Feed profiling done in separate test
    run_same_element_queries(data_set.matching_query, MAP_OF_STRUCT, fast_search, elements_per_doc)
  end

  def run_same_element_queries(query, collection_type, fast_search, elements_per_doc)
    fancy_puts("run_same_element_queries(collection_type: #{collection_type}, fast_search: #{fast_search}, " +
               "elements_per_doc: #{elements_per_doc})")

    assert_hitcount("yql=#{query}", @num_docs_with_matches) # Sanity check

    clients = FBENCH_CLIENTS
    fillers = [
      parameter_filler(COLLECTION_TYPE, collection_type),
      parameter_filler(FAST_SEARCH, fast_search),
      parameter_filler(ELEMENTS_PER_DOC, elements_per_doc)
    ]
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    copy_query_to_container(query, container)
    run_fbench2(container, @query_file_name, {:runtime => FBENCH_RUNTIME, :clients => clients}, fillers)
  end

end

