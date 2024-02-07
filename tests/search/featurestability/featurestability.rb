# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'json'

class FeatureStability < IndexedOnlySearchTest

  SAVE_RESULT = false

  def setup
    set_owner("yngve")
    set_description("Ensure that dump features do not change without being " +
                    "noticed. If this test fails, just make sure that the " +
                    "change was intentional, and update the expected value.")
  end

  def test_feature_stability
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start
    feed_and_wait_for_docs("simple", 1, :file => "#{selfdir}/feed.xml")
    run_query("my_set:1",          "#{selfdir}/result1.txt")
    run_query("my_set:1.2",        "#{selfdir}/result2.txt")
    run_query("my_set:1+my_set:2", "#{selfdir}/result3.txt")
    run_query("my_set:a",          "#{selfdir}/result4.txt")
    run_query("my_set:a+my_set:b", "#{selfdir}/result5.txt")
  end

  def run_query(query, file)
    query = "query=#{query}&" +
      "ranking.listFeatures=true"
    if (SAVE_RESULT)
      save_features(search(query), file)
    else
      exp = load_features(file)
      act = parse_features(search(query))
      assert_equal(exp.size, act.size, "Expected #{exp.size} features, got #{act.size}")
      assert_features(exp, act)
    end
  end

  def parse_features(result)
    return result.hit[0].field["rankfeatures"]
  end

  def save_features(result, file_name)
    fs = parse_features(result)
    file = File.open(file_name, "w")
    fs = fs.sort {|x,y| x[0] <=> y[0]}
    fs.each do |name, score|
      file.write(name.to_s + "#" + score.to_s + "\n")
    end
    file.close
  end

  def load_features(file_name)
    fs = []
    File.open(file_name, "r").each do |line|
      fs.push(line.split("#"))
    end
    return fs
  end

  def teardown
    stop
  end

end
