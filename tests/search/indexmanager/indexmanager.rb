# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'search/indexmanager/indexmanagerdocgenerator'

IndexManagerConfig = Struct.new(:num_doc_sets, :num_puts, :num_removes, :num_updates, :num_unique_words)
IndexManagerFlushStats = Struct.new(:num_memory_index_flush, :num_disk_index_fusion, :num_trigger_flush, :fusion_during_last_flush)

class IndexManagerTest < IndexedOnlySearchTest
  
  def setup
    set_owner("geirst")
  end

  def timeout_seconds
    60*20
  end

  def test_index_flush_and_fusion_vespa_with_warmup
    set_description("Test the interaction between flush, fusion, and source selector when using Vespa index manager")
    run_index_flush_and_fusion_test(
        create_app("vespa").
            config(ConfigOverride.new("vespa.config.search.core.proton").
                add("index", ConfigValues.new.
                    add("warmup", ConfigValues.new.add("time",5)))))
  end

  def test_index_flush_and_fusion_vespa
    set_description("Test the interaction between flush, fusion, and source selector when using Vespa index manager")
    run_index_flush_and_fusion_test(create_app("vespa"))
  end

  def create_app(index_type)
    SearchApp.new.sd(selfdir+"#{index_type}/test.sd")
  end
  def run_index_flush_and_fusion_test(app)
    deploy_app(app)
    start
    @cfg = IndexManagerConfig.new(7, 23, 2, 3, 5)
    @gen = IndexManagerDocGenerator.new(@cfg.num_unique_words)
    @stats = IndexManagerFlushStats.new(0, 0, 0, false)

    # A document set consists of @cfg.num_puts unique documents.
    # The number of document sets are given by @cfg.num_doc_sets.
    # There is no document overlap between document sets.
    # The number of documents to remove in a document set is @cfg.num_removes (x2),
    # and the number of documents to update/re-feed in a document set is @cfg.num_updates (x2).
    # There are two (non-overlapping) sets of unique words used in the documents, one for puts and one for updates.
    # The number of unique words in each set is @cfg.num_unique_words.

    feed_puts(@gen.gen_puts(0, @cfg.num_puts), 0)

    for i in 1...@cfg.num_doc_sets do
      # put documents for document set i
      feed_puts(@gen.gen_puts(get_begin_doc_id(i), @cfg.num_puts), i)

      # feed removes and updates for document set i - 1
      doc_id = get_begin_doc_id(i - 1) + @cfg.num_removes + @cfg.num_updates
      feed_removes(@gen.gen_removes(doc_id, @cfg.num_removes), i - 1, 1)
      doc_id += @cfg.num_removes
      feed_updates(@gen.gen_updates(doc_id, @cfg.num_updates), i - 1, 1)

      # feed removes and updates for document set i
      doc_id = get_begin_doc_id(i)
      feed_removes(@gen.gen_removes(doc_id, @cfg.num_removes), i, 0)
      doc_id += @cfg.num_removes
      feed_updates(@gen.gen_updates(doc_id, @cfg.num_updates), i, 0)

      flush_and_verify
#      for i in 1...10
#          sleep 1
#          verify_corpus
#      end
    end
  end

  def feed_and_verify(file)
    puts "About to feed '#{file}'"
    feed(:file => file)
    verify_corpus
  end

  def flush_and_verify
    vespa.search["search"].first.trigger_flush
    verify_trigger_flush_count
    verify_memory_index_flush_count
    verify_disk_index_fusion_count
    verify_corpus
  end

  def verify_corpus
    query = "?query=sddocname:test"
    puts "Expects #{query} -> #{@gen.doc_count} hits"
    assert_hitcount(query, @gen.doc_count)
    @gen.words.sort.each do |word,docids|
      hitcount = docids.size
      query = "?wand.field=features&wand.tokens=%7B#{word}:1%7D&hits=400"
      puts "Expects #{query} -> #{hitcount} hits"
      result = search(query)
      assert_hitcount(result, hitcount)
      # descending sort that matches the default rank profile sort order
      sorted_docids = docids.sort {|x,y| y <=> x}
      sorted_docids.each_index do |i|
        exp_docid = sorted_docids[i]
        #puts "Expects hit[#{i}].documentid == #{exp_docid}"
        assert_equal(exp_docid, result.hit[i].field['documentid'])
      end
    end
  end

  def get_begin_doc_id(doc_set_id)
    return doc_set_id * @cfg.num_puts
  end

  def feed_puts(doc_set, doc_set_id)
    file = dirs.tmpdir + "feed-puts-#{doc_set_id}.xml"
    doc_set.write_xml(file)
    feed_and_verify(file)
  end

  def feed_removes(doc_set, doc_set_id, phase_id)
    file = dirs.tmpdir + "feed-removes-#{doc_set_id}-#{phase_id}.xml"
    doc_set.write_rm_xml(file)
    feed_and_verify(file)
  end

  def feed_updates(doc_set, doc_set_id, phase_id)
    file = dirs.tmpdir + "feed-updates-#{doc_set_id}-#{phase_id}.xml"
    doc_set.write_xml(file)
    feed_and_verify(file)
  end

  def verify_log_matches(regexp, exp_matches)
    puts "Expects #{regexp} -> #{exp_matches} matches"
    wait_for_log_matches(regexp, exp_matches)
  end

  def verify_trigger_flush_count
    @stats.num_trigger_flush += 1
    verify_log_matches(/.*Flush finished/, @stats.num_trigger_flush)
  end

  def verify_memory_index_flush_count
    @stats.num_memory_index_flush += 1
    verify_log_matches(/.*diskindex\.load\.complete.*index\.flush.*/, @stats.num_memory_index_flush)
    verify_log_matches(/.*flush\.complete.*memoryindex\.flush/, @stats.num_memory_index_flush)
  end

  def verify_disk_index_fusion_count
    load_regexp = /.*diskindex\.load\.complete.*index\.fusion.*/
    fusion_regexp = /.*fusion\.complete.*/
    load_count = vespa.logserver.log_matches(load_regexp)
    fusion_count = vespa.logserver.log_matches(fusion_regexp)
    puts "Expects #{load_regexp} (#{load_count} matches) == #{fusion_regexp} (#{fusion_count} matches)"
    assert_equal(load_count, fusion_count)
    count_diff = fusion_count - @stats.num_disk_index_fusion
    if @stats.num_trigger_flush == 2
      # 1) If the current memory index is flushed and loaded before fusion starts we get a fusion between flushed 1 and flushed 2 (+1).
      puts "Expects #{fusion_regexp} -> #{@stats.num_disk_index_fusion} (+1) matches"
      assert(count_diff == 0 || count_diff == 1)
    elsif @stats.num_trigger_flush > 2
      if @stats.fusion_during_last_flush
        # 2) If the last fusion used the last flushed memory index we do not get a fusion this time because we do not have enough inputs (-1).
        puts "Expects #{fusion_regexp} -> #{@stats.num_disk_index_fusion+1} (-1) matches"
        assert(count_diff == 0 || count_diff == 1)
      else
        # 3) We have enough inputs to do a fusion this time.
        puts "Expects #{fusion_regexp} -> #{@stats.num_disk_index_fusion+1} matches"
        assert_equal(1, count_diff)
      end
    end
    @stats.num_disk_index_fusion += count_diff
    @stats.fusion_during_last_flush = (count_diff == 1)
  end

  def teardown
    stop
  end
end
