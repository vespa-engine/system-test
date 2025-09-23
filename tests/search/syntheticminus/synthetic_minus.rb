# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class SyntheticMinus < IndexedStreamingSearchTest

  def timeout_seconds
    return 800
  end

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def each_comb(left, cnt, prefix = [], &proc)
    if (cnt == 0)
      proc.call(prefix)
    else
      left.each_index do |i|
        p = prefix + [left[i]]
        l = left[0...i] + left[i+1..-1]
        each_comb(l, cnt - 1, p, &proc)
      end
    end
  end

  def test_synthetic_minus
    feed_and_wait_for_docs("music", 64, :file => selfdir+"minus.docs.json")

    puts "searching combinations 1..."
    each_comb(["use", "the", "force", "luke"], 2) do |words|
      assert_hitcount("query=#{words[0]}+-#{words[1]}&type=all", 11)
      assert_hitcount("query=-#{words[0]}+#{words[1]}&type=all", 11)
    end

    puts "searching combinations 2..."
    each_comb(["use", "the", "force", "luke"], 3) do |words|
      assert_hitcount("query=-#{words[0]}+#{words[1]}+#{words[2]}&type=all", 8)
      assert_hitcount("query=#{words[0]}+-#{words[1]}+#{words[2]}&type=all", 8)
      assert_hitcount("query=#{words[0]}+#{words[1]}+-#{words[2]}&type=all", 8)

      assert_hitcount("query=-#{words[0]}+-#{words[1]}+#{words[2]}&type=all", 3)
      assert_hitcount("query=#{words[0]}+-#{words[1]}+-#{words[2]}&type=all", 3)
      assert_hitcount("query=-#{words[0]}+#{words[1]}+-#{words[2]}&type=all", 3)
    end

    puts "searching combinations 3..."
    each_comb(["use", "the", "force", "luke"], 4) do |words|
      assert_hitcount("query=-#{words[0]}+#{words[1]}+#{words[2]}+#{words[3]}&type=all", 6)
      assert_hitcount("query=#{words[0]}+-#{words[1]}+#{words[2]}+#{words[3]}&type=all", 6)
      assert_hitcount("query=#{words[0]}+#{words[1]}+-#{words[2]}+#{words[3]}&type=all", 6)
      assert_hitcount("query=#{words[0]}+#{words[1]}+#{words[2]}+-#{words[3]}&type=all", 6)

      assert_hitcount("query=-#{words[0]}+-#{words[1]}+#{words[2]}+#{words[3]}&type=all", 2)
      assert_hitcount("query=-#{words[0]}+#{words[1]}+-#{words[2]}+#{words[3]}&type=all", 2)
      assert_hitcount("query=-#{words[0]}+#{words[1]}+#{words[2]}+-#{words[3]}&type=all", 2)
      assert_hitcount("query=#{words[0]}+-#{words[1]}+-#{words[2]}+#{words[3]}&type=all", 2)
      assert_hitcount("query=#{words[0]}+-#{words[1]}+#{words[2]}+-#{words[3]}&type=all", 2)
      assert_hitcount("query=#{words[0]}+#{words[1]}+-#{words[2]}+-#{words[3]}&type=all", 2)

      assert_hitcount("query=#{words[0]}+-#{words[1]}+-#{words[2]}+-#{words[3]}&type=all", 1)
      assert_hitcount("query=-#{words[0]}+#{words[1]}+-#{words[2]}+-#{words[3]}&type=all", 1)
      assert_hitcount("query=-#{words[0]}+-#{words[1]}+#{words[2]}+-#{words[3]}&type=all", 1)
      assert_hitcount("query=-#{words[0]}+-#{words[1]}+-#{words[2]}+#{words[3]}&type=all", 1)

      assert_hitcount("query=-#{words[0]}+-#{words[1]}+-#{words[2]}+-#{words[3]}&type=all", 0)
    end

    puts "done."
  end


end
