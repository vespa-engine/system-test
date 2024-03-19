# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'


class GlobalFeatures < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    @id_field = "documentid"
  end

  #---------- now ----------#
  def test_now
    set_description("Test the now feature")
    deploy_app(SearchApp.new.sd(selfdir + "now.sd"))
    start
    feed_and_wait_for_docs("now", 1, :file => selfdir + "now.json")
    run_now_test(30)
  end

  def run_now_test(epsilon = 4.0)
    assert_now(60,    60)
    assert_now(86460, 86460)

    5.times do
      assert_actual_now(epsilon)
      sleep 1
    end
  end

  def assert_now(out, now)
    query = "query=a&nocache&rankproperty.vespa.now=#{now}"
    search(query)
    exp = {"now" => out}
    assert_features(exp, search(query).hit[0].field['summaryfeatures'])
  end

  def assert_actual_now(epsilon)
    query = "query=a&nocache"
    search(query)
    timebefore = Time.now.to_i
    now = Time.now.to_i
    exp = {"now" => now}
    got = search(query).hit[0].field['summaryfeatures']
    timeafter = Time.now.to_i
    assert_features(exp, got, epsilon + timeafter - timebefore)
  end


  #---------- age and freshness ----------#
  def test_age_and_freshness
    set_description("Test the age and the freshness feature")
    deploy_app(SearchApp.new.sd(selfdir + "age.sd"))
    start
    feed_and_wait_for_docs("age", 1, :file => selfdir + "age.json")
    run_age_and_freshness_test
  end

  def run_age_and_freshness_test
    assert_age(0,  60)
    assert_age(60, 86460)

    5.times do
      assert_age(86400) # age of document = 86400 seconds
      sleep 1
    end

    assert_freshness(1,   0)
    assert_freshness(0.5, 60)
    assert_freshness(0,   120)
  end

  def assert_age(age, now = nil, epsilon = 6.0)
    query = "query=a:86400&nocache"
    search(query)
    timebefore = Time.now.to_i
    exp = {"age(a)" => age}
    if now != nil
      query = query + "&rankproperty.vespa.now=#{now}"
    else
      exp = {"age(a)" => Time.now.to_i - age}
    end
    got = search(query).hit[0].field['summaryfeatures']
    timeafter = Time.now.to_i
    assert_features(exp, got, epsilon + timeafter - timebefore)
  end

  def assert_freshness(freshness, age)
    query = "query=a:86400&nocache&rankproperty.vespa.now=#{86400 + age}"
    exp = {"freshness(a)" => freshness}
    assert_features(exp, search(query).hit[0].field['summaryfeatures'], 1e-4)
  end


  #---------- random ----------#
  def test_random
    set_description("Test the random feature")
    deploy_app(SearchApp.new.sd(selfdir + "random.sd"))
    start
    feed_and_wait_for_docs("random", 2, :file => selfdir + "random.json")
    if is_streaming
      @id_field = "uri"
    end
    run_random_test
  end

  def run_random_test
    sf = get_summary_features("query=a&nocache")
    puts "sf[0]: #{sf[0].to_a.join(",")}"
    puts "sf[1]: #{sf[1].to_a.join(",")}"
    assert_random(sf[0], sf[1])

    sf = get_summary_features("query=a&nocache&ranking=seed")
    puts "sf[0]: #{sf[0].to_a.join(",")}"
    puts "sf[1]: #{sf[1].to_a.join(",")}"
    assert_random(sf[0], sf[1])
    assert_different_random(sf[0])
    assert_different_random(sf[1])

    sfa1 = get_summary_features("query=a&nocache")
    sleep 2
    sfa2 = get_summary_features("query=a&nocache")
    sfb =  get_summary_features("query=b&nocache")
    puts "sfb[0]: #{sfb[0].to_a.join(",")}"
    puts "sfb[1]: #{sfb[1].to_a.join(",")}"
    # same query -> same random value
    assert_equal(sfa1[0].fetch("random.match").to_f, sfa2[0].fetch("random.match").to_f)
    assert_equal(sfa1[1].fetch("random.match").to_f, sfa2[1].fetch("random.match").to_f)
    # different query -> different random value
    assert_same_random_match(sfa1[0], sfb[0])
    assert_same_random_match(sfa1[1], sfb[1])
  end

  def assert_random(sf0, sf1)
    sf0.delete("vespa.summaryFeatures.cached")
    sf1.delete("vespa.summaryFeatures.cached")
    assert_equal(4, sf0.size)
    assert_equal(4, sf1.size)
    assert(sf0.has_key?("random"))
    assert(sf0.has_key?("random(1)"))
    assert(sf0.has_key?("random(2)"))
    assert(sf0.has_key?("random.match"))
    sf0.each do |name,rnd|
      a = rnd.to_f
      b = sf1.fetch(name).to_f
      assert(a != b, "Expected #{a} != #{b}")
      assert((a >= 0.0 and a < 1.0), "Expected #{a} in the interval [0,1>")
      assert((b >= 0.0 and b < 1.0), "Expected #{b} in the interval [0,1>")
    end
  end

  def assert_different_random(sf)
    sf.delete("vespa.summaryFeatures.cached")
    assert_equal(4, sf.size)
    a = sf.fetch("random").to_f
    b = sf.fetch("random(1)").to_f
    c = sf.fetch("random(2)").to_f
    assert((a != b and b != c), "Expected #{a} != #{b} != #{c}")
  end

  def assert_same_random_match(sf0, sf1)
    rm0 = sf0.fetch("random.match").to_f
    rm1 = sf1.fetch("random.match").to_f
    assert(rm0 == rm1, "Expected #{rm0} == #{rm1}")
  end

  def get_summary_features(query)
    result = search(query)
    result.sort_results_by(@id_field)
    retval = []
    result.hit.each do |hit|
      retval.push(hit.field['summaryfeatures'])
    end
    return retval
  end


  def teardown
    stop
  end

end
