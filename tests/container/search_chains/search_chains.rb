# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class SearchChainsTest < SearchContainerTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("gjoranv")
    set_description("Tests the search chain config, as explained in https://docs.vespa.ai/en/components/chained-components.html")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.example.AddHitSearcher")
    deploy(selfdir+"app")
    start
  end

  # Gives as many hits as there are AddHitSearcher instances in the chain, see services.xml
  def test_resultset_lengths
    assert_length(0, ["simple_1"])

    assert_length(1,
                  ["simple_2",
                   combine(["simple", "elementary"], (3..5)),
                   "base1_9", "base2_9",
                   "referenceChain", "referenceChain2",
                   "derived_8",
                   "base1_9", "base2_9", "derived_9"])

    assert_length(2,
                  [combine(["base"], (6..8)),
                   "derived_7"])
    assert_length(3, ["derived_6"])

  end

  def teardown
    stop
  end

  def assert_length(length, searchChainNames)
    searchChainNames.flatten.each {
      | searchChainName |
      assert_equal(length, hit_length_searchchain(searchChainName))
    }
  end

  def search_searchchain(name)
    return search("?searchChain=#{name}")
  end

  def hit_length_searchchain(name)
    puts("Checking result set length for search chain #{name}")
    return search_searchchain(name).hit.length
  end

  def combine(searchChainNames, range)
    searchChainNames.collect { | searchChainName |
      range.collect { | i |
        "#{searchChainName}_#{i}"
      }
    }.flatten
  end
end
