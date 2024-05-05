# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'
require 'json'
require 'rexml/document'
require 'search/partialupdate/attributetestcase'

class PartialUpdate < IndexedStreamingSearchTest

  @@fctr = Process.pid * 100

  def self.final_test_methods
    ['test_arithmetic_updates_with_undefined_values']
  end

  def setup
    set_owner("geirst")
  end

  def setup_realtime(paged)
    deploy_app(SearchApp.new.sd(paged ? selfdir + "paged/update.sd" : selfdir + "update.sd"))
    start
  end

  def feed_docs(file, exceptiononfailure = true)
    puts "feed_docs(#{file})"
    tmp_file = dirs.tmpdir + "realtime." + file
    File.open(tmp_file, "w") do |tmp|
      File.open(selfdir + file, "r") do |feed|
        while block = feed.read(50 * 1024 * 1024)
          tmp.write(block)
        end
      end
    end
    feed(:file => tmp_file, :exceptiononfailure => exceptiononfailure)
    File.delete(tmp_file) if File.exist?(tmp_file)
  end

  def poll_cmp(expected, timeout=30)
    query = "query=upd&nocache"
    sort_field = "intfield"
    fields_to_compare = ["intfield","longfield","bytefield","floatfield","doublefield"]
    poll_compare(query, selfdir + expected, sort_field, fields_to_compare, timeout)
  end

  def cmp(expected)
    assert_result("query=upd&nocache", selfdir + expected,
                  "intfield",
                  ["intfield","longfield","bytefield","floatfield","doublefield"])
  end

  def feed_and_check()
    # ignore partial updates
    feedfile(selfdir + "update.a.json")

    result = search("/?query=upd&nocache")
    assert_equal(0, result.hit.size)

    # new feed, documents and partial updates interleaved
    feedfile(selfdir + "update.b.json")
    feedfile(selfdir + "update.j.json")
    poll_cmp("update.b.result.json")

    # new feed, only documents
    feed_docs("update.c.json")
    poll_cmp("update.c.result.json")

    # apply partial updates
    feedfile(selfdir + "update.a.json")
    poll_cmp("update.a.result.json")

    # new feed, replace partial updates
    feed_docs("update.c.json")
    poll_cmp("update.c.result.json")

    # apply partial updates
    feedfile(selfdir + "update.a.json")
    poll_cmp("update.a.result.json")

    # apply more partial updates
    feedfile(selfdir + "update.d.json")
    poll_cmp("update.d.result.json")

    # apply partial updates for updateable fields
    feedfile(selfdir + "update.a.json")
    poll_cmp("update.a.result.json")
  end

  def feed_and_check_2()
    # new feed (increment 0)
    feed_docs("update.c.json")
    poll_cmp("update.c.result.json")

    # increment 1
    feed_docs("update.e.json")
    poll_cmp("update.e.result.json")

    # apply partial updates
    feedfile(selfdir + "update.f.json")
    poll_cmp("update.f.result.json")

    # increment 2
    feed_docs("update.g.json")
    poll_cmp("update.g.result.json")

    # apply partial updates
    feedfile(selfdir + "update.h.json")
    poll_cmp("update.h.result.json")
  end

  def run_test_realtime(paged)
    setup_realtime(paged)

    feed_and_check()
    feed_and_check_2()

    # remove all documents
    feedfile(selfdir+"update.k.json")
    poll_cmp("update.k.result.json", 60)

    # the searchnode should start up again with the correct sync token
    vespa.search["search"].first.softdie
    sleep 10

    feed_and_check_2()
  end

  def test_realtime
    run_test_realtime(false)
  end

  def test_realtime_paged
    run_test_realtime(true)
  end

  def test_indexed_attribute_summary
    deploy_app(SearchApp.new.sd(selfdir + "indexed.sd"))
    start
    feed_and_wait_for_docs("indexed", 1, :file => selfdir + "indexed.doc.json", :trace => 9)
    assert_hitcount('query=io:index io:only&nocache', 1)
    assert_hitcount('query=io:%22index only%22&nocache', 1)
    assert_hitcount('query=iso:%22index&7Csummary%22&nocache', 1)
    assert_hitcount('query=aiso:%22index&7Cattribute&7Csummary%22&nocache', 1)

    assert_hitcount('query=io:Updated&nocache', 0)
    assert_hitcount('query=iso:Updated&nocache', 0)
    assert_hitcount('query=aiso:Updated&nocache', 0)

    feed_and_wait_for_docs("indexed", 1, :file => selfdir + "indexed.doc2.json", :trace => 9)

    assert_hitcount('query=io:Initial&nocache', 0)
    assert_hitcount('query=io:Initial&nocache', 0)
    assert_hitcount('query=iso:Initial&nocache', 0)
    assert_hitcount('query=aiso:Initial&nocache', 0)

    assert_hitcount('query=io:Second&nocache', 1)
    assert_hitcount('query=iso:Second&nocache', 1)
    assert_hitcount('query=aiso:Second&nocache', 1)

    feed_and_wait_for_docs("indexed", 1, :file => selfdir + "indexed.update.json", :trace => 9)

    assert_hitcount('query=io:index io:only&nocache', 0)
    assert_hitcount('query=io:%22index only%22&nocache', 0)
    assert_hitcount('query=iso:%22index&7Csummary%22&nocache', 0)
    assert_hitcount('query=aiso:%22index&7Cattribute&7Csummary%22&nocache', 0)

    assert_hitcount('query=io:Second&nocache', 0)
    assert_hitcount('query=iso:Second&nocache', 0)
    assert_hitcount('query=aiso:Second&nocache', 0)

    assert_hitcount('query=io:io&nocache', 1)
    assert_hitcount('query=io:Updated&nocache', 1)
    assert_hitcount('query=iso:iso&nocache', 1)
    assert_hitcount('query=iso:Updated&nocache', 1)
    assert_hitcount('query=aiso:Updated&nocache', 1)
  end

  #---------------------------------------------------------------------------#
  #----------- Testing updates for all attribute vector types ----------------#
  #---------------------------------------------------------------------------#

  def index_multiple_files(files, exceptiononfailure = true)
    feeder_output = ""
    files.each do |file|
      feeder_output += feedfile(file, :exceptiononfailure => exceptiononfailure)
    end
    return feeder_output
  end

  def wait_for_hitcount_not_equal(query, wanted_hitcount)
    30.times do
      act_hitcount = search(query).hitcount
      if wanted_hitcount.to_i != act_hitcount
        break
      else
        sleep 1
        puts "'#{query}' returned #{wanted_hitcount} number of hits, expected not to. Retry query"
      end
    end
    act_hitcount = search(query).hitcount
    assert_not_equal(wanted_hitcount, act_hitcount, "Expected '#{query}' not to return #{wanted_hitcount} number of hits")
  end

  def feed_and_check_attribute_updates(test_case)

    pid = Process.pid
    doc_type = test_case.doc_type

    docs = dirs.tmpdir+"#{doc_type}docs.#{pid}.json"
    updates = dirs.tmpdir+"#{doc_type}updates.#{pid}.xml"
    max_doc = dirs.tmpdir+"#{doc_type}maxdoc.#{pid}.xml"
    result = dirs.tmpdir+"#{doc_type}result.#{pid}.xml"

    File.open(docs, "w") do |file|
      puts "generating #{docs}"
      test_case.generate_documents(file)
    end
    File.open(updates, "w") do |file|
      puts "generating #{updates}"
      test_case.generate_updates(file)
    end
    File.open(max_doc, "w") do |file|
      puts "generating #{max_doc}"
      test_case.generate_max_doc(file)
    end
    File.open(result, "w") do |file|
      puts "generating #{result}"
      test_case.generate_result(file)
    end

    # documents and partial updates interleaved to test indexing
    index_multiple_files([docs, updates, max_doc])
    wait_for_hitcount("/?query=sddocname:#{doc_type}", test_case.max_doc + 1)
    wait_for_hitcount_not_equal(test_case.check_docs_query, test_case.max_doc)
    puts "Query=" + test_case.query
    poll_compare(test_case.query + '&format=xml', result, test_case.sort_field, test_case.fields_to_compare, 30)

    # documents and partial updates separated to test fsearch
    index_multiple_files([docs])
    wait_for_hitcount("/?query=sddocname:#{doc_type}", test_case.max_doc + 1)
    wait_for_hitcount(test_case.check_docs_query, test_case.max_doc)
    feedfile(updates)
    wait_for_hitcount_not_equal(test_case.check_docs_query, test_case.max_doc)
    poll_compare(test_case.query + '&format=xml', result, test_case.sort_field, test_case.fields_to_compare, 30)

    # the searchnode should start up again in the same state
    vespa.search["search"].first.softdie
    vespa.search["search"].wait_until_ready
    wait_for_hitcount("/?query=sddocname:#{doc_type}", test_case.max_doc + 1)
    poll_compare(test_case.query + '&format=xml', result, test_case.sort_field, test_case.fields_to_compare, 30)
  end

  #----------------------------------------------------------------------------
  # Single Value Attributes
  #----------------------------------------------------------------------------
  def test_single_value_attribute
    deploy_app(SearchApp.new.sd(selfdir + "attrsingle.sd"))
    start
    feed_and_check_attribute_updates(SingleAttributeTestCase.new)
  end

  def test_single_value_attribute_summary
    deploy_app(SearchApp.new.sd(selfdir + "attrsinglesummary.sd"))
    start
    feed_and_check_attribute_updates(SingleAttributeSummaryTestCase.new)
  end

  def x_test_single_value_attribute_extra
    set_description("Test several arithmetic operations on the same field inside a document update (tracked in ticket #1217479)")
    deploy_app(SearchApp.new.sd(selfdir + "attrsingle.sd"))
    start
    feed_and_check_attribute_updates(SingleAttributeTestCaseExtra.new)
  end

  #----------------------------------------------------------------------------
  # Array Attributes
  #----------------------------------------------------------------------------
  def test_array_attribute
    deploy_app(SearchApp.new.sd(selfdir + "attrarray.sd"))
    start
    feed_and_check_attribute_updates(ArrayAttributeTestCase.new)
  end

  def test_array_attribute_summary
    deploy_app(SearchApp.new.sd(selfdir + "attrarraysummary.sd"))
    start
    feed_and_check_attribute_updates(ArrayAttributeSummaryTestCase.new)
  end

  def x_test_array_attribute_extra
    set_description("Test assign and add on the same field inside a document update (tracked in ticket #1217486)")
    deploy_app(SearchApp.new.sd(selfdir + "attrarray.sd"))
    start
    feed_and_check_attribute_updates(ArrayAttributeTestCaseExtra.new)
  end

  #----------------------------------------------------------------------------
  # Weighted Set Attributes
  #----------------------------------------------------------------------------
  def test_weightedset_attribute
    deploy_app(SearchApp.new.sd(selfdir + "attrweightedset.sd"))
    start
    feed_and_check_attribute_updates(WeightedSetAttributeTestCase.new)
  end

  def test_weightedset_attribute_summary
    deploy_app(SearchApp.new.sd(selfdir + "attrweightedsetsummary.sd"))
    start
    feed_and_check_attribute_updates(WeightedSetAttributeSummaryTestCase.new)
  end


  def test_feed_error
    deploy_app(SearchApp.new.sd(selfdir + "attrerror.sd"))
    start

    feed(:file => selfdir + "attrerrordocs.json")
    output = feedfile(selfdir + "attrerrorupdates.json", :exceptiononfailure => false, :stderr => true)

    puts "\nFeeder output:\n#{output}\n"

    # check output
    tofind = ".*Expected start of composite, got VALUE_NUMBER_INT*"
    assert(Regexp.new(tofind).match(output), "Did not find in feeder output: #{tofind}")
  end

  def test_arithmetic_updates_with_undefined_values
    @params = { :search_type => 'INDEXED' }
    set_description("Check that arithmetic updates are ignored if the current value is undefined")
    deploy_app(SearchApp.new.sd(selfdir + "attrundefined.sd"))
    start
    feed(:file => selfdir + "attrundefineddocs.json")
    wait_for_hitcount("query=sddocname:attrundefined&nocache", 1)

    poll_compare("query=sddocname:attrundefined&nocache", selfdir + "attrundefinedresult.xml", nil, \
                 ["sbyte", "sint", "slong", "sfloat", "sdouble", "documentid"], 5)
    feedfile(selfdir + "attrundefinedupdates.json")
    poll_compare("query=sddocname:attrundefined&nocache", selfdir + "attrundefinedresult.xml", nil, \
                 ["sbyte", "sint", "slong", "sfloat", "sdouble", "documentid"], 5)
  end

  #----------------------------------------------------------------------------
  # Complex partial updates in index & summary fields
  #----------------------------------------------------------------------------
  def test_index_and_summary_update_simultaneously
    set_description('Test that we can update an index and a summary field simultaneously in the same update')
    deploy_app(SearchApp.new.sd(selfdir + 'complex.sd'))
    start
    feed_and_wait_for_docs('complex', 1, :file => selfdir + 'complex.doc.json')
    result = search('query=sddocname:complex&nocache')
    assert_equal(1, result.hitcount)
    assert_equal('bbb', result.hit[0].field['fb'])
    assert_equal('ccc', result.hit[0].field['fc'])
    feed(:file => selfdir + 'complex.update.0.json')
    assert_hitcount('query=fa:eee', 1)
    result = search('query=sddocname:complex&nocache')
    assert_equal(1, result.hitcount)
    assert_equal('fff', result.hit[0].field['fb'])
    feed(:file => selfdir + 'complex.update.1.json')
    result = search('query=sddocname:complex&nocache')
    assert_equal(1, result.hitcount)
    assert_equal('ggg', result.hit[0].field['fc'])
    assert_hitcount('query=fd:hhh', 1)
  end

  def test_two_index_updates_one_by_one
    set_description("Test that we can update two indexed fields one by one")
    deploy_app(SearchApp.new.sd(selfdir + "complex.sd"))
    start
    feed_and_wait_for_docs("complex", 1, :file => selfdir + "complex.doc.json")
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fa:eee&nocache", 0)
    assert_hitcount("query=fd:ddd&nocache", 1)
    assert_hitcount("query=fd:hhh&nocache", 0)
    feed(:file => selfdir + "complex.update.2.json")
    assert_hitcount("query=fa:aaa&nocache", 0)
    assert_hitcount("query=fa:eee&nocache", 1)
    assert_hitcount("query=fd:ddd&nocache", 1)
    assert_hitcount("query=fd:hhh&nocache", 0)
    feed(:file => selfdir + "complex.update.3.json")
    assert_hitcount("query=fa:aaa&nocache", 0)
    assert_hitcount("query=fa:eee&nocache", 1)
    assert_hitcount("query=fd:ddd&nocache", 0)
    assert_hitcount("query=fd:hhh&nocache", 1)
    proton = vespa.search["search"].first
    proton.trigger_flush
    sleep 4
    proton.softdie
    vespa.search["search"].wait_until_ready
    wait_for_hitcount("/?query=sddocname:complex", 1);
    assert_hitcount("query=fa:aaa&nocache", 0)
    assert_hitcount("query=fa:eee&nocache", 1)
    assert_hitcount("query=fd:ddd&nocache", 0)
    assert_hitcount("query=fd:hhh&nocache", 1)
  end

  def test_same_index_update_twice
    set_description("Test that we can feed the same index update twice")
    deploy_app(SearchApp.new.sd(selfdir + "complex.sd"))
    start
    feed_and_wait_for_docs("complex", 1, :file => selfdir + "complex.doc.json")
    feed(:file => selfdir + "complex.update.2.json")
    feed(:file => selfdir + "complex.update.2.json")
    assert_hitcount("query=fa:eee", 1)
  end

  def test_array_index_update
    set_description("Test that non-idempotent update is applied once")
    deploy_app(SearchApp.new.sd(selfdir + "indexarray.sd"))
    start
    feed_and_wait_for_docs("indexarray", 1,
	 :file => selfdir + "indexarray.doc.json")
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fa:bbb&nocache", 1)
    assert_hitcount("query=fa:ccc&nocache", 0)
    assert_fieldcount("fa", "fa:aaa", 1.0, 0)
    assert_fieldcount("fa", "fa:bbb", 2.0, 0)
    feed(:file => selfdir + "indexarray.update.0.json")
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fa:bbb&nocache", 1)
    assert_hitcount("query=fa:ccc&nocache", 1)
    assert_fieldcount("fa", "fa:aaa", 1.0, 0)
    assert_fieldcount("fa", "fa:bbb", 4.0, 0)
    assert_fieldcount("fa", "fa:ccc", 1.0, 0)
    proton = vespa.search["search"].first
    proton.trigger_flush
    sleep 4
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fa:bbb&nocache", 1)
    assert_hitcount("query=fa:ccc&nocache", 1)
    assert_fieldcount("fa", "fa:aaa", 1.0, 0)
    assert_fieldcount("fa", "fa:bbb", 4.0, 0)
    assert_fieldcount("fa", "fa:ccc", 1.0, 0)
    proton.softdie
    vespa.search["search"].wait_until_ready
    wait_for_hitcount("/?query=sddocname:indexarray", 1);
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fa:bbb&nocache", 1)
    assert_hitcount("query=fa:ccc&nocache", 1)
    assert_fieldcount("fa", "fa:aaa", 1.0, 0)
    assert_fieldcount("fa", "fa:bbb", 4.0, 0)
    assert_fieldcount("fa", "fa:ccc", 1.0, 0)
  end

  def assert_fieldcount(field, query, score, docid=0)
    query = "query=" + query + "&nocache"
    result = search(query)
    result.sort_results_by("documentid")
    pexp = {}
    pexp["fieldInfo(#{field}).cnt"] = score
    puts "#{result.hit[docid].field["summaryfeatures"]}"
    assert_features(pexp, result.hit[docid].field['summaryfeatures'], 1e-4)
  end

  def assert_attrfieldcount(field, query, score, docid=0)
    query = "query=" + query + "&nocache"
    result = search(query)
    result.sort_results_by("documentid")
    pexp = {}
    pexp["attributeMatch(#{field}).matches"] = score
    puts "#{result.hit[docid].field["summaryfeatures"]}"
    assert_features(pexp, result.hit[docid].field['summaryfeatures'], 1e-4)
  end

  def assert_attrfieldcount_kludge(field, query, score, docid=0)
    query = "query=" + query + "&nocache"
    result = search(query)
    result.sort_results_by("documentid")
    pexp = {}
    pexp["attribute(#{field}).count"] = score
    puts "#{result.hit[docid].field["summaryfeatures"]}"
    assert_features(pexp, result.hit[docid].field['summaryfeatures'], 1e-4)
  end

  def transfer_fbench_queries(query_dir)
    Dir.glob("#{query_dir}/*.txt").each do |file|
      local_file = vespa.logserver.fetchfiles(:file => file)[0]
      @remote_query_dir = File.dirname(local_file)
    end
  end

  def create_fbench_thread
    fbench_command = "vespa-fbench -D -n 1 -c 0 -s 20 -q #{@remote_query_dir}/query-%03d.txt localhost #{vespa.container.values.first.http_port}"
    puts "########## create fbench thread ##########"
    thread = Thread.new(vespa.logserver, fbench_command) do |execute_object, command|
      execute_object.execute(command)
    end
    return thread
  end

  def test_compaction
    set_description("Test that updates don't fail due to slow search")
    deploy_app(SearchApp.new.sd(selfdir + "compaction.sd").
                 container(Container.new.component(AccessLog.new("disabled")).
                             search(Searching.new).
                             docproc(DocumentProcessing.new)))
    start
    proton = vespa.search["search"].first
    transfer_fbench_queries(selfdir + "slowqueries")
    feed_and_wait_for_docs("compaction", 1,
	 :file => selfdir + "compaction.doc.json")
    @fbench_thread = create_fbench_thread
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fb:bbb&nocache", 1)
    assert_hitcount("query=fb:ccc&nocache", 0)
    assert_hitcount("query=fb:ddd55&nocache", 0)
    feed(:file => selfdir + "compaction.update.0.json")
    assert_hitcount("query=fa:aaa&nocache", 1)
    assert_hitcount("query=fb:bbb&nocache", 0)
    assert_hitcount("query=fb:ccc&nocache", 1)
    assert_hitcount("query=fb:ddd55&nocache", 1)
    # XXX: should work
    # assert_attrfieldcount("fb", "fb:ddd*", 55.0, 00)
    # XXX: seems wrong
    assert_attrfieldcount("fb", "fb:ddd*", 1.0, 0)
    # XXX: should work
    # assert_fieldcount("fb", "fb:ddd*", 55.0, 0)
    # XXX: seems wrong
    assert_fieldcount("fb", "fb:ddd*", 1.0, 0)
    # XXX: should work
    # assert_attrfieldcount("fb", "fb:ccc", 55.0, 0)
    # XXX: seems wrong
    assert_attrfieldcount("fb", "fb:ccc", 1.0, 0)
    # XXX: should work
    # assert_fieldcount("fb", "fb:ccc", 55.0, 0)
    # XXX: seems wrong
    assert_fieldcount("fb", "fb:ccc", 1.0, 0)
    assert_attrfieldcount_kludge("fb", "fb:ccc", 110.0, 0)
    @fbench_thread.join
  end

  def test_disappearing_tensor
    set_description('ensure tensor does not disappear')
    deploy_app(SearchApp.new.sd(selfdir + 'hnsw_search.sd'))
    start
    feed_and_wait_for_docs('hnsw_search', 1, :file => selfdir + 'doc_hnsw.json')
    assert_hitcount('query=my_title:abc', 1)
    assert_result('query=my_title:abc', selfdir + 'res_hnsw_1.json')
    feedfile(selfdir + 'up_hnsw_1.json')
    assert_result('query=my_title:abc', selfdir + 'res_hnsw_2.json')
    feedfile(selfdir + 'up_hnsw_2.json')
    assert_result('query=my_title:abc', selfdir + 'res_hnsw_3.json')
  end

  def teardown
    stop
  end

end
