# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'

class StreamingMatcher < StreamingSearchTest

  def timeout_seconds
    3600
  end

  def content_node_bucket_count(idx)
    vespa.storage['storage'].storage[idx.to_s].get_bucket_count
  end

  def assert_rank(expected, docid, query, ranking)
    query = "query=" + query + "&ranking=" + ranking + "&streaming.userid=1"
    result = search(query)
    documentid = "id:music:musicsearch:n=1:#{docid}"
    hit = find_hit(result, "documentid", documentid)
    if hit != nil
        actual = hit.field["relevancy"].to_f
        assert_equal(expected.to_f, actual)
    end
    assert(hit != nil, "Did not find a hit with 'documentid'=='#{documentid}")
  end

  def find_hit(result, field, content)
    result.hit.each do |hit|
      if hit.field[field] == content
        return hit
      end
    end
    return nil
  end

  def assert_ftm(t_fp, t_occ, l_fp, l_occ, docid, query, field)
    query = "query=" + query + "&streaming.userid=1"
    result = search(query)
    documentid = "id:music:musicsearch:n=1:#{docid}"
    hit = find_hit(result, "documentid", documentid)
    exp = {"fieldTermMatch(title,0).firstPosition" => t_fp, \
           "fieldTermMatch(title,0).occurrences" => t_occ, \
           "fieldTermMatch(lyrics,0).firstPosition" => l_fp, \
           "fieldTermMatch(lyrics,0).occurrences" => l_occ }
    if hit != nil
      assert_features(exp, hit.field[field], 1e-4)
    end
    assert(hit != nil, "Did not find a hit with 'documentid'=='#{documentid}")
  end

  def assert_first_phase(exp, docid, query, ranking, empty=false)
    query = "query=" + query + "&ranking=" + ranking + "&streaming.userid=1"
    result = search(query)
    documentid = "id:music:musicsearch:n=1:#{docid}"
    hit = find_hit(result, "documentid", documentid)
    if hit != nil
      if !empty
        assert_features({"firstPhase" => exp}, hit.field["summaryfeatures"], 1e-4)
      else
        assert(hit.field["summaryfeatures"] == "", "'summaryfeatures' was not empty")
      end
    end
    assert(hit != nil, "Did not find a hit with 'documentid'=='#{documentid}")
  end

  def assert_first_position(fp, field, query)
    query = "query=" + query + "&ranking=sf&streaming.userid=1"
    result = search(query)
    exp = {"fieldTermMatch(#{field},0).firstPosition" => fp}
    assert_features(exp, result.hit[0].field["summaryfeatures"], 1e-4)
  end

  def assert_attribute_rank(exp, field)
    query = "query=ss:first&ranking=sf&streaming.userid=1"
    result = search(query)
    assert_features({"attribute(#{field})" => exp}, result.hit[0].field["summaryfeatures"], 1e-4)
  end

  def assert_result_order(query, docids)
    result = search(query)
    assert_equal(result.hit.size, docids.size)
    i = 0
    result.hit.each do |hit|
      assert_equal(hit.field["documentid"], "id:sortaggr:sortaggr:n=1:#{docids[i]}")
      i += 1
    end
  end

  def get_query(hits, offset = 0, sort = nil)
    query = "query=sddocname:heap&streaming.userid=1&rankfeatures&hits=#{hits}&offset=#{offset}"
    if sort != nil
      query += "&sorting=#{sort}"
    end
    return query
  end

  def assert_heap_property(query, hits)
    puts "assert_heap_property: query(#{query}), hits(#{hits.size})"
    result = search(query)
    assert_equal(hits.size, result.hit.size)
    hits.each_index do |i|
      documentid = "id:heap:heap:n=1:#{hits[i]}"
      rank = hits[i] * 10
      feature = hits[i]
      puts "Expects hit #{i} to have documentid(#{documentid}), rank(#{rank}), and feature(#{feature})"
      assert_relevancy(query, rank, i)
      expf = {"attribute(f1)" => feature}
      assert_features(expf, result.hit[i].field["rankfeatures"])
      assert_features(expf, result.hit[i].field["summaryfeatures"])
      assert_equal(documentid, result.hit[i].field["documentid"])
    end
  end

  def assert_result_include?(result, expected)
    assert(result.xmldata.include?(expected), "Expected '#{expected}' in result:#{result.xmldata}")
  end

  def teardown
    stop
  end


end
