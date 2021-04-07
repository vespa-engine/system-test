# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class TensorCellTypesTest < IndexedSearchTest

  def setup
    set_owner('arnej')
  end

  def test_tensor_evaluation
    set_description('Test tensor evaluation with various cell types')
    deploy_app(SearchApp.new.sd(selfdir + 'multi.sd').search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("multi", 3, :file => selfdir + "multi-docs.json")
    expect_scores = [ 525, 580, 330, 412.5, 475, 460, 270, 337.5, 350, 360, 220, 275, 200, 240, 160, 200 ]
    idx = 0
    [ "default", "w32bits", "w16bits", "w8bits" ].each do |rprofile|
      [ "kid", "adult" ].each do |qa|
        [ "f", "m" ].each do |qs|
            q = '?query=sddocname:multi'
            q += '&ranking.profile=' + rprofile
            q += '&ranking.features.query(age)={{age:' + qa + '}:1.5}'
            q += '&ranking.features.query(sex)={{sex:' + qs + '}:2.0}'
            result = search(q)
            assert_equal(result.hit.size, 1)
            puts "q(age=#{qa}, sex=#{qs}, #{rprofile}) : #{result.hit.size} hit, score: #{result.hit[0].field['relevancy']} / title: #{result.hit[0].field['title']}"
            assert_equal(result.hit[0].field['relevancy'].to_f, 3.0 * expect_scores[idx])
            idx += 1
        end
      end
    end
  end

  def teardown
    stop
  end

end
