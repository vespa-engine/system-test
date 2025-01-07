require 'search_test'


class Generate < SearchTest
  def setup
    super
    set_owner('glebashnik')
    set_description('Test feed field generator')
  end

  def test_feed_field_generator
    system('cd app && mvn generate-resources && mvn package')
    deploy(selfdir + 'app/target/application')
    start
    # SearchApp.new.sd(selfdir + 'app/src/main/application/schemas/music.sd').deploy(self)
    feed_and_wait_for_docs('passage', 1, :file => selfdir + "data/one.jsonl")
    assert_hitcount('query=manhattan&ranking=mock_gen', 1)
    assert_hitcount('query=manhattan&ranking=mock_lm_gen', 1)
    assert_hitcount('query=manhattan&ranking=local_llm_gen', 1)
  end

  def teardown
    stop
  end
end
