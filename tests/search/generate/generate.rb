# Copyright Vespa.ai. All rights reserved.
require 'search_test'

class ContainerTensorEval < SearchTest
  def setup
    super
    set_owner('glebashnik')
    set_description('Test feed field generator')
    # add_bundle_dir(selfdir + 'app', 'generate', {:mavenargs => '-Dmaven.test.skip=true'})
    deploy("#{selfdir}/target/application")
    start
  end

  def test_feed_field_generator
    feed_and_wait_for_docs('test', 1, :file => selfdir + "data/one.jsonl")
    assert_hitcount('query=manhattan', 1)
  end
end
