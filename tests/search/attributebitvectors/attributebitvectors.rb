# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class AttributeBitVectors < SearchTest

  def setup
    set_owner('toregge')
    set_description("Test use of attribute posting list bitvectors")
    @num_docs = 4096
    @rank_profiles = [ 'unranked', 'default', 'onlya', 'onlyaf' ]
  end

  def get_app
    sc = SearchCluster.new('attributebitvectors')
    sc.sd(selfdir + '/test.sd').threads_per_search(1)
    app = SearchApp.new.cluster(sc)
  end

  # Control approximate document frequencies for the generated data
  # i.e. "rare" occurs in about 50 of 4096 documents, "common" occurs in
  # about 200 of 4096 documents and "stop" occurs in the remaining ones.
  def word_data
    'echo "50 rare 200 common 3846 stop"'
  end

  def doc_template
    '{ "put": "id:ns:test::$seq()", "fields": { "a": { "$words(1)" : 200 } } }'
  end

  # Feed @num_docs generated documents. The word "rare" should never have
  # a bitvector variant of posting list, while words "common" and "stop"
  # will have bitvector variants of posting lists when bitvectors are enabled.
  def feed_data
    command = DataGenerator.new.feed_command(template: doc_template, count: @num_docs, data: word_data)
    feed_stream(command, {})
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def doc_count_query_string
    '/search/?' + URI.encode_www_form([['query', 'sddocname:test'],
                                       ['nocache'],
                                       ['hits', '0'],
                                       ['ranking', 'unranked'],
                                       ['timeout', '5.0'],
                                      ])
  end

  def doc_count
    qrserver.search(doc_count_query_string).hitcount
  end


  def trace_query_string(field, term, ranking)
    '/search/?' + URI.encode_www_form([['query', "#{field}:#{term}"],
                                       ['nocache'],
                                       ['hits', '0'],
                                       ['ranking', ranking],
                                       ['tracelevel', 7],
                                       ['timeout', '5.0'],
                                       ['model.type', 'all'],
                                      ])
  end

  def get_iterators_trace(json)
    if json.is_a?(Array)
      for elem in json
        result = get_iterators_trace(elem)
        return result unless result.nil?
      end
    end
    return nil unless json.is_a?(Hash)
    if json.has_key?('tag') && json.has_key?('optimized')
      if json['tag'] == 'iterator'
        return json['optimized']
      end
    end
    for key in [ 'children', 'message', 'threads', 'trace', 'traces']
      if json.has_key?(key)
        result = get_iterators_trace(json[key])
        return result unless result.nil?
      end
    end
    nil
  end

  def count_bitvector_iterators_in_trace(json)
    if json.is_a?(Array)
      result = 0
      for elem in json
        result += count_bitvector_iterators_in_trace(elem)
      end
      return result
    end
    return 0 unless json.is_a?(Hash)
    if json.has_key?('children')
      result = 0
      if json['children'].is_a?(Hash)
        json['children'].each do |k,v|
          result += count_bitvector_iterators_in_trace(v)
        end
      end
      return result
    end
    if json.has_key?('[type]')
      if json['[type]'] =~ /BitVector/
        return 1
      end
    end
    return 0
  end

  def trace_query(field, term, ranking)
    result = qrserver.search(trace_query_string(field, term, ranking))
    iterators_trace = get_iterators_trace(result.json)
    puts "iterators trace for query '#{field}:#{term}' rank profile '#{ranking}' is"
    puts JSON.pretty_generate(iterators_trace)
    bv_count = count_bitvector_iterators_in_trace(iterators_trace)
    puts "bv_count is #{bv_count}"
    bv_count
  end

  def assert_bv_counts(field, term, counts)
    assert_equal(@rank_profiles.size, counts.size)
    for i in 0...@rank_profiles.size
      assert_equal(counts[i], trace_query(field, term, @rank_profiles[i]))
    end
  end

  def test_attributevectors
    deploy_app(get_app)
    start
    feed_data
    assert_equal(@num_docs, doc_count)
    assert_bv_counts('a', 'rare', [0, 0, 0, 0])
    assert_bv_counts('af', 'rare', [0, 0, 0, 0])
    assert_bv_counts('a', 'common', [1, 0, 0, 1])
    assert_bv_counts('af', 'common', [1, 1, 1, 1])
  end

  def teardown
    stop
  end
end
