# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Tuning < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_basic_tuning
    set_description("Test that tuning can be specified in services.xml and that we get a working system afterwards")
    deploy_app(SearchApp.new.cluster(SearchCluster.new('test').
               sd(selfdir + "test.sd").tune_searchnode(
                 { :requestthreads => {:search => 8, :summary => 4 },
                   :flushstrategy => {:native => { :total => {:maxmemorygain => 200000000, :diskbloatfactor => 0.3},
                                                   :component => {:maxmemorygain => 10000000, :diskbloatfactor => 0.4, :maxage => 3600 },
                                                   :transactionlog => {:maxsize => 32000 }
                                                 } },
                   :index => {:io => {:search => :mmap } },
                   :summary => { :io => { :read =>:directio},
                                 :store => { :cache => { :maxsize => 8192,
                                                         :compression => {:type => :lz4, :level => 8}
                                                       },
                                             :logstore => { :maxfilesize => 16384,
                                                           :chunk => { :maxsize => 1024,
                                                                       :compression => {:type => :none, :level => 0}
                                                                     }
                                                         }
                                           }
                               }
                 } )))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.xml")
    assert_hitcount("f1:c", 2)
    assert_hitcount("f2:foo", 1)
  end

  def teardown
    stop
  end

end
