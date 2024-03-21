# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class YqlFederation < IndexedSearchTest

  def setup
    set_owner("arnej")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.SourceManager")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd")\
      .search_chain(SearchChain.new("default").inherits(nil)\
        .add(Federation.new("federationSearcher")\
          .add("search")\
          .add("local")\
        )\
        .add(Searcher.new("yql", nil, "Federation", "com.yahoo.search.yql.MinimalQueryInserter", "container-search-and-docproc"))\
        .add(Searcher.new("sourceManaging", "ExternalYql", nil, "com.yahoo.vespatest.SourceManager"))\
      )\
      .search_chain(Provider.new("search", "local").cluster("search"))\
      .search_chain(Provider.new("local", "local").cluster("search"))\
    )
    start
#    enable_all_log_levels
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.json")
  end

  def enable_all_log_levels
    qrs = (vespa.qrserver['0'] or vespa.container.values.first)
    svc = qrs.servicetype
    qrs.logctl("#{svc}:com.yahoo.search.cluster", "all=on")
  end

  def test_settings
    wait_for_atleast_hitcount("sddocname:music&sources=search,local", 777*2)
    singleresult = search("sddocname:music&sources=search&sorting=isbn")
    assert_equal(777, singleresult.hitcount)
    multiresult = search("sddocname:music&sources=search,local&sorting=isbn&format=xml")
    assert_equal(777*2, multiresult.hitcount)


    # Check that the result in the two groups are equal
    # Since we have groups, we have to parse the hits ourselves
    groups = parseGroups(multiresult.xml)
    (0..10).each {|i|
      assert_equal(groups["local"][i], groups["search"][i])
    }

  end


  def parseGroups(xml)
    groups = {}
    xml.each_element("group") { |groupEl|
      hits = []

      groupEl.each_element("hit") { |hitEl|
        if not hitEl.attributes["type"] == "logging" then
          hits.push  Hit.new(hitEl)
        end
      }
      # Ugly hack to handle a single level of nested, unnamed groups
      groupEl.each_element("group") { |innerGroupEl|
        hits = []
        innerGroupEl.each_element("hit") { |hitEl|
          if not hitEl.attributes["type"] == "logging" then
            hits.push  Hit.new(hitEl)
          end
        }
      }
      groups[groupEl.attributes["source"]] = hits
    }
    return groups
  end

  def teardown
    stop
  end
end
