# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SourceProvider < IndexedSearchTest

  def setup
    set_owner("nobody")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
               cluster_name('mysearch').
                        search_dir(selfdir + "search").
                        search_chain(SearchChain.new("default").inherits(nil).
                                       add(Federation.new("federationSearcher").
                                             add('mysearch').
                                             add("local").
                                             add("local_other")
                                          )
                                    ).
                        search_chain(Provider.new('mysearch', "local").cluster('mysearch')).
                        search_chain(Provider.new("local", "local").cluster('mysearch')).
                        search_chain(Provider.new("local_other", "local").cluster('mysearch'))
                     )
    start
    feed(:file => SEARCH_DATA+"music.777.xml")
    wait_for_hitcount("sddocname:music&sources=mysearch&hits=0", 777)
  end

  def test_nonexisting_source
    wait_for_atleast_hitcount("sddocname:music&sources=mysearch,local&hits=0", 777*2)
    singleresult = search("sddocname:music&sources=mysearch")
    assert_equal(777, singleresult.hitcount)
    assert_query_no_errors("sddocname:music&sources=mysearch")
    nonexistingresult = search("sddocname:music&sources=nonexisting,mysearch&hits=0")
    assert_equal(777, nonexistingresult.hitcount)
    assert_query_errors("sddocname:music&sources=mysearch,nonexisting&hits=0",[
      "Could not resolve source ref 'nonexisting'. Valid source refs are .*"
    ]);

  end

  def test_settings
    wait_for_atleast_hitcount("sddocname:music&sources=mysearch,local", 777*2)
    singleresult = search("sddocname:music&sources=mysearch")
    assert_equal(777, singleresult.hitcount)
    multiresult = search("sddocname:music&sources=mysearch,local&rankfeature.$now=42")
    assert_equal(777*2, multiresult.hitcount)


    #Check that the result in the two groups are equal
    #Since we have groups, we have to parse the hits ourselves
    groups = parseGroups(multiresult)
    (0..10).each {|i|
      assert_equal(groups["local"][i], groups['mysearch'][i])
    }

    ##Test out properties
    sourceresult = search("sddocname:music&sources=mysearch,local&source.mysearch.hits=5&source.mysearch.offset=5&source.local.offset=10&source.local.hits=15")

    sourcegroups = parseGroups(sourceresult)

    assert_equal(15, sourcegroups["local"].size)
    assert_equal(5, sourcegroups['mysearch'].size)
    assert_equal(groups['mysearch'][5], sourcegroups['mysearch'][0])

    providerresult = search("sddocname:music&sources=local&provider.local.hits=15&source.local.hits=5&provider.local.offset=5")

    providergroups = parseGroups(providerresult)

    assert_equal(5, providergroups["local"].size)
    assert_equal(groups["local"][5], providergroups["local"][0])
  end


  def megs(i)
     i << 20
  end


  def parseGroups(res)
    groups = {}
    res.groupings.each do |name,groupEl|
      hits = []
      groupEl['children'].each do |hitEl|
        hitEl.delete('source')
        hits.push Hit.new(hitEl)
      end
      groups[groupEl["source"]] = hits
    end
    return groups
  end

  def teardown
    stop
  end
end
