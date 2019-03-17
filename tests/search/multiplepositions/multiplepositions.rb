# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MultiplePositions < IndexedSearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("musum")
    set_description("Test single and multivalued input to positions with new position syntax in sd files")
  end

  def nightly?
    true
  end

  def test_multiplepos_2d
    deploy_app(SearchApp.new.sd(selfdir+"multiplepos2d.sd"))
    start
    feed_and_wait_for_docs("multiplepos2d", 4, :file => selfdir+"multiplepos2d.xml")
    wait_for_hitcount("query=Trondheim1", 1)
    puts "Query: Search with position"
    assert_hitcount("query=Trondheim1&pos.ll=0N%3B0E", 0)
    assert_hitcount("query=Trondheim1&pos.ll=63N25%3B10E25", 1)

    assert_hitcount("query=sddocname:multiplepos2d&pos.ll=63.4225N%3B10.3637E", 2)
    assert_hitcount("query=sddocname:multiplepos2d&pos.ll=63.4225N%3B10.3637E&pos.radius=5km", 2)
    assert_hitcount("query=sddocname:multiplepos2d&pos.ll=63.4225N%3B10.3637E&pos.radius=100m", 1)


    assert_result("query=sddocname:multiplepos2d&pos.ll=63N25%3B10E25", selfdir+"multiplepos2d.result")
  end


  def test_multiplepos_1d
    deploy_app(SearchApp.new.sd(selfdir+"multiplepos1d.sd"))
    start
    feed_and_wait_for_docs("multiplepos1d", 4, :file => selfdir+"multiplepos1d.xml")
    wait_for_hitcount("query=Trondheim1", 1)
    puts "Query: Search with position"
    assert_hitcount("query=Trondheim1+ll:[1%3B2]&location=[1,0,0]", 0)
    assert_hitcount("query=Trondheim1+ll:[633000%3B634345]&location=[1,0,0]", 1)

    assert_hitcount("query=ll:[633000%3B654345]&location=[1,0,0]", 2)
    assert_hitcount("query=ll:[653000%3B654345]&location=[1,0,0]", 1)
  end


  # Also tests that specifying a name for the position attribute works
  def test_singlepos_2d
    deploy_app(SearchApp.new.sd(selfdir+"singlepos2d.sd"))
    start
    feed_and_wait_for_docs("singlepos2d", 12, :file => selfdir+"singlepos2d.xml")
    wait_for_hitcount("query=Steinberget", 1)
    puts "Query: Search with position"
    assert_hitcount("query=Steinberget&pos.ll=0N%3B0E", 0)
    assert_hitcount("query=Steinberget&pos.ll=63N25%3B10E25", 1)

    assert_hitcount("query=sddocname:singlepos2d&pos.ll=63.4225N%3B10.3637E", 10)
    assert_hitcount("query=sddocname:singlepos2d&pos.ll=63.4225N%3B10.3637E&pos.radius=5km", 6)
    assert_hitcount("query=sddocname:singlepos2d&pos.ll=63.4225N%3B10.3637E&pos.radius=100m", 1)
  end


  def test_singlepos_1d
    deploy_app(SearchApp.new.sd(selfdir+"singlepos1d.sd"))
    start
    feed_and_wait_for_docs("singlepos1d", 11, :file => selfdir+"singlepos1d.xml")
    wait_for_hitcount("query=Steinberget", 1)
    puts "Query: Search with position"
    assert_hitcount("query=Steinberget+ll:[1%3B2]&location=[1,0,0]", 0)
    assert_hitcount("query=Steinberget+ll:[633000%3B634345]&location=[1,0,0]", 1)

    assert_hitcount("query=ll:[633000%3B644345]&location=[1,0,0]", 10)
    assert_hitcount("query=ll:[634537%3B654345]&location=[1,0,0]", 1)
  end


  def teardown
    stop
  end

end
