# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class ComponentDirectoryconfig < SearchContainerTest

  def setup
    @valgrind = false
    set_owner("hmusum")
    set_description("Verify that a directory can be distributed using file distribution.")
  end

  def test_transfer_directory_to_searcher
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.FileSearcher")
    deploy(selfdir+"app")
    start

    result = search("query=test")

    titles = []
    result.hit.each { |hit|
      titles.push(hit.field["title"])
    }
    assert_equal(2, titles.size())

    sorted_titles = titles.sort()
    assert_equal("one\n", sorted_titles[0])
    assert_equal("two\n", sorted_titles[1])
  end


end
