# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class Bm25FeatureTest < SearchTest

  def setup
    set_owner("geirst")
  end

  def test_bm25_feature
    set_description("Test basic functionality of the bm25 rank feature")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start

    # Note: Average field length for these documents = 4 ((7 + 3 + 2) / 3).
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    assert_bm25_scores
    
    vespa.search["search"].first.trigger_flush
    assert_bm25_scores

    restart_proton("test", 3)
    assert_bm25_scores
  end

  def test_enable_bm25_feature
    set_description("Test regeneration of interleaved features when enabling bm25 feature")
    @test_dir = selfdir + "regen/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    # Average field length for content = 4 ((7 + 3 + 2) / 3).
    # Average field length for contenta = 8 ((14 + 6 + 4) / 3).
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "docs.json")
    assert_no_bm25_scores
    assert_no_bm25_array_scores
    redeploy("test.1.sd")                               
    assert_no_bm25_scores
    assert_no_bm25_array_scores
    feed_and_wait_for_docs("test", 4, :file => @test_dir + "docs2.json")
    # Trigger dump from memory to disk
    vespa.search["search"].first.trigger_flush
    # Trigger fusion
    vespa.search["search"].first.trigger_flush
    assert_bm25_scores(4, 4)
    assert_bm25_array_scores(4, 8)
  end

  def assert_bm25_scores(total_doc_count = 3, avg_field_length = 4)
    assert_scores_for_query("content:a", [score(2, 3, idf(3, total_doc_count), avg_field_length),
                                          score(3, 7, idf(3, total_doc_count), avg_field_length),
                                          score(1, 2, idf(3, total_doc_count), avg_field_length)])

    assert_scores_for_query("content:b", [score(1, 3, idf(2, total_doc_count), avg_field_length),
                                          score(1, 7, idf(2, total_doc_count), avg_field_length)])

    assert_scores_for_query("content:a+content:d", [score(1, 2, idf(3, total_doc_count), avg_field_length) + score(1, 2, idf(2, total_doc_count), avg_field_length),
                                                    score(3, 7, idf(3, total_doc_count), avg_field_length) + score(1, 7, idf(2, total_doc_count), avg_field_length)])
  end

  def assert_bm25_array_scores(total_doc_count, avg_field_length)
    assert_scores_for_query("contenta:a", [score(2, 6, idf(3, total_doc_count), avg_field_length),
                                           score(3, 14, idf(3, total_doc_count), avg_field_length),
                                           score(1, 4, idf(3, total_doc_count), avg_field_length)])

    assert_scores_for_query("contenta:b", [score(1, 6, idf(2, total_doc_count), avg_field_length),
                                           score(1, 14, idf(2, total_doc_count), avg_field_length)])

    assert_scores_for_query("content:a+content:d", [score(1, 4, idf(3, total_doc_count), avg_field_length) + score(1, 4, idf(2, total_doc_count), avg_field_length),
                                                    score(3, 14, idf(3, total_doc_count), avg_field_length) + score(1, 14, idf(2, total_doc_count), avg_field_length)])
  end

  def assert_no_bm25_scores
    assert_scores_for_query("content:a", [0.0, 0.0, 0.0])

    assert_scores_for_query("content:b", [0.0, 0.0])

    assert_scores_for_query("content:a+content:d", [0.0, 0.0])
  end

  def assert_no_bm25_array_scores
    assert_scores_for_query("contenta:a", [0.0, 0.0, 0.0])

    assert_scores_for_query("contenta:b", [0.0, 0.0])

    assert_scores_for_query("content:a+content:d", [0.0, 0.0])
  end

  def idf(matching_doc_count, total_doc_count = 3)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    Math.log(1 + ((total_doc_count - matching_doc_count + 0.5) / (matching_doc_count + 0.5)))
  end

  def score(num_occs, field_length, inverse_doc_freq, avg_field_length = 4)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    inverse_doc_freq * (num_occs * 2.2) / (num_occs + (1.2 * (0.25 + 0.75 * field_length / avg_field_length)))
  end

  def assert_scores_for_query(query, exp_scores)
    result = search(query)
    assert_hitcount(result, exp_scores.length)
    for i in 0...exp_scores.length do
      assert_relevancy(result, exp_scores[i], i)
    end
  end

  def use_sdfile(sdfile)
    dest_sd = "#{dirs.tmpdir}test.sd"
    command = "cp #{@test_dir}#{sdfile} #{dest_sd}"
    success = system(command)
    puts "use_sdfile(#{sdfile}): command='#{command}', success='#{success}'"
    assert(success)
    dest_sd
  end

  def postdeploy_wait(deploy_output)
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))
    wait_for_reconfig(600)
  end

  def redeploy(sdfile)
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile(sdfile)))
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    return deploy_output
  end

  def wait_for_content_cluster_config_generation(deploy_output)
    gen = get_generation(deploy_output).to_i
    vespa.storage["search"].wait_until_content_nodes_have_config_generation(gen)
  end

  def teardown
    stop
  end

end
