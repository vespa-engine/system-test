# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'uri'

class RemoveDocTypeDuringFeed < IndexedOnlySearchTest

  class FeedResult
    attr_accessor :failed
    def initialize
      @failed = false
    end
  end

  def setup
    set_owner('toregge')
    set_description("Test removal of document type during feeding")
    @gendata_app = 'vespa-gen-testdocs'
    @numdocs = 200000
    @waitdocs = 10000
  end

  def get_app(both)
    sc = SearchCluster.new('test')
    sc.sd(selfdir + '/keep.sd')
    if both
      sc.sd(selfdir + '/remove.sd')
    end
    app = SearchApp.new.cluster(sc).validation_override('content-type-removal')
  end

  def gen_data(doctype)
    vespa.adminserver.
      execute("#{@gendata_app} gentestdocs --basedir #{dirs.tmpdir} " +
              '--idtextfield i1 ' +
              '--randtextfield i2 ' +
              '--numwords 1000 ' +
              '--mindocid 0 ' +
              "--docidlimit #{@numdocs} " +
              "--doctype #{doctype} " +
              "--json feed-#{doctype}.json")
  end

  def count_ignored_puts(output)
    lastlines = output.split("\n").last(10)
    ignored = 0
    for line in lastlines
      if line =~ /PutDocument:\s+ok:\s+\d+\s+msgs\/sec:\s+\S+\s+failed:\s+\d+\s+ignored:\s+(\d+)\s+/
        ignored = $1.to_i
      end
    end
    ignored
  end

  def feed_data(doctype, result)
    thread = Thread.new(doctype, result) do |doctype, result|
      begin
        puts "Feed data #{doctype} start"
        # Need to use vespa-feeder to be able to count ignored operations
        output = feedfile("#{dirs.tmpdir}/feed-#{doctype}.json",
                          :localfile => true, :timeout => 240, :client => :vespa_feeder)
        ignored = count_ignored_puts(output)
        if ignored > 0
          raise "#{ignored} ignored puts"
        end
      rescue Exception => e
        puts "Feed data #{doctype} got exception"
        puts e.message
        puts e.backtrace.inspect
        result.failed = true
      ensure
        puts "Feed data #{doctype} end"
      end
    end
    thread
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def hitcount_query_string(doctype)
    '/search/?' + URI.encode_www_form([['query', "sddocname:#{doctype}"],
                                      ['nocache'],
                                      ['hits', '0'],
                                      ['ranking', 'unranked'],
                                      ['timeout', '5.0'],
                                      ['model.restrict', doctype]
                                     ])
  end

  def hitcount(doctype)
    qrserver.search(hitcount_query_string(doctype)).hitcount
  end

  def test_remove_doctype_during_feed
    first_app = get_app(true)
    second_app = get_app(false)
    deploy_app(first_app)
    start
    puts 'Generating feed'
    gen_data('keep')
    gen_data('remove')
    feed_keep_result = FeedResult.new
    feed_remove_result = FeedResult.new
    puts 'Starting feed'
    feed_keep_thread = feed_data('keep', feed_keep_result)
    feed_remove_thread = feed_data('remove', feed_remove_result)
    puts "Waiting for #{@waitdocs} documents of doctype remove"
    100.times do
      remove_hitcount = hitcount('remove')
      puts "hitcount for doctype remove is #{remove_hitcount}"
      break if remove_hitcount >= @waitdocs
      sleep 1
    end
    redeploy(second_app)
    puts 'Waiting for feed to complete'
    feed_keep_thread.join
    feed_remove_thread.join
    puts 'Feed completed'
    assert(!feed_keep_result.failed, 'Feed of doctype keep should succeed')
    assert(feed_remove_result.failed, 'Feed of doctype remove should fail')
    puts 'Checking hitcount for doctype keep'
    assert_hitcount(hitcount_query_string('keep'), @numdocs)
    puts 'Checking that searchnode has been started once'
    assert_equal(1, assert_log_matches(/starting\/1\s+name="searchnode"/))
  end

  def teardown
    stop
  end
end
