# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Rendering < IndexedStreamingSearchTest
  SAVE_RESULT = false

  def setup
    set_owner("nobody")
    set_description("Test the search rendering api and deployment of renderers. [Depends on working grouping test.]")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.DemoRenderer")
    deploy_app(SearchApp.new.
                   sd(selfdir + "purchase.sd").
                   container(
                   Container.new.search(
                       Searching.new.
                           renderer(Renderer.new("DemoRenderer", "com.yahoo.vespatest.DemoRenderer")).
                           renderer(Renderer.new("SimpleRenderer", "com.yahoo.vespatest.SimpleRenderer").
                                        bundle("com.yahoo.vespatest.DemoRenderer").
                                        config(ConfigOverride.new("com.yahoo.vespatest.simple-renderer").add("text", "Number of hits:"))))))
    start
    feed_and_wait_for_docs("purchase", 20, :file => "#{selfdir}/docs.xml");
  end

  def test_rendering
    simple_renderer_with_config
    empty_result
    grouping_rendering
    error_message if not is_streaming
  end

  def simple_renderer_with_config
    check_query("/?query=noMatchingResults", "simple_renderer.txt", "SimpleRenderer")
  end

  def empty_result
    check_query("/?query=noMatchingResults", "emtpy.txt")
  end

  def error_message
    check_query("/?query=", "error_message.txt")
  end

  def grouping_rendering
    check_grouping_query("all(group(customer) each(group(time.date(date)) each(output(sum(price)))))",
                "example7.txt")

    check_grouping_query("all(group(customer) each(max(3) each(output(summary()))))",
                "example6.txt")
  end

  def check_grouping_query(group, file)
    query = "/?query=sddocname:purchase&hits=0&select=#{group}"
    check_query(query, file)
  end

  def check_query(query, file, renderer="DemoRenderer")
    fullQuery = "#{query}&presentation.format=#{renderer}"
    if (SAVE_RESULT)
      save_result(fullQuery, file);
    end
    assert_xml_result_with_timeout(2.0, fullQuery, "#{selfdir}/#{file}")
  end

  def teardown
    stop
  end

end
