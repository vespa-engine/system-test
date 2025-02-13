require 'search_test'

class Generate < SearchTest
  def setup
    super
    set_owner('glebashnik')
    set_description('Test text generation when feeding.')
  end

  def test_generate_text_when_feeding
    add_bundle_dir(selfdir + "app", "generate_text_when_feeding")
    deploy(selfdir + "app/src/main/application")
    start
  
    feed_and_wait_for_docs('passage', 1, :file => selfdir + "data/feed.jsonl")
    assert_hitcount('query=hello&ranking=mock_gen', 1) # Custom text generator.
    assert_hitcount('query=hello&ranking=mock_lm_gen', 1) # Generator with custom LM.
    assert_hitcount('query=hello&ranking=local_llm_gen', 1) # Generator with local LLM.
    
    result = search("query=hello&ranking=mock_gen")
    assert_equal("define hello define hello", result.hit[0].field["mock_gen"])
    assert_equal("define hello define hello", result.hit[0].field["mock_lm_gen"])
    assert(!result.hit[0].field["local_llm_gen"].empty?) # LLM output changes every time
  end

  def teardown
    stop
  end
end
