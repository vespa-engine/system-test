# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class VisibilityDelayTest < SearchTest

  def setup
    set_owner("geirst")
    @visibility_delay = 30.0
  end

  def test_visibility_delay
    set_description("Test that committing to attribute and index fields considers visibility delay")
    deploy_app(get_app(@visibility_delay))
    start

    assert_puts_committed_at_visibility_delay
    assert_updates_committed_at_visibility_delay
    assert_puts_committed_at_get
    assert_puts_committed_at_flush
    assert_puts_committed_at_shutdown
  end

  def get_app(visibility_delay)
    SearchApp.new.sd(SEARCH_DATA + "test.sd").
      config(ConfigOverride.new("vespa.config.search.core.proton").
             add("maxvisibilitydelay", 150)).
      visibility_delay(visibility_delay).enable_http_gateway
  end

  def assert_field_content(exp_hits, field, term, content)
    puts "assert_field_content(#{exp_hits}, #{field}, #{term}, #{content})"
    result = search("query=#{field}:#{term}&nocache")
    assert_hitcount(result, exp_hits)
    for i in 0...exp_hits
      puts "assert_field_value(#{field}, #{content}, #{i})"
      assert_field_value(result, field, content.to_s, i)
    end
  end

  def assert_docs(exp_hits, f1_term, f1_content, f2_term)
    assert_field_content(exp_hits, "f1", f1_term, f1_content)
    assert_field_content(exp_hits, "f2", f2_term, f2_term)
  end

  def wait_for_docs(exp_hits, f1, f2, timeout = 120)
    wait_for_hitcount("query=f1:#{f1}&nocache", exp_hits, timeout)
    wait_for_hitcount("query=f2:#{f2}&nocache", exp_hits, timeout)
  end

  def sleep_visibility_delay
    sleep_time = @visibility_delay + 5
    puts "sleep_visibility_delay: #{sleep_time}"
    sleep sleep_time
  end

  def restart_search_node
    vespa.search["search"].first.restart
    sleep 2
  end

  def assert_puts_committed_at_visibility_delay
    feed(:file => selfdir + "docs.0.json")
    sleep_visibility_delay
    assert_docs(3, "foo", "foo", 10)
  end

  def assert_updates_committed_at_visibility_delay
    restart_search_node
    wait_for_docs(3, "foo", 10) # previous doc state

    feed(:file => selfdir + "updates.0.json")
    sleep_visibility_delay
    assert_docs(3, "foo", "foo", 15)
    assert_hitcount("query=f2:10&nocache", 0)
  end

  def assert_puts_committed_at_get
    restart_search_node
    wait_for_docs(3, "foo", 15) # previous doc state

    feed(:file => selfdir + "docs.1.json")
    act_doc = vespa.document_api_v1.get("id:test:test::0")
    exp_doc = Document.new("test", "id:test:test::0").add_field("f1", "bar").add_field("f2", 20)
    assert_equal(exp_doc, act_doc)
    # Getting a document from proton commits the underlying memory structures but do not wait until index write thread is done.
    # Due to this we need to wait for expected hits. We use a timeout less than visibility delay to ensure
    # that we get the expected hits before the delay triggers a new commit.
    wait_for_docs(0, "foo", 15, @visibility_delay / 2)
    assert_docs(3, "bar", "bar", 20)
  end

  def assert_puts_committed_at_flush
    restart_search_node
    wait_for_docs(3, "bar", 20) # previous doc state

    feed(:file => selfdir + "docs.2.json")
    vespa.search["search"].first.trigger_flush
    assert_docs(0, "bar", "bar", 20)
    assert_docs(3, "baz", "baz", 30)
  end

  def assert_puts_committed_at_shutdown
    restart_search_node
    wait_for_docs(3, "baz", 30) # previous doc state
    assert_docs(0, "bar", "bar", 20)
    assert_docs(3, "baz", "baz", 30)

    feed(:file => selfdir + "updates.0.json")
    assert_docs(0, "bar", "bar", 20)
    assert_docs(3, "baz", "baz", 30)
    vespa.search["search"].first.kill
    restart_search_node
    wait_for_docs(3, "baz", 15)
    assert_docs(3, "baz", "baz", 15)
  end

  def test_live_reconfig
    set_description("Test that visibility delay can be configured up and down on a live system")
    deploy_app(get_app(0))
    start
    feed(:file => selfdir + "docs.0.json")
    assert_hitcount("query=f1:foo&nocache", 3)
    assert_hitcount("query=f1:bar&nocache", 0)

    redeploy(get_app(@visibility_delay))
    feed(:file => selfdir + "docs.1.json")
    assert_hitcount("query=f1:foo&nocache", 3)
    assert_hitcount("query=f1:bar&nocache", 0)

    redeploy(get_app(0))
    assert_hitcount("query=f1:foo&nocache", 0)
    assert_hitcount("query=f1:bar&nocache", 3)
    feed(:file => selfdir + "docs.2.json")
    assert_hitcount("query=f1:bar&nocache", 0)
    assert_hitcount("query=f1:baz&nocache", 3)
  end

  def teardown
    stop
  end

end
