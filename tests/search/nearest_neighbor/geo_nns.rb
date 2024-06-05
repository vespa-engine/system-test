# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class GeoNnsTest < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
  end

  def query_and_print(query_props)
    query = get_query(query_props)
    puts "geo query='#{query}'"
    askhits = query_props[:target_num_hits]
    if askhits == 7
      fullq = get_query(query_props.merge({:max_hits => 2*askhits}))
      result = search(fullq)
      puts "hits: #{result.hit.size}"
      result.hit.each do |hit|
        txt = hit.field['text']
        pos = hit.field['pos_hnsw']
        sfs = hit.field['summaryfeatures']
        dsf = sfs['distance(label,nns)']
        miles = dsf.to_f / 1.609344
        puts "Hit: #{txt}  => #{pos} -> #{dsf} km -> #{miles.to_i} miles"
      rescue => e
        puts "PROBLEM #{e} processing hit in result:"
        puts "#{result}"
        puts "xml data:"
        puts "#{result.xmldata}"
        assert_equal("hit was not OK", hit)
      end
    end
    search(query)
  end

  def geo_check(lat, lon, query_props = {})
    query_props[:x_0] = lat
    query_props[:x_1] = lon
    result = query_and_print(query_props)
    query_props[:approx] = "false"
    assert_geo_search(query_props, result)
    query_props[:doc_tensor] = "pos"
    assert_geo_search(query_props, result)
  end

  def assert_geo_search(query_props, approx_result)
    query = get_query(query_props)
    puts "assert_geo_search(): query='#{query}'"
    exact_result = search(query)
    assert_equal(exact_result.hit.size, approx_result.hit.size)
    exact_result.hit.zip(approx_result.hit).each do |exp_hit, act_hit|
      exp_hit.check_equal(act_hit)
    end
  end

  def split_line(line)
    lld = line.chomp.split(':')
    assert_equal(3, lld.size)
    lat, lon, txt = lld
    place = {:lat => lat, :lon => lon, :txt => txt}
  end

  def feed_doc(idx, place)
    doc = Document.new("geo", "id:test:geo::#{idx}").
          add_field("pos", { "values" => [place[:lat], place[:lon]] }).
          add_field("pos_hnsw", { "values" => [place[:lat], place[:lon]] }).
          add_field("text", place[:txt])
    vespa.document_api_v1.put(doc, {:brief => true})
  end

  def geo_deploy(num_ready_copies = 1)
    app = SearchApp.new.
        sd(selfdir + "geo.sd").
        num_parts(2).redundancy(2).ready_copies(num_ready_copies).
        threads_per_search(1)
    deploy_app(app)
  end

  def test_geo_airports
    set_description("Test the nearest neighbor search operator for geo search")
    geo_deploy
    start
    i=0
    places = []
    File.open(selfdir + 'airports.txt').each_line do |line|
      place = split_line(line)
      places.push(place)
      feed_doc(i, place)
      i += 1
    end
    wait_for_hitcount('?query=sddocname:geo', i)
    puts "Done put of #{i} documents"
    places.each do |place|
      geo_check(place[:lat], place[:lon], {:target_num_hits => 4})
    end
    assert_hitcount('query=sddocname:geo', i)
  end

  def test_geo_cities
    set_description("Test the nearest neighbor search operator for geo search (with whitelist)")
    geo_deploy(2)
    start
    # Note: Need to use :vespa_feeder to be able to set maxpending, otherwise
    # feeding order might not give the same HNSW graph for every run
    feed(:file => selfdir + "5k-docs.json", :numthreads => 1, :client => :vespa_feeder, :maxpending => 1 )
    i=5000
    puts "Done put of #{i} documents"
    wait_for_hitcount('?query=sddocname:geo', i)
    geo_check(63.0, 10.0, {:target_num_hits => 100})
    places = []
    File.open(selfdir + 'airports.txt').each_line do |line|
      places.push(split_line(line))
    end
    places.each do |place|
      [ 50, 7 ].each do |numhits|
        geo_check(place[:lat], place[:lon], {:target_num_hits => numhits})
      end
      geo_check(place[:lat], place[:lon], {:target_num_hits => 9, :filter => "san"})
    end
    places.each do |place|
      geo_check(place[:lat], place[:lon], {:target_num_hits => 50, :threshold => 50.5})
    end
  end

  def get_query(qprops)
    x_0 = qprops[:x_0] || 0
    x_1 = qprops[:x_1] || 0
    target_num_hits = qprops[:target_num_hits] || 10
    query_tensor = qprops[:query_tensor] || 'qpos_double'
    doc_tensor = qprops[:doc_tensor] || 'pos_hnsw'
    approx = qprops[:approx]
    filter = qprops[:filter]
    threshold = qprops[:threshold]
    max_hits = qprops[:max_hits] || target_num_hits

    result = "yql=select * from sources * where {targetNumHits: #{target_num_hits},"
    result += "approximate: #{approx}," if approx
    result += "distanceThreshold: #{threshold}," if threshold
    result += "label: \"nns\"} nearestNeighbor(#{doc_tensor},#{query_tensor})"
    result += " and text contains \"#{filter}\"" if filter
    result += "&ranking.features.query(#{query_tensor})={{x:0}:#{x_0},{x:1}:#{x_1}}"
    result += "&hits=#{max_hits}"
    return result
  end

  def teardown
    stop
  end
end
