require 'search_test'

class Generate < SearchTest
  def setup
    super
    set_owner('glebashnik')
    set_description('Test feed field generator')
    # add_bundle_dir(selfdir + 'app', 'generate', {:mavenargs => '-Dmaven.test.skip=true'})
    start
  end

  def test_feed_field_generator
    deploy(selfdir + 'app/target/application')
    start
    # SearchApp.new.sd(selfdir + 'app/src/main/application/schemas/music.sd').deploy(self)
    feed_and_wait_for_docs('passage', 1, :file => selfdir + "data/one.jsonl")
    assert_hitcount('query=manhattan', 1)
  end

  def teardown
    stop
  end
end
