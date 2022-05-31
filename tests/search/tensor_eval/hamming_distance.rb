# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class HammingDistanceRankingTest < IndexedSearchTest

  def setup
    set_owner('arnej')
  end

  def verify_rankscores(queryvector, expected_scores)
    foohit = nil
    q = '?query=sddocname:hamming'
    q += '&ranking.features.query(qvector)=' + queryvector
    q += '&format=json'
    result = search(q)
    puts "Result for query vector #{queryvector} (#{result.hit.size} hits)"
    assert_equal(result.hit.size, 4)
    result.hit.each do |hit|
      title = hit.field['title']
      score = hit.field['relevancy'].to_f
      want = expected_scores[title]
      puts "Hit with title #{title} and score #{score}, expected #{want}"
      assert_equal(score, want)
      foohit = hit if title == 'foo'
    end
    if foohit
      sfs = foohit.field['summaryfeatures']
      out = sfs['output_tensor']
      hdv = []
      out['cells'].each do |cell|
        hdv.append(cell['value'])
      end
      puts "Hamming distance vector for foo: #{hdv}"
    end
  end

  def test_hamming_distance_ranking
    set_description('Test evaluation of hamming distance for various tensor combinations')
    hdir = selfdir + 'hamming/'
    deploy_app(SearchApp.new.sd(hdir + 'hamming.sd'))
    start
    feed_and_wait_for_docs('hamming', 4, :file => hdir + 'docs.json')
    q_and_a = {
      '[0,0,0,0,0,0,0,0]' => { 'foo' => 0, 'bar' => 8, 'baz' => 64, 'qux' => 8 },
      '[1,1,1,1,3,3,3,3]' => { 'foo' => 12, 'bar' => 4, 'baz' => 52, 'qux' => 18 },
      '[1,3,7,15,31,63,127,255]' => { 'foo' => 36, 'bar' => 28, 'baz' => 28, 'qux' => 28 },
      '[11,13,15,17,19,21,23,25]' => { 'foo' => 25, 'bar' => 17, 'baz' => 39, 'qux' => 27 },
    }
    q_and_a.each_pair do |q,a|
      verify_rankscores(q, a)
    end
  end

  def teardown
    stop
  end

end
