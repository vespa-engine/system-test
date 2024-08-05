# Copyright Vespa.ai. All rights reserved.

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
    feed_and_wait_for_docs("dotproduct", 1, :file => selfdir + "dotproduct.json")

    assert_dotproduct({"rankingExpression(sum_dp)" => 0, "dotProduct(a,x)" => 0,  "dotProduct(b,x)" => 0,  "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0,
                       "dotProduct(a2,x)" => 0,  "dotProduct(b2,x)" => 0,  "dotProduct(i2,vi)" => 0, "dotProduct(f2,vf)" => 0}, [])
    assert_dotproduct({"rankingExpression(sum_dp)" => 0, "dotProduct(a,y)" => 0,  "dotProduct(b,y)" => 0,  "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0,
                       "dotProduct(a2,y)" => 0,  "dotProduct(b2,y)" => 0,  "dotProduct(i2,vi)" => 0, "dotProduct(f2,vf)" => 0}, [])
    assert_dotproduct({"rankingExpression(sum_dp)" => 110, "dotProduct(a,x)" => 10, "dotProduct(b,x)" => 40, "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0,
                       "dotProduct(a2,x)" => 17, "dotProduct(b2,x)" => 43, "dotProduct(i2,vi)" => 0, "dotProduct(f2,vf)" => 0}, ["x=(i:1,j:2)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 110, "dotProduct(a,y)" => 0,  "dotProduct(b,y)" => 0,  "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0,
                       "dotProduct(a2,y)" => 0,  "dotProduct(b2,y)" => 0,  "dotProduct(i2,vi)" => 0, "dotProduct(f2,vf)" => 0}, ["x=(i:1,j:2)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 99, "dotProduct(a,x)" => 10, "dotProduct(b,x)" => 40, "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0,
                       "dotProduct(a2,x)" => 17, "dotProduct(b2,x)" => 43, "dotProduct(i2,vi)" => 0, "dotProduct(f2,vf)" => 0}, ["x=(i:1,j:2)","y=(i:0.5,j:-0.5)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 99, "dotProduct(a,y)" => -1, "dotProduct(b,y)" => -4, "dotProduct(i,vi)" => 0, "dotProduct(f,vf)" => 0,
                       "dotProduct(a2,y)" => -2, "dotProduct(b2,y)" => -4, "dotProduct(i2,vi)" => 0, "dotProduct(f2,vf)" => 0}, ["x=(i:1,j:2)","y=(i:0.5,j:-0.5)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 75, "dotProduct(f,vf)" => 29, "dotProduct(f2,vf)" => 46}, ["vf={0:3.5,1:4.5}"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 75, "dotProduct(f,vf)" => 29, "dotProduct(f2,vf)" => 46}, ["vf=(0:3.5,1:4.5)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 54, "dotProduct(f,vf)" => 20.25, "dotProduct(f2,vf)" => 33.75}, ["vf=(1:4.5)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 21, "dotProduct(f,vf)" => 8.75, "dotProduct(f2,vf)" => 12.25}, ["vf=(0:3.5)"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 59, "dotProduct(i,vi)" => 22, "dotProduct(i2,vi)" => 37}, ["vi=[3 4]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 75, "dotProduct(f,vf)" => 29, "dotProduct(f2,vf)" => 46}, ["vf=[3.5 4.5]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 59, "dotProduct(l,vl)" => 22, "dotProduct(l2,vl)" => 37}, ["vl=[3 4]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 75, "dotProduct(d,vd)" => 29, "dotProduct(d2,vd)" => 46}, ["vd=[3.5 4.5]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 75, "dotProduct(fd,vfd)" => 29, "dotProduct(fd2,vfd)" => 46}, ["vfd=[3.5 4.5]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 75, "dotProduct(ff,vff)" => 29, "dotProduct(ff2,vff)" => 46}, ["vff=[3.5 4.5]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 59, "dotProduct(fl,vfl)" => 22, "dotProduct(fl2,vfl)" => 37}, ["vfl=[3 4]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 59, "dotProduct(fi,vfi)" => 22, "dotProduct(fi2,vfi)" => 37}, ["vfi=[3 4]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => 134, "dotProduct(i,vi)" => 22, "dotProduct(f,vf)" => 29,
                       "dotProduct(i2,vi)" => 37, "dotProduct(f2,vf)" => 46}, ["vi=[3 4]", "vf=[3.5 4.5]"])
    assert_dotproduct({"rankingExpression(sum_dp)" => -134, "dotProduct(i,vi)" => -22, "dotProduct(f,vf)" => -29,
                       "dotProduct(i2,vi)" => -37, "dotProduct(f2,vf)" => -46}, ["vi=[-3 -4]", "vf=[-3.5 -4.5]"])
  end

  def assert_dotproduct(expected, vectors)
    query = "query=sddocname:dotproduct&ranking=sum_dotproduct&ranking.queryCache=true"
    vectors.each do |vector|
      query += "&rankproperty.dotProduct." + vector
    end
    puts "run '#{query}'"
    result = search(query)
    assert_features(expected, result.hit[0].field['summaryfeatures'], 1e-4)
  end


  def teardown
    stop
  end

end
