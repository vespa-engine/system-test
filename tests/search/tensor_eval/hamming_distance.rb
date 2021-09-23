# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class HammingDistanceRankingTest < IndexedSearchTest

  def setup
    set_owner('arnej')
  end

  def gen_vec(start, inc)
    ax = start
    comma = false
    result = '['
    (0...16).each do
      result += ',' if comma
      comma = true
      result += ax.to_s
      ax += inc
    end
    result += ']'
    return result
  end

  def test_hamming_distance_ranking
    set_description('Test evaluation of hamming distance for various tensor combinations')
    hdir = selfdir + 'hamming/'
    deploy_app(SearchApp.new.sd(hdir + 'hamming.sd').search_dir(hdir + 'search'))
    start
    feed_and_wait_for_docs('hamming', 4, :file => hdir + 'docs.json')

    expect_scores = [55, 43, 32, 0, 63, 44, 35, 32, 92, 89, 82, 63]
    idx = 0

    [ 0, 1, -1 ].each do |increment|
      xv = gen_vec(0, increment)
      q = '?query=sddocname:hamming'
      q += '&ranking.features.query(just_x)=' + xv
      q += '&format=json'
      result = search(q)
      puts "Result for increment = #{increment}"
      foohit = nil
      result.hit.each do |hit|
        title = hit.field['title']
        score = hit.field['relevancy'].to_f
        puts "Hit with title #{title} and score #{score}"
        assert_equal(score, expect_scores[idx])
        idx = idx+1
        foohit = hit if title == 'foo'
      end
      #assert_equal(result.hit.size, 4)
      #lasthit = result.hit[3]
      sfs = foohit.field['summaryfeatures']
      out = sfs['rankingExpression(output_tensor)']
      #cell = out['cells'].first
      #puts "tensor type: #{out['type']} cell addr #{cell['address']} value #{cell['value']}"
      hdv = []
      out['cells'].each do |cell|
        hdv.append(cell['value'])
      end
      puts "Hamming distance vector for foo: #{hdv}"
    end
  end

  def teardown
    stop
  end

end
