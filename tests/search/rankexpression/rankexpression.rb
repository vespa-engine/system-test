# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class RankExpression < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
  end

  def test_rankExpressionUnaryMinus
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData()
    #assert_unary_minus("unary_minus1")
    assert_unary_minus("unary_minus2")
    #assert_unary_minus("unary_minus3")
    assert_unary_minus("unary_minus4")
  end

  def assert_unary_minus(ranking)
    result = search("query=sddocname:rankexpression&skipnormalizing&ranking=#{ranking}")
    result.hit.each_index do |i|
      myrank = result.hit[i].field["myrank"].to_i
      relevancy = result.hit[i].field["relevancy"].to_i
      assert_equal(-myrank, relevancy,
                   "Expected -#{myrank}, got #{relevancy} for hit #{i} with " +
                   "ranking profile '#{ranking}'.")
    end
  end

  def test_rankExpression
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData();
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100");
    result.hit.each_index do |i|
      score = result.hit[i].field["relevancy"].to_i;
      exp = 100 - i;
      if (i < 10)
        exp = exp * exp;
      end
      assert(score == exp, "Expected relevancy #{exp} for document #{i}.");
    end
  end

  def test_rankExpressionParams
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData();
    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1");
    assert(result.hit[0].field["relevancy"].to_i == 0 * 10);

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params2");
    assert(result.hit[0].field["relevancy"].to_i == 1 * 10);

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankproperty.var1=2");
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10);

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankfeature.$var1=2");
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10);

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankfeature.query(var1)=2");
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10);

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankfeature.query(var1)=2");
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10);
  end

  def test_RankExpressionFile
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData();
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100&ranking=file1");
        result.hit.each_index do |i|
          score = result.hit[i].field["relevancy"].to_i;
          exp = 100 - i;
          if (i < 10)
            exp = exp * exp * exp;
          end
          assert(score == exp, "Expected relevancy #{exp} for document #{i}.");
        end
  end

  def test_RankExpressionFileLogical
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      sd(selfdir + "rankexpression2.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData();
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100&ranking=file1&search=rankexpression");
        result.hit.each_index do |i|
          score = result.hit[i].field["relevancy"].to_i;
          exp = 100 - i;
          if (i < 10)
            exp = exp * exp * exp;
          end
          assert(score == exp, "Expected relevancy #{exp} for document #{i}.");
        end
  end

  def test_RankExpressionMembership
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
               rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData();
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100&ranking=in1");
    result.hit.each_index do |i|
      score = result.hit[i].field["relevancy"].to_i;
      if (i == 0)
        exp = 9
      elsif (i == 1)
        exp = 6
      else
        exp = 0
      end
      assert(score == exp, "Expected relevancy #{exp} for document #{i}.");
    end
  end

  def indexData
    str =""
    0.upto(99) do |i|
      str += "<document id=\"id:scheme:rankexpression::#{i}\" type=\"rankexpression\">";
      str += "<title>document #{i}</title>";
      str += "<myrank>#{100 - i}</myrank>";
      str += "</document>\n";
    end
    feed = File.open("#{dirs.tmpdir}/feed.xml", "w")
    feed.print(str);
    feed.close();
    feed_and_wait_for_docs("rankexpression", 100, :file => "#{dirs.tmpdir}/feed.xml");
  end

  def test_isnan
    set_description("Test that isNan function works")
    deploy_app(SearchApp.new.sd(selfdir + "isnan.sd"))
    start
    feed_and_wait_for_docs("isnan", 2, :file => selfdir + "isnan.xml")
    assert_relevancy("query=sddocname:isnan&ranking=rp1", 31, 0)
    assert_relevancy("query=sddocname:isnan&ranking=rp1", 11, 1)
    assert_relevancy("query=sddocname:isnan&ranking=rp2", 32.2, 0)
    assert_relevancy("query=sddocname:isnan&ranking=rp2", 12,   1)
    assert_relevancy("query=sddocname:isnan&ranking=rp3", 33.3, 0)
    assert_relevancy("query=sddocname:isnan&ranking=rp3", 13,   1)
  end

  def teardown
    stop
  end

end
