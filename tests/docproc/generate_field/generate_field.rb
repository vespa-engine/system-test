require 'search_test'

class GenerateField < SearchTest
  def setup
    super
    set_owner("glebashnik")
    set_description("Test generation of document fields using custom gen.")
  end

  def timeout_seconds
    # Need extra time to download LLM.
    900
  end

  def test_generate_field
    add_bundle_dir(selfdir + "bundle", "app")
    deploy(selfdir + "/app")
    start(600)
  
    feed_and_wait_for_docs('passage', 1, :file => selfdir + "data/feed.jsonl")
    
    result = search("query=friend")
    assert_equal(1, result.hit.size)
    
    hit = result.hit[0]

    # Text output to string with mock generator 
    assert_equal("Explain: silence is a true friend who never betrays Explain: silence is a true friend who never betrays",
                 hit.field["mock_generator"])

    # Text output to string with mock language model
    assert_equal("Explain: silence is a true friend who never betrays Explain: silence is a true friend who never betrays",
                 hit.field["mock_language_model"])
    
    # Structured output to string
    explanation = hit.field["explanation"]
    assert(!explanation.nil? && explanation.size > 0, "'explanation' in hit is nil, response: #{result}")

    # Structured output to array of strings
    keywords = hit.field["keywords"]
    assert(!keywords.nil? && keywords.size > 0, "Wrong keywords: #{keywords}")
    
    # Structured output to bool
    assert(!hit.field["sentiment_bool"].nil?)

    # Structured output to int
    assert(!hit.field["sentiment_int"].nil?)

    # Structured output to long
    assert(!hit.field["sentiment_long"].nil?)

    # Structured output to float
    assert(!hit.field["sentiment_float"].nil?)

    # Structured output to double
    assert(!hit.field["sentiment_double"].nil?)
  end

  def teardown
    stop
  end
end
