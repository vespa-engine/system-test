# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'
require 'json'
require 'uri'

# Exercises ai.vespa.search.counting.FilterIntersectionsSearcher end to end:
# exact total hit counts for every combination of named YQL filters, computed
# as forked count-only queries against real content nodes.
#
# Ground truth is derived in Ruby from the same generated documents, so every
# expected bucket is computed, not scripted.
class FilterIntersectionsTest < IndexedStreamingSearchTest

  CENTER = [40.182465, -75.150116]
  NEAR = [[40.20, -75.13], [40.16, -75.18], [40.19, -75.12], [40.15, -75.16]]    # < 25 miles
  FAR  = [[34.05, -118.24], [47.61, -122.33], [25.76, -80.19], [41.88, -87.63]]  # >> 25 miles
  EDGE_IN  = [40.537055, -75.150116]  # ~24.5 miles out
  EDGE_OUT = [40.552983, -75.150116]  # ~25.6 miles out

  TAGS = {
    "yes"        => [{"kind" => "certifications", "label" => "Energy Star"}],
    "wrongkind"  => [{"kind" => "labels",         "label" => "Energy Star"}],
    "wronglabel" => [{"kind" => "certifications", "label" => "Fair Trade"}],
    # kind and label in DIFFERENT elements: plain AND would match, sameElement must not
    "split"      => [{"kind" => "certifications", "label" => "Fair Trade"},
                     {"kind" => "labels",         "label" => "Energy Star"}],
    "none"       => [{"kind" => "labels",         "label" => "Organic"}],
    "case"       => [{"kind" => "certifications", "label" => "energy star"}],  # attributes match uncased
    "missing"    => nil,
  }
  FEATURES = {
    "full"    => ["Bluetooth", "GPS", "Waterproof"],
    "wifi"    => ["Wifi", "GPS", "Waterproof"],
    "partial" => ["Bluetooth", "GPS"],
    "none"    => ["Solar", "Compass"],
    "case"    => ["bluetooth", "gps", "waterproof"],
    "missing" => nil,
  }
  METRICS = {
    "yes"     => [{"label" => "warranty", "value" => 36}],
    "low"     => [{"label" => "warranty", "value" => 12}],
    "wrong"   => [{"label" => "weight",   "value" => 48}],
    # neither element satisfies label AND value >= 24
    "split"   => [{"label" => "warranty", "value" => 12},
                  {"label" => "weight",   "value" => 36}],
    "none"    => [{"label" => "height",   "value" => 60}],
    "missing" => nil,
  }

  # [active, region, geo, category, tags, features, metrics]
  ITEMS = [
    [true,  "EU", "near",     1, "yes",        "full",    "yes"],
    [true,  "EU", "near",     1, "yes",        "full",    "yes"],
    [true,  "EU", "near",     1, "yes",        "wifi",    "yes"],
    [true,  "EU", "near",     2, "yes",        "partial", "low"],
    [true,  "EU", "near",     1, "split",      "none",    "none"],
    [true,  "EU", "near",     1, "wronglabel", "full",    "wrong"],
    [true,  "EU", "far",      1, "yes",        "full",    "yes"],
    [true,  "EU", "far",      1, "yes",        "wifi",    "yes"],
    [true,  "EU", "far",      2, "yes",        "none",    "split"],
    [true,  "EU", "far",      1, "wrongkind",  "partial", "low"],
    [true,  "EU", "near",     3, "none",       "full",    "yes"],
    [true,  "EU", "near",     1, "yes",        "none",    "none"],
    [true,  "EU", "far",      1, "none",       "partial", "yes"],
    [true,  "EU", "near",     2, "yes",        "wifi",    "yes"],
    [true,  "EU", "far",      3, "wronglabel", "partial", "wrong"],
    [true,  "EU", "near",     1, "yes",        "partial", "low"],
    [true,  "EU", "far",      2, "none",       "none",    "none"],
    [true,  "EU", "near",     1, "wrongkind",  "full",    "yes"],
    [true,  "EU", "far",      1, "yes",        "partial", "yes"],
    [true,  "EU", "near",     2, "yes",        "wifi",    "split"],
    [true,  "EU", "edge_in",  2, "none",       "none",    "none"],
    [true,  "EU", "edge_out", 2, "none",       "none",    "none"],
    [true,  "EU", "near",     2, "case",       "case",    "low"],
    [true,  "EU", "missing",  2, "missing",    "missing", "missing"],
    # outside the base query (inactive or non-EU): must never be counted when scoped
    [false, "EU", "near",     1, "yes",        "full",    "yes"],
    [false, "EU", "near",     1, "yes",        "full",    "yes"],
    [true,  "US", "near",     1, "yes",        "full",    "yes"],
    [true,  "JP", "far",      1, "yes",        "wifi",    "yes"],
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

  WHERE = {
    "geo"       => 'geoLocation(location, 40.182465, -75.150116, "25 miles")',
    "category"  => 'category = 1',
    "certified" => 'tags contains sameElement(kind contains "certifications", label contains "Energy Star")',
    "features"  => '(features contains "Bluetooth" or features contains "Wifi") ' +
                   'and features contains "GPS" and features contains "Waterproof"',
    "warranty"  => 'metrics contains sameElement(label contains "warranty", value >= 24)',
    "phantom"   => 'category = 99',  # matches nothing; must give 0, not an error
    # operator showcase: everything the YQL parser accepts works as a filter fragment
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

  ALL_SOURCES = ["item", "supplier"]

  def setup
    set_owner("sebasabe")
    set_description("Exact total hit counts for every intersection of named YQL filters, " +
                    "via FilterIntersectionsSearcher.")
    @docs, @records = build_corpus
    chain = SearchChain.new("default", "vespa").
      add(Searcher.new("ai.vespa.search.counting.FilterIntersectionsSearcher"))
    deploy_app(SearchApp.new.sd(selfdir + "item.sd").sd(selfdir + "supplier.sd").search_chain(chain))
    start
    feed_file = dirs.tmpdir + "docs.json"
    File.write(feed_file, JSON.pretty_generate(@docs))
    feed_and_wait_for_docs("item", ITEMS.size, :file => feed_file)
    wait_for_hitcount("query=sddocname:supplier&nocache&hits=0&streaming.selection=true", SUPPLIERS.size)
  end

  def test_full_matrix_over_base_query
    # 5 filters at 2 dimensions: 5 singles + 10 pairs
    assert_intersections(%w[geo category certified features warranty])
  end

  def test_same_element_filters
    assert_intersections(%w[certified])   # kind and label must be in the SAME element
    assert_intersections(%w[warranty])    # label and value >= 24 in the SAME element
  end

  def test_geo_filter_including_boundary_documents
    assert_intersections(%w[geo])
  end

  def test_impossible_filter_gives_zero_for_itself_and_every_pair
    buckets = assert_intersections(%w[category phantom])
    assert_equal(0, buckets["phantom"])
    assert_equal(0, buckets["category&phantom"])
  end

  def test_cells_are_sorted_by_name_singles_then_pairs_regardless_of_input_order
    keys = assert_intersections(%w[warranty geo category]).keys
    assert_equal(%w[category geo warranty category&geo category&warranty geo&warranty], keys)
  end

  def test_unscoped_base_includes_inactive_and_foreign_documents
    assert_intersections(%w[certified], :scoped => false)
  end

  def test_custom_separator
    buckets = assert_intersections(%w[geo category], :separator => "::")
    assert(buckets.key?("category::geo"))
  end

  def test_dimensions
    assert_equal(25, assert_intersections(%w[geo category certified features warranty], :dimensions => 3).size)
    assert_equal(3,  assert_intersections(%w[geo category certified], :dimensions => 1).size)
    # beyond the filter count clamps to the full intersection
    assert_equal(3,  assert_intersections(%w[geo category], :dimensions => 5).size)
  end

  def test_operator_showcase
    assert_intersections(%w[in numrange cmp boolops regex weakAnd nonEmpty userInput],
                         :extra => {"featureWord" => "Solar"})
  end

  def test_user_input_in_both_base_query_and_filter
    yql = 'select * from sources item where active = true and ({defaultIndex: "region"} userInput(@baseRegion))'
    assert_intersections(%w[userInput category], :yql => yql, :scoped => true,  # yql keeps the active/EU scope
                         :extra => {"baseRegion" => "EU", "featureWord" => "Solar"})
  end

  def test_multiple_sources
    # the fork keeps the main query's source list, so a cell counts documents of every named type
    assert_intersections(%w[category cmp in], :sources => "item, supplier")
    assert_intersections(%w[category cmp in], :sources => "*")
    assert_intersections(%w[category cmp], :sources => "supplier")
    assert_intersections(%w[category regex], :sources => "item, supplier", :scoped => false)
  end

  def test_malformed_filter_is_an_error_not_a_missing_bucket
    params = [["yql", base_yql("item")], ["hits", "0"],
              ["filterIntersections.filters", JSON.generate([{"name" => "broken", "where" => "this is not ( yql"}])]]
    assert_query_errors("/search/?" + URI.encode_www_form(params), [".*Filter 'broken': invalid YQL.*"])
  end

  def test_filter_cannot_escape_its_parenthesis_and_widen_the_base_query
    # Regression guard: a filter with unbalanced parentheses must be rejected outright. Were filters ever
    # spliced into the base query's YQL text again, this would parse as "(base and true) or true or (false)"
    # and count documents outside the base query.
    params = [["yql", base_yql("item")], ["hits", "0"],
              ["filterIntersections.filters", JSON.generate([{"name" => "escape", "where" => "true) or true or (false"}])]]
    assert_query_errors("/search/?" + URI.encode_www_form(params), [".*Filter 'escape': invalid YQL.*"])
  end

  def test_nearest_neighbor_filter_keeps_the_rank_profile_inputs
    # cells keep the main query's rank profile, so the query tensor declared there is typed on the content nodes
    assert_intersections(%w[nn category], :extra => {"input.query(q)" => "[1.0, 0.0]"})
  end

  def test_cell_limit_is_enforced_and_overridable
    all_filters = WHERE.keys
    n = all_filters.size
    filters_param = ["filterIntersections.filters",
                     JSON.generate(all_filters.map { |f| {"name" => f, "where" => WHERE[f]} })]
    common = [["yql", base_yql("item")], ["hits", "0"], ["timeout", "20s"],
              ["featureWord", "Solar"], ["input.query(q)", "[1.0, 0.0]"], filters_param]

    # all filters at 4 dimensions is far above the default limit of 1000 cells
    four = cells(n, 4)
    assert(four > 1000, "fixture must exceed the default cell limit, got #{four}")
    assert_query_errors("/search/?" + URI.encode_www_form(common + [["filterIntersections.dimensions", "4"]]),
                        [".*#{n} filters at 4 dimensions give #{four} cells, more than the default limit of 1000.*"])

    # the limit is inclusive: one below the exact cell count is rejected, the exact count is accepted
    three = cells(n, 3)
    three_dims = common + [["filterIntersections.dimensions", "3"]]
    assert_query_errors("/search/?" + URI.encode_www_form(three_dims + [["filterIntersections.maxCells", (three - 1).to_s]]),
                        [".*give #{three} cells, more than the limit of #{three - 1} set by filterIntersections.maxCells.*"])
    result = search("/search/?" + URI.encode_www_form(three_dims + [["filterIntersections.maxCells", three.to_s]]))
    assert_nil(result.json["root"]["errors"], "Unexpected errors: #{result.json['root']['errors']}")
    assert_equal(three, result.json["root"]["fields"]["filterIntersections"]["buckets"].size)
  end

  def test_no_filters_parameter_is_a_no_op
    result = search("/search/?" + URI.encode_www_form([["yql", base_yql("item")], ["hits", "0"]]))
    assert_nil(result.json["root"]["errors"])
    assert_nil(result.json["root"]["fields"] && result.json["root"]["fields"]["filterIntersections"])
  end

  # ---- helpers --------------------------------------------------------------

  # Runs one intersections query, asserts every bucket against ground truth and
  # returns the buckets as key => totalCount in emission order.
  # :scoped selects the ground-truth pool: true means "active and EU" (base_yql), false means everything (all_yql).
  # A custom :yql must state which of the two it is equivalent to by passing :scoped explicitly.
  def assert_intersections(filter_ids, scoped: nil, separator: nil, dimensions: nil,
                           sources: "item", yql: nil, extra: {})
    raise ArgumentError, "pass :scoped explicitly when overriding :yql" if yql && scoped.nil?
    scoped = true if scoped.nil?
    params = [["yql", yql || (scoped ? base_yql(sources) : all_yql(sources))],
              ["hits", "0"],
              ["filterIntersections.filters",
               JSON.generate(filter_ids.map { |f| {"name" => f, "where" => WHERE[f]} })]]
    params << ["filterIntersections.separator", separator] if separator
    params << ["filterIntersections.dimensions", dimensions.to_s] if dimensions
    extra.each { |k, v| params << [k, v] }

    result = search("/search/?" + URI.encode_www_form(params))
    root = result.json["root"]
    assert_nil(root["errors"], "Unexpected errors: #{root['errors']}")
    actual = root["fields"]["filterIntersections"]["buckets"]
    expected = expected_buckets(filter_ids, scoped, separator || "&", dimensions || 2, sources)
    assert_equal(expected, actual, "Buckets for #{filter_ids} (sources=#{sources}, scoped=#{scoped})")
    actual.map { |b| [b["key"], b["totalCount"]] }.to_h
  end

  def base_yql(sources)
    "select * from sources #{sources} where active = true and region contains \"EU\""
  end

  def all_yql(sources)
    "select * from sources #{sources} where true"
  end

  # Mirrors the searcher: filters sorted case-insensitively by name, then all
  # combinations of size 1..dimensions, smaller sizes first; every cell emitted.
  def expected_buckets(filter_ids, scoped, separator, dimensions, sources)
    wanted = sources.strip == "*" ? ALL_SOURCES : sources.split(",").map(&:strip)
    pool = @records.select { |r| wanted.include?(r["source"]) && (r["base"] || !scoped) }
    ids = filter_ids.sort_by(&:downcase)
    buckets = []
    (1..[dimensions, ids.size].min).each do |size|
      ids.combination(size).each do |names|
        count = pool.count { |r| names.all? { |f| r.fetch(f, false) } }
        buckets << {"key" => names.join(separator), "names" => names, "totalCount" => count}
      end
    end
    buckets
  end

  # Number of cells for n filters at d dimensions: all non-empty subsets of at most d filters.
  def cells(n, d)
    (1..[d, n].min).sum { |k| (1..k).reduce(1) { |c, i| c * (n - k + i) / i } }
  end

  def miles(a, b)
    r = 3958.8
    la1, lo1, la2, lo2 = [a[0], a[1], b[0], b[1]].map { |d| d * Math::PI / 180 }
    h = Math.sin((la2 - la1) / 2)**2 + Math.cos(la1) * Math.cos(la2) * Math.sin((lo2 - lo1) / 2)**2
    2 * r * Math.asin(Math.sqrt(h))
  end

  # Builds the feed and, per document, a record of which filters it satisfies.
  def build_corpus
    docs, records = [], []
    ITEMS.each_with_index do |(active, region, geo, category, tag, feat, met), i|
      id = i + 1
      coord = case geo
              when "missing"  then nil
              when "edge_in"  then EDGE_IN
              when "edge_out" then EDGE_OUT
              when "near"     then NEAR[id % 4]
              else                 FAR[id % 4]
              end
      raise "bad geo fixture #{coord}" if coord && ((miles(CENTER, coord) < 25) != %w[near edge_in].include?(geo))
      tags, features, metrics = TAGS[tag], FEATURES[feat], METRICS[met]
      lower = (features || []).map(&:downcase)
      fields = {"active" => active, "region" => region, "category" => category}
      fields["location"] = {"lat" => coord[0], "lng" => coord[1]} if coord
      fields["tags"] = tags if tags
      fields["features"] = features if features
      fields["metrics"] = metrics if metrics
      fields["embedding"] = {"values" => (id.even? ? [1.0, 0.0] : [0.0, 1.0])} unless geo == "missing"
      docs << {"put" => "id:item:item::#{id}", "fields" => fields}
      records << {
        "source"    => "item",
        "base"      => active && region == "EU",
        "geo"       => %w[near edge_in].include?(geo),
        "category"  => category == 1,
        "certified" => (tags || []).any? { |t| t["kind"].downcase == "certifications" && t["label"].downcase == "energy star" },
        "features"  => !features.nil? && (lower.include?("bluetooth") || lower.include?("wifi")) &&
                       lower.include?("gps") && lower.include?("waterproof"),
        "warranty"  => (metrics || []).any? { |m| m["label"].downcase == "warranty" && m["value"] >= 24 },
        "phantom"   => false,
        "in"        => [1, 3].include?(category),
        "numrange"  => (2..3).cover?(category),
        "cmp"       => category >= 2,
        "boolops"   => category != 1 && (lower.include?("solar") || lower.include?("compass")),
        "regex"     => region == "EU",
        "weakAnd"   => lower.include?("solar") || lower.include?("compass"),
        "nonEmpty"  => lower.include?("solar"),
        "userInput" => lower.include?("solar"),
        "nn"        => id.even? && geo != "missing",
      }
    end
    SUPPLIERS.each_with_index do |(active, region, category), i|
      id = i + 1
      docs << {"put" => "id:supplier:supplier::#{id}",
               "fields" => {"active" => active, "region" => region, "category" => category}}
      # supplier has no geo/tags/features/metrics fields: those filters can never match it
      records << {
        "source"   => "supplier",
        "base"     => active && region == "EU",
        "category" => category == 1,
        "in"       => [1, 3].include?(category),
        "numrange" => (2..3).cover?(category),
        "cmp"      => category >= 2,
        "regex"    => region == "EU",
        "phantom"  => false,
      }
    end
    [docs, records]
  end

  def teardown
    stop
  end

end
