# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'search/utils/elastic_doc_generator'
require 'document'
require 'document_set'
require 'thread'
require 'fileutils'

class StableActiveCount < SearchTest

  def setup
    @valgrind = false
    set_owner('vekterli')
    FileUtils.rm_rf('generated')
    FileUtils.mkdir('generated')
  end

  def teardown
    FileUtils.rm_rf('generated')
    stop
  end

  def timeout_seconds
    60*20
  end

  def create_app
    SearchApp.new.sd(selfdir+'test.sd').
      search_type("ELASTIC").
      cluster_name("mycluster").
      num_parts(4).redundancy(2).ready_copies(2).
      storage(StorageCluster.new("mycluster", 4).
              distribution_bits(8).
              bucket_split_count(5))
  end

  class SearchRunner
    attr_reader :bad_searches
    attr_accessor :expected_hitcount, :search_term, :searches_run, :error_stats
    def initialize(test)
      @test = test
      @m = Mutex.new
      @done = false
      @bad_searches = []
      @expected_hitcount = 0
      @search_term = 'foo'
      @searches_run = 0
      @error_stats = {
        :min => 1000000000,
        :max => 0,
        :sum => 0,
        :avg => 0
      }
    end

    def mark_done
      @m.synchronize {
        @done = true
      }
    end

    def is_done?
      @m.synchronize {
        @done
      }
    end

    def get_query
      "query=f1:#{@search_term}&nocache&hits=0"
    end

    def add_to_error_stats(hitcount)
      @error_stats[:sum] += hitcount
      @error_stats[:min] = [@error_stats[:min], hitcount].min
      @error_stats[:max] = [@error_stats[:max], hitcount].max
    end

    def should_record_more_errors?
      @bad_searches.size < 1000
    end

    def do_search(start_time)
      hitcount = @test.search(get_query).hitcount
      if hitcount != @expected_hitcount && should_record_more_errors?
        @bad_searches << [Time.now - start_time, hitcount]
        add_to_error_stats(hitcount)
      end
      @searches_run += 1
    end

    def run
      start_time = Time.now
      while !is_done?
        do_search(start_time)
        sleep 0.50
      end
      @error_stats[:avg] = @error_stats[:sum] / @bad_searches.size.to_f
    end
  end

  def launch_search_threads(n_threads, expected_hitcount)
    threads = []
    runners = []
    n_threads.times do |i|
      runners << SearchRunner.new(self)
      threads << Thread.new {
        r = runners[i]
        r.expected_hitcount = expected_hitcount
        r.search_term = 'hello'
        r.run
      }
    end
    [threads, runners]
  end

  def verify_runners(runners, expected_hit_count)
    runners.each do |r|
      assert r.searches_run > 0
      puts "Search runner performed #{r.searches_run} searches"
      if !r.bad_searches.empty?
        puts r.bad_searches.inspect
        err = r.error_stats
        flunk("Expected a stable hit count of #{expected_hit_count} during " +
              "splitting, but got at least #{r.bad_searches.size} " +
              "discrepancies out of #{r.searches_run} searches run " +
              "(min=#{err[:min]}, max=#{err[:max]}, avg=#{err[:avg]})")
      end
    end
  end

  def test_hitcount_stable_during_splitting_within_node
    set_description('Test that hit counts do not fluctuate due to bucket ' +
                    'activations during splitting when these ' +
                    'splits do not go over the limit where docs start getting ' +
                    'merged across to other nodes.')

    deploy_app(create_app)
    start

    puts "Generating feed 1"
    first_pass_docs = 100_000
    content = { :field1 => 'hello', :field2 => '2000' }
    feed_file_1 = "#{dirs.tmpdir}1stfeed.xml"
    ElasticDocGenerator.write_docs(0, first_pass_docs,
                                   feed_file_1, content)

    puts "Generating feed 2"
    second_pass_docs = 200_000
    content = { :field1 => 'world', :field2 => '2001' }
    feed_file_2 = "#{dirs.tmpdir}2ndfeed.xml"
    ElasticDocGenerator.write_docs(first_pass_docs, second_pass_docs,
                                   feed_file_2, content)

    puts "Feeding first feed"
    feed(:file => feed_file_1)

    search_threads = 6
    threads, runners = launch_search_threads(search_threads, first_pass_docs)

    puts "Feeding second feed"
    feed(:file => feed_file_2)

    puts "Shutting down runner threads"
    runners.each { |r| r.mark_done }
    threads.each { |t| t.join }

    verify_runners(runners, first_pass_docs)
  end

end
