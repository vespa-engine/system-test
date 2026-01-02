# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class RankExpression < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
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
    indexData()
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100")
    result.hit.each_index do |i|
      score = result.hit[i].field["relevancy"].to_i
      exp = 100 - i
      if (i < 10)
        exp = exp * exp
      end
      assert(score == exp, "Expected relevancy #{exp} for document #{i}.")
    end
  end

  def test_rankExpressionParams
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData()
    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1")
    assert(result.hit[0].field["relevancy"].to_i == 0 * 10)

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params2")
    assert(result.hit[0].field["relevancy"].to_i == 1 * 10)

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankproperty.var1=2")
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10)

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankfeature.$var1=2")
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10)

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankfeature.query(var1)=2")
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10)

    result = search("query=myrank:10&parallel&skipnormalizing&ranking=params1&rankfeature.query(var1)=2")
    assert(result.hit[0].field["relevancy"].to_i == 2 * 10)
  end

  def test_RankExpressionFile
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData()
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100&ranking=file1")
        result.hit.each_index do |i|
          score = result.hit[i].field["relevancy"].to_i
          exp = 100 - i
          if (i < 10)
            exp = exp * exp * exp
          end
          assert(score == exp, "Expected relevancy #{exp} for document #{i}.")
        end
  end

  def test_RankExpressionFileLogical
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
                      sd(selfdir + "rankexpression2.sd").
                      rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData()
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100&ranking=file1&search=rankexpression")
        result.hit.each_index do |i|
          score = result.hit[i].field["relevancy"].to_i
          exp = 100 - i
          if (i < 10)
            exp = exp * exp * exp
          end
          assert(score == exp, "Expected relevancy #{exp} for document #{i}.")
        end
  end

  def test_RankExpressionMembership
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
               rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData()
    result = search("query=sddocname:rankexpression&parallel&skipnormalizing&hits=100&ranking=in1")
    result.hit.each_index do |i|
      score = result.hit[i].field["relevancy"].to_i
      if (i == 0)
        exp = 9
      elsif (i == 1)
        exp = 6
      else
        exp = 0
      end
      assert(score == exp, "Expected relevancy #{exp} for document #{i}.")
    end
  end

  def test_switchExpression
    deploy_app(SearchApp.new.sd(selfdir + "rankexpression.sd").
               rank_expression_file(selfdir + "ranking1.expression"))
    start
    indexData()

    # Test 0: Check if manual nested-if works (to isolate transformation vs backend issue)
    result = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_nested_if")
    # Hits are sorted by relevancy (highest first), so:
    # hit[0] should be the document with relevancy=10000 (myrank=100)
    # hit[1] should be the document with relevancy=2500 (myrank=50)
    # hit[2] should be the document with relevancy=1 (myrank=1)
    assert_equal(10000, result.hit[0].field["relevancy"].to_i,
                 "NESTED-IF: First result should have relevancy 10000 (myrank=100)")
    assert_equal(2500, result.hit[1].field["relevancy"].to_i,
                 "NESTED-IF: Second result should have relevancy 2500 (myrank=50)")
    assert_equal(1, result.hit[2].field["relevancy"].to_i,
                 "NESTED-IF: Third result should have relevancy 1 (myrank=1)")
    assert_equal(0, result.hit[3].field["relevancy"].to_i,
                 "NESTED-IF: Fourth result should have relevancy 0 (default case)")

    # Test 1: Basic switch with exact matches
    result = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_basic") 
    # Hits are sorted by relevancy (highest first)
    assert_equal(10000, result.hit[0].field["relevancy"].to_i,
                 "First result should have relevancy 10000 (case 100)")
    assert_equal(2500, result.hit[1].field["relevancy"].to_i,
                 "Second result should have relevancy 2500 (case 50)")
    assert_equal(1, result.hit[2].field["relevancy"].to_i,
                 "Third result should have relevancy 1 (case 1)")
    assert_equal(0, result.hit[3].field["relevancy"].to_i,
                 "Fourth result should have relevancy 0 (default case)")

    # Test 2: Switch with boolean expressions (like if statement)
    result = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_ranges")
    result.hit.each_index do |i|
      myrank = result.hit[i].field["myrank"].to_i
      score = result.hit[i].field["relevancy"].to_i
      if myrank > 90
        expected = myrank * myrank
      else
        expected = myrank
      end
      assert_equal(expected, score,
                   "myrank=#{myrank} should give #{expected}, got #{score}")
    end

    # Test 3: Model selection use case (issue #33096)
    result = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_model_selection")
    assert_equal(1000, result.hit[0].field["relevancy"].to_i, "myrank=100 -> 1000")
    assert_equal(990, result.hit[1].field["relevancy"].to_i, "myrank=99 -> 990")
    assert_equal(980, result.hit[2].field["relevancy"].to_i, "myrank=98 -> 980")
    # Remaining hits should return myrank value (default case)
    result.hit[3..-1].each_index do |i|
      idx = i + 3
      myrank = result.hit[idx].field["myrank"].to_i
      score = result.hit[idx].field["relevancy"].to_i
      assert_equal(myrank, score, "myrank=#{myrank} should hit default")
    end

    # Test 4: Switch with computed discriminant
    # Note: The ranking expression does floating-point division: myrank / 10
    # Only values that divide evenly by 10 will match the case statements
    # (e.g., 100/10=10.0 matches case 10, but 97/10=9.7 doesn't match case 9)
    result = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_with_computation")
    result.hit.each_index do |i|
      myrank = result.hit[i].field["myrank"].to_i
      score = result.hit[i].field["relevancy"].to_i
      # Floating-point division result
      bucket_float = myrank / 10.0
      # Only exact integer results will match switch cases
      if bucket_float == bucket_float.to_i
        bucket = bucket_float.to_i
        expected = case bucket
                   when 10 then 100
                   when 9 then 90
                   when 5 then 50
                   when 1 then 10
                   else 0
                   end
      else
        # Non-integer result won't match any case, returns default
        expected = 0
      end
      assert_equal(expected, score,
                   "myrank=#{myrank} (bucket=#{bucket_float}) should give #{expected}")
    end

    # Test 5: Verify switch behaves identically to nested if
    result_switch = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_basic")
    result_if = search("query=sddocname:rankexpression&skipnormalizing&hits=100&ranking=switch_nested_if")
    # Both should produce the same relevancy scores at each position
    # (Note: documents with tied scores can be in any order, so we only check relevancy, not myrank)
    result_switch.hit.each_index do |i|
      switch_score = result_switch.hit[i].field["relevancy"].to_i
      if_score = result_if.hit[i].field["relevancy"].to_i
      assert_equal(if_score, switch_score,
                   "Switch and nested if should produce identical relevancy at position #{i}")
    end
    # Verify the top 3 results have the expected scores
    assert_equal(10000, result_switch.hit[0].field["relevancy"].to_i)
    assert_equal(2500, result_switch.hit[1].field["relevancy"].to_i)
    assert_equal(1, result_switch.hit[2].field["relevancy"].to_i)
    assert_equal(10000, result_if.hit[0].field["relevancy"].to_i)
    assert_equal(2500, result_if.hit[1].field["relevancy"].to_i)
    assert_equal(1, result_if.hit[2].field["relevancy"].to_i)
  end

  def indexData
    str ="[\n"
    0.upto(99) do |i|
      str += "{ \"id\": \"id:scheme:rankexpression::#{i}\", \"fields\": {"
      str += "  \"title\": \"document #{i}\", \"myrank\": #{100 - i} } }"
      unless (i == 99)
        str += ",\n"
      end
    end
    str += "]"
    puts str
    feed = File.open("#{dirs.tmpdir}/feed.json", "w")
    feed.print(str)
    feed.close()
    feed_and_wait_for_docs("rankexpression", 100, :file => "#{dirs.tmpdir}/feed.json")
  end

  def test_isnan
    set_description("Test that isNan function works")
    deploy_app(SearchApp.new.sd(selfdir + "isnan.sd"))
    start
    feed_and_wait_for_docs("isnan", 2, :file => selfdir + "isnan.json")
    assert_relevancy("query=sddocname:isnan&ranking=rp1", 31, 0)
    assert_relevancy("query=sddocname:isnan&ranking=rp1", 11, 1)
    assert_relevancy("query=sddocname:isnan&ranking=rp2", 32.2, 0)
    assert_relevancy("query=sddocname:isnan&ranking=rp2", 12,   1)
    assert_relevancy("query=sddocname:isnan&ranking=rp3", 33.3, 0)
    assert_relevancy("query=sddocname:isnan&ranking=rp3", 13,   1)
  end


end
