# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class SearchPath < IndexedOnlySearchTest

  def setup
    set_owner("balder")
  end

  def test_searchpath
    @valgrind=false
    set_description("Test for searchpath")
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new("mycluster").sd(SEARCH_DATA+"music.sd").
                       redundancy(3).
                       ready_copies(3).
                       group(create_groups())))
    start
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.xml")

    puts "Fetch 777 total documents from all nodes"
    assert_hitcount("query=sddocname:music", 777)
    res = {:n0g0 => 400, :n0g1 => 366, :n0g2 => 396, :n1g0 => 377, :n1g1 => 411, :n1g2 => 381}
    run_searchpath_test(res)
  end

  def run_searchpath_test(res)
    puts "Fetch total documents from column 0"
    assert_hitcount("query=sddocname:music&model.searchPath=0/0", res[:n0g0])
    assert_hitcount("query=sddocname:music&searchpath=0/0", res[:n0g0])
    assert_hitcount("query=sddocname:music&searchPath=0/0", res[:n0g0])
    assert_hitcount("query=sddocname:music&model.searchPath=0/1", res[:n0g1])
    assert_hitcount("query=sddocname:music&model.searchPath=0/2", res[:n0g2])

    puts "Fetch total documents from column 1"
    assert_hitcount("query=sddocname:music&model.searchPath=1/0", res[:n1g0])
    assert_hitcount("query=sddocname:music&model.searchPath=1/1", res[:n1g1])
    assert_hitcount("query=sddocname:music&model.searchPath=1/2", res[:n1g2])

    puts "Test comma separated list"
    assert_hitcount("query=sddocname:music&model.searchPath=0,0/0", res[:n0g0])
    assert_hitcount("query=sddocname:music&model.searchPath=0,1/0", 777)

    puts "Test range list"
    assert_hitcount("query=sddocname:music&model.searchPath=[0,1%3E/0", res[:n0g0])
    assert_hitcount("query=sddocname:music&model.searchPath=[0,2%3E/0", 777)

    puts "Test out of range -> capping"
    assert_hitcount("query=sddocname:music&model.searchPath=0,1,2/0", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=[0,3%3E/0", 777)

    puts "Test wildcard queries"
    assert_hitcount("query=sddocname:music&model.searchPath=", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=%2A", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=/0", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=/1", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=/2", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=/%2A", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=%2A/0", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=%2A/1", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=%2A/2", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=%2A/%2A", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=//", 777)
    assert_hitcount("query=sddocname:music&model.searchPath=/0", 777)
    hitcount = search("query=sddocname:music&model.searchPath=1/").hitcount
    possible_hitcounts = [res[:n1g0], res[:n1g1], res[:n1g2]]
    assert(possible_hitcounts.include?(hitcount))

    puts "Test errors that shall throw exceptions"
    assert_hitcount("query=sddocname:music&model.searchPath=a/0", 0)
    assert_hitcount("query=sddocname:music&model.searchPath=[a/0", 0)
    assert_hitcount("query=sddocname:music&model.searchPath=[a,b%3E/0", 0)
  end

  def create_groups
    NodeGroup.new(0, "mytopgroup").
      distribution("1|1|*").
      group(NodeGroup.new(0, "mygroup0").
            node(NodeSpec.new("node1", 0)).
            node(NodeSpec.new("node1", 1))).
      group(NodeGroup.new(1, "mygroup1").
            node(NodeSpec.new("node1", 2)).
            node(NodeSpec.new("node1", 3))).
      group(NodeGroup.new(2, "mygroup2").
            node(NodeSpec.new("node1", 4)).
            node(NodeSpec.new("node1", 5)))
  end

  def teardown
    stop
  end

end
