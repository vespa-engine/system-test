require 'search_test'

class Generate < SearchTest
  def setup
    super
    set_owner('glebashnik')
    set_description('Test generation of documents fields with custom generators and a local LLM.')
  end

  def test_generate_text_when_feeding
    add_bundle_dir(selfdir + "app", "generate_field")
    deploy(selfdir + "app/src/main/application")
    start
  
    feed_and_wait_for_docs('passage', 1, :file => selfdir + "data/feed.jsonl")
    assert_hitcount('query=friend&ranking=mock_gen', 1) # Custom text generator.
    assert_hitcount('query=friend&ranking=mock_lm_gen', 1) # Generator with custom LM.
    assert_hitcount('query=friend&ranking=local_llm_gen', 1) # Generator with local LLM.
    
    result = search("query=friend&ranking=mock_gen")
    assert_equal("Explain: Silence is a true friend who never betrays. Explain: Silence is a true friend who never betrays.", result.hit[0].field["mock_gen"])
    assert_equal("Explain: Silence is a true friend who never betrays. Explain: Silence is a true friend who never betrays.", result.hit[0].field["mock_lm_gen"])
    
    local_llm_gen_value = result.hit[0].field["local_llm_gen"].downcase
    assert(local_llm_gen_value.include?("silence"),
           "Field `local_llm_gen` does not contain the expected word `silence`, has value: #{local_llm_gen_value}")
  end

  def teardown
    stop
  end
end
