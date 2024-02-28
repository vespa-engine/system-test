# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class InterpolatedLookupTest < IndexedOnlySearchTest

  def setup
    set_owner("arnej")
    set_description("perform interpolated lookup grouping operation")
    @@timeout = 2.0
  end

  def test_doc_example
    deploy_app(
        SearchApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               cluster(SearchCluster.new("multitest").
                      sd(selfdir+"sad.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("sad", 1, :file => selfdir+"feed-0.xml")
    # save_result("query=title:foo", selfdir+"example/foo.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo", selfdir+"example/foo.xml")

    grouping = "select=all%28group%28%22impressions%22%29each%28"
    grouping += "output%28count%28%29as%28uniqueusercount%29%29"
    grouping += "output%28sum%28interpolatedlookup%28pos1impr,relevance%28%29%29%29as%28totalinpos1%29%29"
    grouping += "output%28sum%28interpolatedlookup%28pos2impr,relevance%28%29%29%29as%28totalinpos2%29%29"
    grouping += "%29as%28impressiondata%29%29"

    # save_result("query=title:foo&#{grouping}", selfdir+"example/foo-grp.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}", selfdir+"example/foo-grp.xml")

    rpo = "rankfeature.query%28bid%29=0.420"
    # save_result("query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.420.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.420.xml")

    rpo = "ranking.features.query%28bid%29=0.490"
    # save_result("query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.490.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.490.xml")

    rpo = "rankfeature.query%28bid%29=0.111"
    # save_result("query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.111.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.111.xml")

    rpo = "rankfeature.query%28bid%29=0.200"
    # save_result("query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.200.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.200.xml")

    rpo = "rankfeature.query%28bid%29=0.205"
    # save_result("query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.205.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.205.xml")

    rpo = "rankfeature.query%28bid%29=0.208"
    # save_result("query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.208.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"example/foo-grp.208.xml")
  end

  def test_basic_lookup
    deploy_app(
        SearchApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               cluster(SearchCluster.new("multitest").
                      sd(selfdir+"sad.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("sad", 2, :file => selfdir+"feed-1.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:foo", selfdir+"small/result.foo.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:bar", selfdir+"small/result.bar.xml")

    grouping = "select=all%28group%28%22impressions%22%29each%28"
    grouping += "output%28count%28%29as%28uniqueusercount%29%29"
    grouping += "output%28sum%28interpolatedlookup%28pos1impr,relevance%28%29%29%29as%28totalinpos1%29%29"
    grouping += "output%28sum%28interpolatedlookup%28pos2impr,relevance%28%29%29%29as%28totalinpos2%29%29"
    grouping += "%29as%28impressiondata%29%29"

    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}", selfdir+"small/result.foo-grp.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:bar&#{grouping}", selfdir+"small/result.bar-grp.xml")

    for i in 0..9 do
      rpo = "rankfeature.query%28bid%29=#{i*0.111}"
      assert_xml_result_with_timeout(@@timeout, "query=title:bar&#{grouping}&#{rpo}", selfdir+"small/result.bar-grp.#{i}.xml")
      assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"small/result.foo-grp.#{i}.xml")

      rpo = "ranking.features.query%28bid%29=#{i*0.111}"
      assert_xml_result_with_timeout(@@timeout, "query=title:bar&#{grouping}&#{rpo}", selfdir+"small/result.bar-grp.#{i}.xml")
      assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"small/result.foo-grp.#{i}.xml")
    end
  end

  def test_big_lookup
    @valgrind = false
    deploy_app(
        SearchApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               cluster(SearchCluster.new("multitest").
                      sd(selfdir+"sad.sd").
                      threads_per_search(1).
                      indexing("mycc")))
    start

    node = vespa.adminserver

    node.copy(selfdir + "gendata.c", dirs.tmpdir)

    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out && #{tmp_bin_dir}/a.out > feed-2.xml")
    puts "compile output: #{output}"

    (exitcode, output) = execute(node, "vespa-feed-perf < #{dirs.tmpdir}/feed-2.xml")
    puts "feeder output: #{output}"

    wait_for_hitcount("sddocname:sad", 123456, 30)

    assert_xml_result_with_timeout(@@timeout, "query=title:foo", selfdir+"big/bigresult.foo.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:bar", selfdir+"big/bigresult.bar.xml")

    grouping = "select=all%28group%28%22impressions%22%29each%28"
    grouping += "output%28count%28%29as%28uniqueusercount%29%29"
    grouping += "output%28sum%28interpolatedlookup%28pos1impr,relevance%28%29%29%29as%28totalinpos1%29%29"
    grouping += "output%28sum%28interpolatedlookup%28pos2impr,relevance%28%29%29%29as%28totalinpos2%29%29"
    grouping += "%29as%28impressiondata%29%29"

    assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}", selfdir+"big/bigresult.foo-grp.xml")
    assert_xml_result_with_timeout(@@timeout, "query=title:bar&#{grouping}", selfdir+"big/bigresult.bar-grp.xml")

    for i in 0..9 do
      rpo = "rankfeature.query%28bid%29=#{i*0.111}"
      assert_xml_result_with_timeout(@@timeout, "query=title:bar&#{grouping}&#{rpo}", selfdir+"big/bigresult.bar-grp.#{i}.xml")
      assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"big/bigresult.foo-grp.#{i}.xml")

      rpo = "ranking.features.query%28bid%29=#{i*0.111}"
      assert_xml_result_with_timeout(@@timeout, "query=title:bar&#{grouping}&#{rpo}", selfdir+"big/bigresult.bar-grp.#{i}.xml")
      assert_xml_result_with_timeout(@@timeout, "query=title:foo&#{grouping}&#{rpo}", selfdir+"big/bigresult.foo-grp.#{i}.xml")
    end
  end

  def teardown
    stop
  end

end
