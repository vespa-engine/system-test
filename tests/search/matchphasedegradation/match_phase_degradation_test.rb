# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'
require 'app_generator/container_app'
require 'pp'

class MatchPhaseDegradationTest < IndexedOnlySearchTest

  def setup
    set_owner("arnej")
    set_description("test graceful degradation in match-phase")
  end

  def timeout_seconds
    3600
  end

  def min(a, b)
    if (a < b)
      return a
    end
    return b
  end

  def get_value_by_name(metrics, dimensions, name, mtype)
    metric_name = "content.proton.documentdb.#{name}"
    metric = metrics.get(metric_name, dimensions)
    metric != nil ? metric[mtype] : -1
  end

  def get_dimensions(doc_type, rank_profile = nil)
    (rank_profile != nil) ? {"documenttype" => doc_type, "rankProfile" => rank_profile} : {"documenttype" => doc_type}
  end

  def get_num_queries(metrics, rank_profile)
    return get_value_by_name(metrics, get_dimensions("mpd", rank_profile), "matching.rank_profile.queries", "count").to_i
  end

  def get_num_limited(metrics, rank_profile)
    return get_value_by_name(metrics, get_dimensions("mpd", rank_profile), "matching.rank_profile.limited_queries", "count").to_i
  end

  def get_num_reranked(metrics)
    return get_value_by_name(metrics, get_dimensions("mpd"), "matching.docs_reranked", "count").to_i
  end
  def get_num_ranked(metrics)
    return get_value_by_name(metrics, get_dimensions("mpd"), "matching.docs_ranked", "count").to_i
  end
  def get_num_matched(metrics)
    return get_value_by_name(metrics, get_dimensions("mpd"), "matching.docs_matched", "count").to_i
  end
  def get_num_queries2(metrics)
    return get_value_by_name(metrics, get_dimensions("mpd"), "matching.queries", "count").to_i
  end

  def assert_count_equals(query, count)
    query_url = "/search/?query=sddocname:mpd&nocache&hits=0&format=json&#{query}"
    tree = search(query_url).json
    assert_equal(count, tree["root"]["children"][0]["fields"]["count()"])
  end

  def assert_rank_of_2_best(query, first, second)
    query_url = "/search/?query=sddocname:mpd&nocache&hits=0&format=json&#{query}"
    tree = search(query_url).json
    assert_equal(first, tree["root"]["children"][0]["children"][0]["children"][0]["relevance"])
    assert_equal(second, tree["root"]["children"][0]["children"][0]["children"][1]["relevance"])
  end

  def print_query_stats(metrics)
    numr = get_num_ranked(metrics)
    numre = get_num_reranked(metrics)
    numm = get_num_matched(metrics)
    numq = get_num_queries2(metrics)
    puts("num queries:#{numq} matched: #{numm} ranked: #{numr} reranked: #{numre}")
  end

  def verify_rankcount(metrics1, metrics2, queries, rank_count, rerank_count)
    diffq  = get_num_queries2(metrics2) - get_num_queries2(metrics1)
    diffr  = get_num_ranked(metrics2) - get_num_ranked(metrics1)
    diffre = get_num_reranked(metrics2) - get_num_reranked(metrics1)
    assert_equal(queries, diffq)
    assert_equal(rank_count, diffr/diffq)
    assert_equal(rerank_count, diffre/diffq)
  end

  def test_gendata_degradation
    @valgrind = false
    deploy_app(SearchApp.new.threads_per_search(1).sd(selfdir+"mpd.sd"))
    start
    node = vespa.adminserver
    # node.logctl("searchnode:proton.matching.match_phase_limiter", "debug=on")
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out && #{tmp_bin_dir}/a.out 100000 1000 | vespa-feed-perf")
    puts "compile and feed output: #{output}"

    wait_for_hitcount("sddocname:mpd", 100000, 30)

    snode = vespa.search["search"].searchnode[0]

    metrics = snode.get_total_metrics
    for rp in [ "default", "inverse", "retainall", "retainkilo", "retaintenkilo", "inversekilo" ]
      puts("Metrics for #{rp} rank profile:")
      numq = get_num_queries(metrics, rp)
      numl = get_num_limited(metrics, rp)
      numr = get_num_reranked(metrics)
      puts("num queries: #{numq} num limited: #{numl} num reranked:#{numr}")
    end

    #     save_result("query=title:foo&hits=1", selfdir+"bigresult.foo.xml")
    assert_xml_result_with_timeout(2.0, "query=title:foo&hits=1", selfdir+"bigresult.foo.xml")

    #     save_result("query=title:bar&hits=1", selfdir+"bigresult.bar.xml")
    assert_xml_result_with_timeout(2.0, "query=title:bar&hits=1", selfdir+"bigresult.bar.xml")

    assert_count_equals("ranking=undiverse&select=all(group(cat)output(count())each(output(count())))", 2)
    assert_count_equals("ranking=diverse&select=all(group(cat)output(count())each(output(count())))", 12)
    metrics1 = snode.get_total_metrics
    print_query_stats(metrics1)
    assert_count_equals("ranking=secondphase&select=all(group(cat)output(count())each(output(count())))", 100)
    metrics2 = snode.get_total_metrics
    print_query_stats(metrics2)
    verify_rankcount(metrics1, metrics2, 1, 100000, 100)

    assert_count_equals("ranking=secondphase&ranking.properties.vespa.matchphase.diversity.attribute=cat&ranking.properties.vespa.matchphase.diversity.mingroups=10&ranking.properties.vespa.matchphase.diversity.cutoffstrategy=strict&select=all(group(cat)output(count())each(output(count())))", 100)
    metrics3 = snode.get_total_metrics
    print_query_stats(metrics3)
    verify_rankcount(metrics2, metrics3, 1, 100000, 100)

    assert_rank_of_2_best("ranking=secondphase&select=all(group(cat)output(count())each(output(count())))", 9999900, 98999)
    assert_rank_of_2_best("ranking=secondphase&ranking.properties.vespa.matchphase.diversity.attribute=cat&ranking.properties.vespa.matchphase.diversity.mingroups=10&ranking.properties.vespa.matchphase.diversity.cutoffstrategy=strict&select=all(group(cat)output(count())each(output(count())))", 9999900, 9899900)
    assert_rank_of_2_best("ranking=diverse_secondphase&select=all(group(cat)output(count())each(output(count())))", 9999900, 9899900)

    i = 1
    while i <= 1000
      q="/search/?query=body:#{i}&hits=10&summary=small"
      puts "Check: #{i}/1000 url: #{q}"
      result_norm_dec = search(q + "&ranking=default")
      result_keep_1k  = search(q + "&ranking=retainkilo")
      result_keep_10k = search(q + "&ranking=retaintenkilo")
      result_keep_all = search(q + "&ranking=retainall")
      result_norm_asc = search(q + "&ranking=inverse")
      result_keep_inv = search(q + "&ranking=inversekilo")
      result_sort_asc = search(q + "&sorting=%2border")
      result_sort_dec = search(q + "&sorting=-order")

      # puts "result r1k: #{result_keep_1k.xmldata}"

      hits_norm_dec = result_norm_dec.hitcount
      hits_keep_1k  = result_keep_1k.hitcount
      hits_keep_10k = result_keep_10k.hitcount
      hits_keep_all = result_keep_all.hitcount
      hits_norm_asc = result_norm_asc.hitcount
      hits_keep_inv = result_keep_inv.hitcount
      hits_sort_asc = result_sort_asc.hitcount
      hits_sort_dec = result_sort_dec.hitcount

      assert(hits_norm_dec == i * 100, "expected #{i*100} hits from normal decreasing order, got #{hits_norm_dec}")
      assert(hits_keep_all == i * 100, "expected #{i*100} hits from normal decreasing order, got #{hits_keep_all}")
      assert(hits_keep_1k  <= i * 100, "expected <= #{i*100} hits from degraded keep 1k, got #{hits_keep_1k}")
      assert(hits_keep_10k <= i * 100, "expected <= #{i*100} hits from degrated keep 10k, got #{hits_keep_10k}")
      assert(hits_sort_asc <= i * 100, "expected <= #{i*100} hits from degrated sort ascending(10k), got #{hits_sort_asc}")
      assert(hits_sort_dec <= i * 100, "expected <= #{i*100} hits from degrated sort descending(10k), got #{hits_sort_dec}")
      assert(hits_norm_asc == i * 100, "expected #{i*100} hits from normal decreasing order, got #{hits_norm_asc}")
      assert(hits_keep_inv <= i * 100, "expected <= #{i*100} hits from degraded inv 1k, got #{hits_keep_inv}")
      lowlim = min(900, i*90)
      assert(hits_keep_1k  >= lowlim, "expected >= #{lowlim} hits from degraded keep 1k, got #{hits_keep_1k}")
      assert(hits_keep_1k  <= 1500, "expected <= 1500 hits from degraded keep 1k, got #{hits_keep_1k}")
      assert(hits_keep_inv >= lowlim, "expected >= #{lowlim} hits from degraded inv 1k, got #{hits_keep_inv}")
      assert(hits_keep_inv <= 1500, "expected <= 1500 hits from degraded inv 1k, got #{hits_keep_inv}")
      lowlim = min(9500, i*95)
      assert(hits_keep_10k >= lowlim, "expected >= #{lowlim} hits from degrated keep 10k, got #{hits_keep_10k}")
      assert(hits_keep_10k <= 15000, "expected <= 15000 hits from degrated keep 10k, got #{hits_keep_10k}")
      assert(hits_sort_asc >= 10, "expected >= 10 hits from degraded sort ascending(10k), got #{hits_sort_asc}")
      assert(hits_sort_asc <= 15000, "expected <= 15000 hits from degrated sort ascending(10k), got #{hits_sort_asc}")
      assert(hits_sort_dec >= 10, "expected >= 10 hits from degraded sort descending(10k), got #{hits_sort_dec}")
      assert(hits_sort_dec <= 15000, "expected <= 15000 hits from degrated sort descending(10k), got #{hits_sort_dec}")

      if (hits_keep_1k < hits_norm_dec)
        for j in 0...result_keep_1k.hit.size
          gotten = result_keep_1k.hit[j].field["relevancy"].to_f
          wanted = result_norm_dec.hit[j].field["relevancy"].to_f
          assert(gotten == wanted, "failed check, hit #{j} got #{gotten} wanted #{wanted}")
        end
      end
      if (hits_keep_10k < hits_norm_dec)
        for j in 0...result_keep_10k.hit.size
          gotten = result_keep_10k.hit[j].field["relevancy"].to_f
          wanted = result_norm_dec.hit[j].field["relevancy"].to_f
          assert(gotten == wanted, "failed check, hit #{j} got #{gotten} wanted #{wanted}")
        end
      end
      if (hits_sort_asc < hits_norm_asc)
        for j in 0...result_sort_asc.hit.size
          gotten = result_sort_asc.hit[j].field["order"].to_f
          wanted = result_norm_asc.hit[j].field["order"].to_f
          assert(gotten == wanted, "failed check, hit #{j} got #{gotten} wanted #{wanted}")
        end
      end
      if (hits_sort_dec < hits_norm_dec)
        for j in 0...result_sort_dec.hit.size
          gotten = result_sort_dec.hit[j].field["order"].to_f
          wanted = result_norm_dec.hit[j].field["order"].to_f
          assert(gotten == wanted, "failed check, hit #{j} got #{gotten} wanted #{wanted}")
        end
      end
      if (i >= 400)
        i += 40
      elsif (i >= 200)
        i += 20
      elsif (i >= 150)
        i += 5
      else
        i += 1
      end

    end

    queries = {}
    limited = {}
    reranked = {}

    metrics = snode.get_total_metrics
    for rp in [ "default", "inverse", "retainall", "retainkilo", "retaintenkilo", "inversekilo", "diverse", "diverse_secondphase_querytime" ]
      puts("Metrics for #{rp} rank profile:")
      numq = get_num_queries(metrics, rp)
      numl = get_num_limited(metrics, rp)
      numr = get_num_reranked(metrics)
      puts("num queries: #{numq} num limited: #{numl} num reranked: #{numr}")
      queries[rp] = numq
      limited[rp] = numl
      reranked[rp] = numr
    end
    assert(queries["inverse"] == queries["retainall"])
    assert(queries["inverse"] == queries["retainkilo"])
    assert(queries["inverse"] == queries["retaintenkilo"])
    assert(queries["inverse"] == queries["inversekilo"])

    assert(limited["default"] > 8)
    assert(limited["inverse"] == 0)
    assert(limited["retainall"] == 0)
    assert(limited["retaintenkilo"] > 4)
    assert(limited["retainkilo"] > 40)
  end

  def teardown
    stop
  end


end
