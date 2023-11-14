# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class FederationTest2 < SearchContainerTest

  def setup
    set_owner("nobody")
    set_description("Tests the new federation, as explained in the federation.html vespadoc")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.example.AddHitSearcher")
    deploy(selfdir+"app")
    start
  end

  def teardown
    stop
  end

  def test_inherits
    assert_length(1, ["test-inherits@test-source-inherits"])
  end

  def test_multiple_providers_per_source
    sourceName = "commonSource"

    sourceSpec = "?sources=#{sourceName}"
    sourceProviderSpec = sourceSpec + "&source.#{sourceName}.provider=%s"

    assert_title_matches(sourceSpec, /providerA/)
    assert_title_matches(sourceProviderSpec % "providerA", /providerA/)
    assert_title_matches(sourceProviderSpec % "providerB", /providerB/)
  end

  def assert_title_matches(query, regex)
    save_result(query, 'fqr')
    result = search(query)
    assert(result.hit.size > 0)
    result.hit.each do |h|
      assert(h.field['title'] =~ regex)
    end
  end

  def assert_length(length, searchChainNames)
    searchChainNames.flatten.each {
      | searchChainName |
      assert_equal(length, hit_length_searchchain(searchChainName))
    }
  end

  def search_searchchain(name)
    return search("?searchChain=#{name}&format=xml")
  end

  def hit_length_searchchain(name)
    puts("Checking result set length for search chain #{name}")
    return search_searchchain(name).hit.length
  end

  def test_target_selector
    result = search_searchchain("manual-target-selection")
    titles = get_sorted_titles(result)
    assert_equal(["custom-data--modifyTargetQuery called",
                  "from used-by-TestTargetSelector"],
                 titles)
  end

  def get_sorted_titles(result)
    titles = []
    result.xml.each_element("//hit//field[@name='title']") { |i| titles.push(i.text) };
    titles.sort()
  end
end
