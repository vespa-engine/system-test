require 'search_test'

class Generate < SearchTest
  def setup
    super
    set_owner("glebashnik")
    set_description("Test generation of document fields using OpenAI.")
  end

  def timeout_seconds
    600
  end
  
  def disable_generate_field_openai
  # def test_generate_field_openai
    add_bundle_dir(selfdir + "app", "generate_field_openai")
    deploy(selfdir + "app/src/main/application")
    start
  
    feed_and_wait_for_docs('passage', 1, :file => selfdir + "data/feed.jsonl")
    
    result = search("query=friend")
    assert_equal(1, result.hit.size)
    
    hit = result.hit[0]
 
    explanation = hit.field["explanation"]
    assert(!explanation.nil? && explanation.length > 0)

    keywords = hit.field["keywords"]
    # keywords should be an array of strings
    assert(!keywords.nil? && keywords.length > 0)
    # assert each keyword is a string with length > 0
    keywords.each do |keyword|
      assert(!keyword.nil? && keyword.length > 0)
    end

    sentiment = hit.field["sentiment"]
    assert(!sentiment.nil? && sentiment >= -5 && sentiment <= 5)
  end

  def teardown
    stop
  end
end
