# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'
require 'environment'

class ManyManyHits < IndexedStreamingSearchTest

  def initialize(*args)
    super(*args)
    @gendata_app = "vespa-gen-testdocs"
    @numdocs = 10000
  end

  def timeout_seconds
    3600
  end

  def setup
    set_owner("arnej")
    set_description("Test with 'big' resultsets")
  end

  def generate_feed
    vespa.adminserver.
      execute("#{@gendata_app} gentestdocs " +
              "--basedir #{dirs.tmpdir} " +
              "--idtextfield id " +
              "--consttextfield a,a " +
              "--mindocid 0 " +
              "--docidlimit #{@numdocs} " +
              "--doctype test " +
              "--json feed.json")
  end

  def feed_docs
    generate_feed
    feed_and_wait_for_docs("test", @numdocs, :file => "#{dirs.tmpdir}/feed.json", :localfile => true)
  end

  def test_manymanyhits
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
                   search_dir(selfdir + "search"))
    start
    feed_docs

    timeout=30
    query = { 'query' => 'a:a', 'hits' => @numdocs.to_s }

    result = search_with_timeout(timeout, query)
    assert_equal(@numdocs, result.hitcount)
    assert_equal(@numdocs, result.hit.size)
    # Make local copy of result for use in inner loop
    local_result = Resultset.new(result.xmldata, result.query)
    for i in 0...@numdocs
      assert_equal(i, local_result.hit[i].field['id'])
    end
  end

  def test_manymanyhitsbutno
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_docs

    timeout=30
    query = { 'query' => 'a:a', 'hits' => @numdocs.to_i }

    result = search_with_timeout(timeout, query)
    assert_equal(0, result.hitcount)
    assert_equal(0, result.hit.size)
  end

  def teardown
    stop
  end

end
