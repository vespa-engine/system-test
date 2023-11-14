# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class DefaultFederationSources < SearchContainerTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("nobody")
    set_description("Tests setting the federation option 'default'.")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.example.AddHitSearcher")
    deploy(selfdir+"app")
    start
  end

  def test_default_sources_in_default_federation
    result = search("ignored&format=xml")

    titles = get_sorted_titles(result)
    assert_equal(5, titles.length)
    ["Searcher in source2 in explicitly_enabled_providers_with_sources_are_used_by_default",
     "Searcher in common_source in source_leaders_are_used_by_default",
     "Searcher in explicitly_enabled_providers_with_sources_are_used_by_default",
     "Searcher in providers_without_children_are_used_by_default",
     "Searcher in source1 in providers_with_sources_are_not_used_by_default"].
      zip(titles).each { |expected, title|
      assert(title.include?(expected), "'#{title}' does not include '#{expected}'")
    }
  end

  def test_default_sources_in_custom_federation
    result = search("?searchChain=custom_federation&format=xml")

    titles = get_sorted_titles(result)

    assert_equal(2, titles.length)
    ["Searcher in chains_are_used_by_default",
     "Searcher in explicitly_enabled_providers_with_sources_are_used_by_default"].
      zip(titles).each { |expected, title|
      assert(title.include?(expected), "'#{title}' does not include '#{expected}'")
    }
  end

  def test_non_default_sources_in_custom_federation
    result = search("?searchChain=custom_federation&sources=source2&format=xml")

    titles = get_sorted_titles(result)

    assert_equal(2, titles.length)
    ["Searcher in source2 in explicitly_enabled_providers_with_sources_are_used_by_default",
     "Searcher in explicitly_enabled_providers_with_sources_are_used_by_default"].
      zip(titles).each { |expected, title|
      assert(title.include?(expected), "'#{title}' does not include '#{expected}'")
    }
  end

  def get_sorted_titles(result)
    titles = []
    result.xml.each_element("//hit//field[@name='title']") { |i| titles.push(i.text) };
    titles.sort()
  end

  def teardown
    stop
  end

end
