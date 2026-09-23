# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'
require 'json'
require 'uri'

# Every bucket from FilterIntersectionsSearcher must equal the hit count of the
# same filter intersection run as a plain query.
class FilterIntersectionsTest < IndexedStreamingSearchTest

  NEAR = [[40.20, -75.13], [40.16, -75.18], [40.19, -75.12], [40.15, -75.16]]    # < 25 miles
  FAR  = [[34.05, -118.24], [47.61, -122.33], [25.76, -80.19], [41.88, -87.63]]  # >> 25 miles
  EDGE_IN  = [40.537055, -75.150116]  # ~24.5 miles out
  EDGE_OUT = [40.552983, -75.150116]  # ~25.6 miles out

  TAGS = {
    "yes"       => [{"kind" => "certifications", "label" => "Energy Star"}],
    "wrongkind" => [{"kind" => "labels",         "label" => "Energy Star"}],
    # kind and label in different elements: plain AND would match, sameElement must not
    "split"     => [{"kind" => "certifications", "label" => "Fair Trade"},
                    {"kind" => "labels",         "label" => "Energy Star"}],
    "case"      => [{"kind" => "certifications", "label" => "energy star"}],
    "missing"   => nil,
  }
  FEATURES = {
    "full"    => ["Bluetooth", "GPS", "Waterproof"],
    "wifi"    => ["Wifi", "GPS", "Waterproof"],
    "partial" => ["Bluetooth", "GPS"],
    "none"    => ["Solar", "Compass"],
    "missing" => nil,
  }
  METRICS = {
    "yes"     => [{"label" => "warranty", "value" => 36}],
    "low"     => [{"label" => "warranty", "value" => 12}],
    # no single element has both label warranty and value >= 24
    "split"   => [{"label" => "warranty", "value" => 12},
                  {"label" => "weight",   "value" => 36}],
    "missing" => nil,
  }

  # [active, region, geo, category, tags, features, metrics]
  ITEMS = [
    [true,  "EU", "near",     1, "yes",       "full",    "yes"],
    [true,  "EU", "near",     1, "yes",       "wifi",    "yes"],
    [true,  "EU", "near",     2, "yes",       "partial", "low"],
    [true,  "EU", "near",     1, "split",     "none",    "split"],
    [true,  "EU", "far",      1, "yes",       "full",    "yes"],
    [true,  "EU", "far",      2, "wrongkind", "partial", "low"],
    [true,  "EU", "near",     3, "case",      "full",    "yes"],
    [true,  "EU", "far",      3, "yes",       "none",    "split"],
    [true,  "EU", "near",     2, "wrongkind", "wifi",    "yes"],
    [true,  "EU", "far",      1, "split",     "partial", "yes"],
    [true,  "EU", "edge_in",  2, "yes",       "none",    "low"],
    [true,  "EU", "edge_out", 2, "yes",       "full",    "yes"],
    [true,  "EU", "missing",  2, "missing",   "missing", "missing"],
    # outside the base query
    [false, "EU", "near",     1, "yes",       "full",    "yes"],
    [true,  "US", "near",     1, "yes",       "full",    "yes"],
    [true,  "JP", "far",      1, "yes",       "wifi",    "yes"],
  ]

  # [active, region, category]
  SUPPLIERS = [
    [true,  "EU", 1],
    [true,  "EU", 1],
    [true,  "EU", 2],
    [true,  "EU", 3],
    [true,  "US", 1],
    [false, "EU", 1],
  ]

  BASE = 'active = true and region contains "EU"'

  WHERE = {
    "geo"       => 'geoLocation(location, 40.182465, -75.150116, "25 miles")',
    "category"  => 'category = 1',
    "certified" => 'tags contains sameElement(kind contains "certifications", label contains "Energy Star")',
    "features"  => '(features contains "Bluetooth" or features contains "Wifi") ' +
                   'and features contains "GPS" and features contains "Waterproof"',
    "warranty"  => 'metrics contains sameElement(label contains "warranty", value >= 24)',
    "phantom"   => 'category = 99',
    "in"        => 'category in (1, 3)',
    "numrange"  => 'range(category, 2, 3)',
    "cmp"       => 'category >= 2',
    "boolops"   => '!(category = 1) and (features contains "Solar" or features contains "Compass")',
    "regex"     => 'region matches "EU"',
    "weakAnd"   => 'weakAnd(features contains "Solar", features contains "Compass")',
    "nonEmpty"  => 'nonEmpty(features contains "Solar")',
    "userInput" => '{defaultIndex: "features"} userInput(@featureWord)',
    # nearestNeighbor is only a filter with distanceThreshold; targetHits must cover every candidate
    "nn"        => '{targetHits: 1000, distanceThreshold: 0.5}nearestNeighbor(embedding, q)',
  }

  def setup
    set_owner("sebasabe")
    set_description("Exact hit counts for every intersection of named YQL filters, via FilterIntersectionsSearcher.")
    chain = SearchChain.new("default", "vespa").
      add(Searcher.new("ai.vespa.search.counting.FilterIntersectionsSearcher", nil, nil, nil, "container-search-and-docproc"))
    deploy_app(SearchApp.new.sd(selfdir + "item.sd").sd(selfdir + "supplier.sd").search_chain(chain))
    start
    puts "Feeding #{ITEMS.size} item and #{SUPPLIERS.size} supplier documents (#{is_streaming ? 'streaming' : 'indexed'} mode)"
    feed_file = dirs.tmpdir + "docs.json"
    File.write(feed_file, JSON.generate(documents))
    feed_and_wait_for_docs("item", ITEMS.size, :file => feed_file)
    wait_for_hitcount("query=sddocname:supplier&nocache&hits=0&streaming.selection=true", SUPPLIERS.size)
  end

  # One test method, so the app is deployed and fed only once per mode.
  def test_filter_intersections
    puts "Each check sends one query with filterIntersections.filters, then verifies every returned bucket " +
         "against a plain query counting the same filters ANDed with the base condition."

    step("Main filters (geo, numeric, sameElement on arrays of structs, array of strings) must all match something")
    main_filters = %w[geo category certified features warranty]
    buckets = assert_intersections(main_filters)
    main_filters.each { |f| assert(buckets[f] > 0, "Fixture must match filter #{f}") }

    step("A filter matching nothing gives zero, alone and combined")
    buckets = assert_intersections(%w[category phantom])
    assert_equal(0, buckets["phantom"])
    assert_equal(0, buckets["category&phantom"])

    step("Base condition 'true' counts filters over all documents")
    assert_intersections(%w[certified category], where: "true")

    step("YQL operators as filters: in, range, comparison, boolean ops, regex, weakAnd, nonEmpty, userInput")
    assert_intersections(%w[in numrange cmp boolops regex weakAnd nonEmpty userInput],
                         params: {"featureWord" => "Solar"})

    step("userInput in both the base condition and a filter")
    assert_intersections(%w[userInput category],
                         where: 'active = true and ({defaultIndex: "region"} userInput(@baseRegion))',
                         params: {"baseRegion" => "EU", "featureWord" => "Solar"})

    # the fork keeps the main query's sources, so a cell counts documents of every named type
    step("Multiple sources: counts cover every document type the main query searches")
    assert_intersections(%w[category cmp in], sources: "item, supplier")
    assert_intersections(%w[category cmp in], sources: "*")
    assert_intersections(%w[category cmp], sources: "supplier")
    assert_intersections(%w[category regex], sources: "item, supplier", where: "true")

    # streaming runs hits=0 queries with the unranked profile, which lacks the query tensor
    if is_streaming
      step("Skipping nearestNeighbor filter: not supported with hits=0 in streaming mode")
    else
      step("nearestNeighbor with distanceThreshold as a filter")
      assert_intersections(%w[nn category], params: {"input.query(q)" => "[1.0, 0.0]"})
    end

    step("An invalid filter must be rejected with an error naming the filter (the error below is expected)")
    broken = JSON.generate([{"name" => "broken", "where" => "this is not ( yql"}])
    assert_query_errors(search_url("item", BASE, {"filterIntersections.filters" => broken}),
                        [".*Filter 'broken': invalid YQL.*"])
  end

  # Asserts the buckets for the given filters and returns them as key => totalCount.
  def assert_intersections(names, where: BASE, sources: "item", params: {})
    filters = JSON.generate(names.map { |name| {"name" => name, "where" => WHERE[name]} })
    root = query(sources, where, params.merge("filterIntersections.filters" => filters))
    buckets = root["fields"]["filterIntersections"]["buckets"]
    expected = expected_buckets(names, where, sources, params)
    puts "  sources: #{sources}, base: #{where}"
    expected.each do |e|
      actual = buckets.find { |b| b["key"] == e["key"] }
      puts "  %-28s searcher=%-4s plain query=%s" % [e["key"], actual ? actual["totalCount"] : "missing", e["totalCount"]]
    end
    assert_equal(expected, buckets, "Buckets for #{names} from #{sources} where #{where}")
    buckets.map { |bucket| [bucket["key"], bucket["totalCount"]] }.to_h
  end

  # Filters sorted by name, then every single and every pair, each counted with a plain query.
  def expected_buckets(names, where, sources, params)
    sorted = names.sort_by(&:downcase)
    cells = sorted.combination(1).to_a + sorted.combination(2).to_a
    cells.map do |cell|
      conditions = ([where] + cell.map { |name| WHERE[name] }).map { |c| "(#{c})" }.join(" and ")
      count = query(sources, conditions, params)["fields"]["totalCount"]
      {"key" => cell.join("&"), "names" => cell, "totalCount" => count}
    end
  end

  def step(description)
    puts ""
    puts "=== #{description}"
  end

  def query(sources, where, params)
    root = search(search_url(sources, where, params)).json["root"]
    assert_nil(root["errors"], "Unexpected errors for #{where}: #{root['errors']}")
    root
  end

  def search_url(sources, where, params)
    "/search/?" + URI.encode_www_form({"yql" => "select * from sources #{sources} where #{where}", "hits" => "0"}.merge(params))
  end

  def documents
    items = ITEMS.each_with_index.map do |(active, region, geo, category, tags, features, metrics), i|
      id = i + 1
      coord = {"near" => NEAR[id % 4], "far" => FAR[id % 4], "edge_in" => EDGE_IN, "edge_out" => EDGE_OUT}[geo]
      fields = {"active" => active, "region" => region, "category" => category,
                "tags" => TAGS[tags], "features" => FEATURES[features], "metrics" => METRICS[metrics]}.compact
      if coord
        fields["location"] = {"lat" => coord[0], "lng" => coord[1]}
        fields["embedding"] = {"values" => id.even? ? [1.0, 0.0] : [0.0, 1.0]}
      end
      {"put" => "id:item:item::#{id}", "fields" => fields}
    end
    suppliers = SUPPLIERS.each_with_index.map do |(active, region, category), i|
      {"put" => "id:supplier:supplier::#{i + 1}",
       "fields" => {"active" => active, "region" => region, "category" => category}}
    end
    items + suppliers
  end

  def teardown
    stop
  end

end
