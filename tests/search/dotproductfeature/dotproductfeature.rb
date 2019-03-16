# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class DotProductFeature < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_dotproduct
    set_description("Test the dotproduct feature")
    deploy_app(SearchApp.new.sd(selfdir+"dotproduct.sd"))
    start
    feed_and_wait_for_docs("dotproduct", 1, :file => selfdir + "dotproduct.xml")

    assert_dotproduct({"dotProduct(a,x)" => 0,  "dotProduct(b,x)" => 0,  "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0}, [])
    assert_dotproduct({"dotProduct(a,y)" => 0,  "dotProduct(b,y)" => 0,  "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0}, [])
    assert_dotproduct({"dotProduct(a,x)" => 10, "dotProduct(b,x)" => 40, "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0}, ["x=(i:1,j:2)"])
    assert_dotproduct({"dotProduct(a,y)" => 0,  "dotProduct(b,y)" => 0,  "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0}, ["x=(i:1,j:2)"])
    assert_dotproduct({"dotProduct(a,x)" => 10, "dotProduct(b,x)" => 40, "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0}, ["x=(i:1,j:2)","y=(i:0.5,j:-0.5)"])
    assert_dotproduct({"dotProduct(a,y)" => -1, "dotProduct(b,y)" => -4, "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0}, ["x=(i:1,j:2)","y=(i:0.5,j:-0.5)"])
    assert_dotproduct({"dotProduct(f,vf)" => 29}, ["vf={0:3.5,1:4.5}"])
    assert_dotproduct({"dotProduct(f,vf)" => 29}, ["vf=(0:3.5,1:4.5)"])
    assert_dotproduct({"dotProduct(f,vf)" => 20.25}, ["vf=(1:4.5)"])
    assert_dotproduct({"dotProduct(f,vf)" => 8.75}, ["vf=(0:3.5)"])
    assert_dotproduct({"dotProduct(i,vi)" => 22}, ["vi=[3 4]"])
    assert_dotproduct({"dotProduct(f,vf)" => 29}, ["vf=[3.5 4.5]"])
    assert_dotproduct({"dotProduct(l,vl)" => 22}, ["vl=[3 4]"])
    assert_dotproduct({"dotProduct(d,vd)" => 29}, ["vd=[3.5 4.5]"])
    assert_dotproduct({"dotProduct(fd,vfd)" => 29}, ["vfd=[3.5 4.5]"])
    assert_dotproduct({"dotProduct(ff,vff)" => 29}, ["vff=[3.5 4.5]"])
    assert_dotproduct({"dotProduct(fl,vfl)" => 22}, ["vfl=[3 4]"])
    assert_dotproduct({"dotProduct(fi,vfi)" => 22}, ["vfi=[3 4]"])
    assert_dotproduct({"dotProduct(i,vi)" => 22, "dotProduct(f,vf)" => 29}, ["vi=[3 4]", "vf=[3.5 4.5]"])
    assert_dotproduct({"dotProduct(i,vi)" => -22, "dotProduct(f,vf)" => -29}, ["vi=[-3 -4]", "vf=[-3.5 -4.5]"])
  end

  def assert_dotproduct(expected, vectors)
    query = "query=sddocname:dotproduct&streaming.userid=1"
    vectors.each do |vector|
      query += "&rankproperty.dotProduct." + vector
    end
    puts "run '#{query}'"
    result = search(query)
    assert_features(expected, JSON.parse(result.hit[0].field["summaryfeatures"]), 1e-4)
  end


  def teardown
    stop
  end

end
