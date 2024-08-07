# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ConstantFeatureTest < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
    @barbie_id = 0
    @heman_id  = 1
    @tv_id     = 2
  end

  def use_sdfile(sdfile)
    dest_sd = "#{dirs.tmpdir}test.sd"
    command = "cp #{selfdir}#{sdfile} #{dest_sd}"
    success = system(command)
    puts "use_sdfile(#{sdfile}): command='#{command}', success='#{success}'"
    assert(success)
    dest_sd
  end

  def get_app(sdfile)
    SearchApp.new.sd(use_sdfile(sdfile)).
      search_dir(selfdir + "search").
      search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.TensorInQuerySearcher")))
  end

  def test_constant_feature
    set_description("Test constants in ranking expression")
    set_expected_logged(/invalid json.*badmodel.txt/)
    add_bundle(selfdir + "../tensor_eval/TensorInQuerySearcher.java")
    deploy_app(get_app("test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    check_ranking(201.0, 161.0, 82.0, 102.0)
    redeploy(get_app("test2.sd"))
    if is_streaming
      puts "Wait for new config to be applied for SearchEnvironment::Env"
      wait_for_relevancy("query=sddocname:test&test.age=kid&test.sex=f", 223.0, 0, 60)
    end
    check_ranking(223.0, 169.0, 92.0, 106.0)
    restart_proton("test", 3, "search")
    check_ranking(223.0, 169.0, 92.0, 106.0)
  end

  def check_one_ranking(querytensor, exp_id, exp_rank)
    result = search("query=sddocname:test&#{querytensor}&nocache")
    assert_equal(3, result.hit.size)
    assert_equal(exp_id, result.hit[0].field["id"].to_i)
    assert_equal(exp_rank, result.hit[0].field["relevancy"].to_f)
  end

  def check_ranking(barbie_rank, heman_rank, female_tv_rank, male_tv_rank)
    check_one_ranking("test.age=kid&test.sex=f", @barbie_id, barbie_rank)
    check_one_ranking("test.age=kid&test.sex=m", @heman_id, heman_rank)
    check_one_ranking("test.age=adult&test.sex=f", @tv_id, female_tv_rank)
    check_one_ranking("test.age=adult&test.sex=m", @tv_id, male_tv_rank)
  end

  def teardown
    stop
  end

end
