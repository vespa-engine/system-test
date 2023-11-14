# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'doc_generator'
require 'set'
require 'uri'

class CollectionPerfTestBase < PerformanceTest

  FEED_TYPE        = 'feed_type'
  FAST_SEARCH      = 'fast_search'
  ELEMENTS_PER_DOC = 'elements_per_doc'

  MAX_UNIQUE_INT_TERMS    = 1000
  MAX_UNIQUE_STRING_TERMS = 1000
  MIN_STRING_TERM_LENGTH  = 3
  MAX_STRING_TERM_LENGTH  = 10

  # number of elements per document
  MAP_OF_STRUCT_ELEMENT_TEST_CASES = [1, 5, 10, 20]

  def initialize(*args)
    super(*args)
    @num_docs_total = 100_000
    @first_deploy = true
  end

  def wipe_indexes_and_deploy(with_fast_search:)
    if !@first_deploy
      vespa.stop_base
      vespa.adminserver.clean_indexes # Assumes only 1 node running test
    end
    deploy_app(create_app(with_fast_search: with_fast_search))
    start
    @first_deploy = false
  end

  def create_app(with_fast_search: false)
    sd = with_fast_search ? 'fast-search/test.sd' : 'no-fast-search/test.sd'
    SearchApp.new.sd(selfdir + sd).
      container(Container.new.documentapi(ContainerDocumentApi.new).search(Searching.new))
  end

  def file_in_tmp(file_name)
    dirs.tmpdir + file_name
  end

  def fancy_puts(str)
    puts '------'
    puts str
    puts '------'
  end

  class UniqueStringGenerator
    #TODO rng object, but rand_string must be augmented to use it first
    def UniqueStringGenerator.generate_set(n)
      strings = Set.new
      while strings.size != n
        strings.add StringGenerator.rand_string(MIN_STRING_TERM_LENGTH, MAX_STRING_TERM_LENGTH)
      end
      strings
    end
  end

  class FieldValueGenerator

    attr_reader :matching_strings, :matching_ints

    def initialize(max_string_fields:, max_int_fields:, max_matches_per_doc:)
      str_candidates = UniqueStringGenerator::generate_set(MAX_UNIQUE_STRING_TERMS).to_a
      # Pick string values that are only used for matches.
      # For simplicity, no value reuse across fields (separate posting lists anyway)
      @matching_strings = []
      [max_string_fields, max_matches_per_doc].max.times {|n| @matching_strings << str_candidates.pop }
      @mismatching_strings = str_candidates # Whatever's left

      # For ints, we just let 0..N be our magical matching numbers
      @matching_ints = []
      max_int_fields.times {|n| @matching_ints << n}
      @mismatching_ints = (max_int_fields..MAX_UNIQUE_INT_TERMS).to_a
    end

    def any_matching_string
      @matching_strings[rand(@matching_strings.size)]
    end

    def any_matching_int
      @matching_ints[rand(@matching_ints.size)]
    end

    def any_mismatching_string
      @mismatching_strings[rand(@mismatching_strings.size)]
    end

    def any_mismatching_int
      @mismatching_ints[rand(@mismatching_ints.size)]
    end

  end

  def doc_id(n)
    "id:foo:test::#{n}"
  end

  def generate_feed(feed_type, field_op_gen, file_name = 'struct_map_perf_feed.json')
    feed_file = file_in_tmp(file_name)
    File.open(feed_file, 'w') do |f|
      f.write("[\n")
      @num_docs_total.times do |n|
        f.write(",\n") if n > 0
        op = "{\"#{feed_type}\":\"#{doc_id(n)}\",\"fields\":{"
        op << field_op_gen.emit_fields(n)
        op << "}}"
        f.write(op)
      end
      f.write("\n]\n")
    end
    feed_file
  end

  def feed_with_profiling(feed_file, feed_type, fast_search, elements_per_doc)
    fancy_puts("feed_with_profiling(feed_type: #{feed_type}, fast_search: #{fast_search}, " +
               "elements_per_doc: #{elements_per_doc})")

    now = Time.now
    profiler_start
    fillers = [
      parameter_filler(FEED_TYPE, feed_type),
      parameter_filler(FAST_SEARCH, fast_search),
      parameter_filler(ELEMENTS_PER_DOC, elements_per_doc)
    ]
    run_feeder(feed_file, fillers, { :json => true })
    profiler_report(profiler_label(feed_type, fast_search, elements_per_doc))
    fancy_puts "feed_with_profiling took #{Time.now - now} seconds"
  end

  def feed_without_profiling(feed_file)
    feed(:file => feed_file)
  end

  def profiler_label(feed_type, fast_search, elements_per_doc)
    "#{FEED_TYPE}=#{feed_type}.#{FAST_SEARCH}=#{fast_search}.#{ELEMENTS_PER_DOC}=#{elements_per_doc}"
  end

  def filter_to_s(filter)
    filter.map{|k,v| "#{k}='#{v}'"}.join(',')
  end

end

