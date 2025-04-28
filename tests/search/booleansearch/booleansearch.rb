# Copyright Vespa.ai. All rights reserved.
require 'base64'
require 'document_set'
require 'indexed_only_search_test'
require 'json'

class BooleanSearchTest < IndexedOnlySearchTest

  def setup
    set_owner("bjorncs")
    set_description("Test boolean search with native predicate datatype")

    @feed_file = dirs.tmpdir + "boolean_feed.tmp"
    @update_file = dirs.tmpdir + "boolean_update.tmp"
    @numdocs = 0
  end

  def timeout_seconds
    1800
  end

  def deploy_and_feed()
    deploy_and_feed_file(@feed_file)
  end 

  def deploy_and_start()
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
        container(Container.new("combinedcontainer").
            search(Searching.new).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new)))
    start
  end

  def deploy_and_feed_file(file)
    deploy_and_start()
    feed_and_wait_for_docs("test", @numdocs, :file => file)
  end

  def flush_predicate_attribute
    vespa.search["search"].first.trigger_flush
    wait_for_log_matches(/.*flush\.complete.*attribute\.flush\.predicate_field/, 1)
  end

  def restart_proton_helper
    exp_hits = search({'query' => 'sddocname:test', 'hits' => '0'}).hitcount
    restart_proton('test', exp_hits, skip_trigger_flush: true)
  end

  def teardown
    File.delete(@feed_file) if File.exist?(@feed_file)
    File.delete(@update_file) if File.exist?(@update_file)
    stop
  end

  def generate_doc(id, predicate, field_names = ["predicate_field"])
    @numdocs += 1
    doc = Document.new("id:test:test::#{id}")
    if predicate
      for field_name in field_names
        doc.add_field(field_name, predicate)
      end
    end
    doc
  end

  def generate_update(id, predicate, field_names = ["predicate_field"])
    upd = DocumentUpdate.new("test", "id:test:test::#{id}")
    for field_name in field_names
      upd.addOperation("assign", field_name, predicate)
    end
    upd
  end

  def generate_value_documents()
    docs = DocumentSet.new
    docs.add(generate_doc("female", "gender in [Female]"))
    docs.add(generate_doc("male", "gender in [Male]"))
    docs.add(generate_doc("not male", "gender not in [Male]"))
    docs.add(generate_doc("female-NO", "gender in [Female] or country in [Norway]"))
    docs.add(generate_doc("female-SE", "gender in [Female] or country in [Sweden]"))
    docs.add(generate_doc("female-DK", "gender in [Female] or country in [Denmark]"))
    docs.add(generate_doc("male-NO", "gender in [Male] or country in [Norway]"))
    docs.add(generate_doc("male-JP", "gender in [Male] or country in ['日本']"))
    docs.add(generate_doc("male-GB", "gender in [Male] or country in ['Great Britain']"))
    docs.add(generate_doc("second field", "gender in [Female]", ["second_predicate"]))
    docs.add(generate_doc("not-female-or-NO", "not(gender in [Female] or country in [Norway])"))
    docs
  end

  def write_value_documents(file)
    generate_value_documents().write_json(file)
  end

  def test_issue_18637()
    deploy_and_start()
    feedfile(selfdir + "issue_18637.feed.1.json")
    assert_hitcount("?query=sddocname:test", 4)
    assert_search('{}', '{"value":100}', ["1"], "predicate_field")
    assert_search('{}', '{"value":101}', [], "predicate_field")
    assert_search('{}', '{"value":1000}', ["2"], "predicate_field")
    assert_search('{}', '{"value":1001}', ["2"], "predicate_field")
    assert_search('{}', '{"value":1002}', [], "predicate_field")
    assert_search('{}', '{"value":10}', ["3"], "predicate_field")
    assert_search('{}', '{"value":11}', ["3"], "predicate_field")
    assert_search('{}', '{"value":12}', [], "predicate_field")
    assert_search('{}', '{"value":1}', ["4"], "predicate_field")
    assert_search('{}', '{"value":2}', [], "predicate_field")
    feedfile(selfdir + "issue_18637.feed.2.json")
    assert_hitcount("?query=sddocname:test", 4)
    assert_search('{}', '{"value":200}', ["1"], "predicate_field")
    assert_search('{}', '{"value":201}', [], "predicate_field")
    assert_search('{}', '{"value":2000}', ["2"], "predicate_field")
    assert_search('{}', '{"value":2001}', ["2"], "predicate_field")
    assert_search('{}', '{"value":2002}', [], "predicate_field")
    assert_search('{}', '{"value":20}', ["3"], "predicate_field")
    assert_search('{}', '{"value":21}', [], "predicate_field")
    assert_search('{}', '{"value":2}', ["4"], "predicate_field")
    assert_search('{}', '{"value":3}', ["4"], "predicate_field")
    assert_search('{}', '{"value":4}', [], "predicate_field")

    assert_search('{}', '{"value":10}', [], "predicate_field")
    assert_search('{}', '{"value":11}', [], "predicate_field")
    assert_search('{}', '{"value":101}', [], "predicate_field")
    assert_search('{}', '{"value":1000}', [], "predicate_field")
    assert_search('{}', '{"value":1001}', [], "predicate_field")
    assert_search('{}', '{"value":1002}', [], "predicate_field")

    assert_search('{}', '{"value":1}', [], "predicate_field") # This gives an incorrect match.
    assert_search('{}', '{"value":100}', [], "predicate_field") # This gives an incorrect match.
  end

  def test_put_remove_put_of_single_point()
    deploy_and_start()
    feedfile(selfdir + "issue_18637.point.7.json")
    assert_hitcount("?query=sddocname:test", 1)
    assert_search('{}', '{"value":7}', ["1"], "predicate_field")

    feedfile(selfdir + "issue_18637.remove.json")
    assert_hitcount("?query=sddocname:test", 0)
    assert_search('{}', '{"value":7}', [], "predicate_field")

    feedfile(selfdir + "issue_18637.point.8.json")
    assert_hitcount("?query=sddocname:test", 1)
    assert_search('{}', '{"value":8}', ["1"], "predicate_field")
    assert_search('{}', '{"value":7}', [], "predicate_field")
  end

  def test_that_rankfeatures_does_not_core
    write_value_documents(@feed_file)
    deploy_and_feed
    assert_hitcount_with_timeout(1, "query=sddocname:test&rankfeatures", @numdocs)
  end

  def test_boolean_searcher_value_query_terms
    write_value_documents(@feed_file)
    deploy_and_feed

    run_value_query_terms_test
    flush_predicate_attribute
    run_value_query_terms_test
    restart_proton_helper
    run_value_query_terms_test
  end

  def run_value_query_terms_test
    assert_search('{"gender":"Female"}', '{}',
                  ["female", "female-DK", "female-NO",
                   "female-SE", "not male"], "predicate_field")
    assert_search('{"gender":"Male"}', '{}',
                  ["male", "male-JP", "male-NO", "male-GB",
                   "not-female-or-NO"], "predicate_field")
    assert_search('{"country":"Norway"}', '{}',
                  ["female-NO", "male-NO", "not male"], "predicate_field")
    assert_search('{"gender":"Female","country":"Norway"}', '{}',
                  ["female", "female-DK", "female-NO", "female-SE",
                   "male-NO", "not male"], "predicate_field")
    assert_search('{"country":"%E6%97%A5%E6%9C%AC"}', '{}',
                  ["male-JP", "not male", "not-female-or-NO"],
                  "predicate_field")
    assert_search('{"gender":["Female","Male"]}', '{}',
                  ["female", "female-DK", "female-NO", "female-SE",
                   "male", "male-JP", "male-NO", "male-GB"], "predicate_field")
    assert_search('{"country":["Norway","Sweden"]}', '{}',
                  ["female-NO", "female-SE", "male-NO", "not male"], "predicate_field")
    assert_search('{"country":"Great Britain"}', '{}',
                  ["male-GB", "not male", "not-female-or-NO"],
                  "predicate_field")
    assert_search('{}', '{}', ["not male", "not-female-or-NO"], "predicate_field")
    assert_search('{"gender":"Female"}', '{}', ["second field"],
                  "second_predicate")
  end

  def generate_range_documents
    docs = DocumentSet.new
    docs.add(generate_doc("teen", "age in [13..19]"))
    docs.add(generate_doc("twenties", "age in [20..29]"))
    docs.add(generate_doc("below-40", "age in [..39]"))
    docs.add(generate_doc("above-20", "age in [20..]"))
    docs
  end

  def write_range_documents(file)
    generate_range_documents.write_json(file)
  end

  def test_boolean_searcher_range_query_terms
    write_range_documents(@feed_file)
    deploy_and_feed

    run_range_query_terms_test
    flush_predicate_attribute
    run_range_query_terms_test
    restart_proton_helper
    run_range_query_terms_test
  end

  def run_range_query_terms_test()
    assert_search('{}', '{"age":15L}', ["below-40", "teen"], "predicate_field")
    assert_search('{}', '{"age":20L}', ["above-20", "below-40", "twenties"],
                  "predicate_field")
    assert_search('{}', '{"age":40L}', ["above-20"], "predicate_field")
    assert_search('{}', '{"age":30L}', ["above-20", "below-40"], "predicate_field")
  end

  def test_boolean_searcher_mix_impressions
    docs = generate_value_documents
    range_docs = generate_range_documents
    range_docs.documents.each { | doc|
      docs.add(doc)
    }
    docs.write_json(@feed_file)
    deploy_and_feed

    run_mix_impressions_test
    flush_predicate_attribute
    run_mix_impressions_test
    restart_proton_helper
    run_mix_impressions_test
  end

  def run_mix_impressions_test
    assert_search('{"gender":"Female"}', '{}',
                  ["female", "female-DK", "female-NO", "female-SE",
                   "not male"], "predicate_field")
    assert_search('{"gender":"Male"}', '{}',
                  ["male", "male-JP", "male-NO", "male-GB",
                   "not-female-or-NO"], "predicate_field")
    assert_search('{"country":"Norway"}', '{}',
                  ["female-NO", "male-NO", "not male"], "predicate_field")
    assert_search('{"gender":"Female","country":"Norway"}', '{}',
                  ["female", "female-DK", "female-NO", "female-SE",
                   "male-NO", "not male"], "predicate_field")

    assert_search('{"gender":["Female","Male"]}', '{}',
                  ["female", "female-DK", "female-NO", "female-SE", "male",
                   "male-JP", "male-NO", "male-GB"], "predicate_field")
    assert_search('{"country":["Norway","Sweden"]}', '{}',
                  ["female-NO", "female-SE", "male-NO", "not male"], "predicate_field")

    assert_search('{}', '{"age":15L}', ["below-40", "teen", "not male",
                                   "not-female-or-NO"], "predicate_field")
    assert_search('{}', '{"age":20L}',
                  ["above-20", "below-40", "twenties", "not male",
                   "not-female-or-NO"], "predicate_field")
    assert_search('{}', '{"age":40L}',
                  ["above-20", "not male", "not-female-or-NO"], "predicate_field")

    assert_search('{"gender":"Female"}', '{"age":15L}',
                  ["below-40", "female", "female-DK", "female-NO",
                   "female-SE", "teen", "not male"], "predicate_field")
    assert_search('{"gender":"Male"}', '{"age":20L}',
                  ["above-20", "below-40", "male", "male-JP", "male-NO",
                   "twenties", "male-GB", "not-female-or-NO"], "predicate_field")
    assert_search('{"country":"Norway"}', '{"age":40L}',
                  ["above-20", "female-NO", "male-NO", "not male"], "predicate_field")
  end

  def write_mix_documents(file)
    docs = DocumentSet.new
    # ranges are [..)
    docs.add(generate_doc("teen-m", "age in [13..19] and gender in [Male]"))
    docs.add(generate_doc("twenties-f", "age in [20..29] and gender in [Female]"))
    docs.add(generate_doc("twenties-f-1..4",
              "gender in [Female] and age in [20..29] and pos in [1..3]"))
    docs.add(generate_doc("thirties-f-1..2",
              "gender in [Female] and age in [30..39] and pos in [1..1]"))
    docs.add(generate_doc("twenties-m-3..4",
              "gender in [Male] and age in [20..29] and pos in [3..3]"))
    docs.add(generate_doc("thirties-m-2..3",
                       "gender in [Male] and age in [30..39] and pos in [2..2]"))
    docs.write_json(file)
  end

  def test_boolean_searcher_mix_contracts
    File.open(@feed_file, "w") {|file| write_mix_documents(file) }
    deploy_and_feed

    run_mix_contracts_test
    flush_predicate_attribute
    run_mix_contracts_test
    restart_proton_helper
    run_mix_contracts_test
  end

  def run_mix_contracts_test
    assert_search('{"gender":"Female"}', '{"age":25L,"pos":2L}',
                  ["twenties-f", "twenties-f-1..4"], "predicate_field")
    assert_search('{"gender":"Female"}', '{"age":15L,"pos":2L}', [], "predicate_field")
    assert_search('{"gender":"Female"}', '{"age":15L}', [], "predicate_field")
    assert_search('{"gender":"Female"}', '{"age":25L}', ["twenties-f"], "predicate_field")
    assert_search('{"gender":"Male"}', '{"age":15L}', ["teen-m"], "predicate_field")
    assert_search('{"gender":"Male"}', '{"age":25L}', [], "predicate_field")

    assert_search('{"gender":"Female"}', '{"age":23L,"pos":1L}',
                  ["twenties-f", "twenties-f-1..4"], "predicate_field")
    assert_search('{"gender":"Female"}',
                  '{"age":23L,"pos":4L}', ["twenties-f"], "predicate_field")
    assert_search('{"gender":"Male"}', '{"age":50L}', [], "predicate_field")
    assert_search('{"gender":"Female"}',
                  '{"age":34L,"pos":1L}', ["thirties-f-1..2"], "predicate_field")
    assert_search('{"gender":"Female"}', '{"age":34L,"pos":3L}', [], "predicate_field")
    assert_search('{"gender":"Male"}', '{"age":38L,"pos":1L}', [], "predicate_field")
    assert_search('{"gender":"Male"}', '{"age":38L,"pos":2L}',
                  ["thirties-m-2..3"], "predicate_field")
  end

  def write_subquery_documents(file)
    docs = DocumentSet.new
    docs.add(generate_doc("female-or-NO",
              "gender in [Female] or country in [Norway]",
              ["predicate_field", "second_predicate"]))
    docs.add(generate_doc("female-and-NO",
              "gender in [Female] and country in [Norway]"))
    docs.add(generate_doc("not female", "gender not in [Female]"))
    docs.write_json(file)
  end

  def test_boolean_searcher_subqueries
    File.open(@feed_file, "w") {|file| write_subquery_documents(file) }
    deploy_and_feed
    run_subqueries_test()
  end

  def run_subqueries_test()
    assert_subquery_search('{"gender":"Female"}',
                  [
                    ["female-or-NO", 0xFFFFFFFFFFFFFFFF]])
    assert_subquery_search('{"gender":"Female","country":"Norway"}',
                  [
                    ["female-and-NO", 0xFFFFFFFFFFFFFFFF],
                    ["female-or-NO", 0xFFFFFFFFFFFFFFFF]])
    assert_subquery_search('{"[0]":{"gender":"Female"}}',
                  [
                    ["female-or-NO", 1],
                    ["not female", ~1]])
    assert_subquery_search('{"[0,63]":{"gender":"Female"}, "[31,62]":{"country":"Norway"}}',
                  [
                    ["female-or-NO", (1 << 63) + (1 << 62) + (1 << 31) + 1],
                    ["not female", ~((1 << 63) + 1)]])
    assert_subquery_search('{"[0,32,63]":{"gender":"Female"}, "[31,32,62]":{"country":"Norway"}}',
                  [
                    ["female-and-NO", (1 << 32)],
                    ["female-or-NO", (1 << 63) + (1 << 62) + (1 << 32) + (1 << 31) + 1],
                    ["not female", ~((1 << 63) + (1 << 32) + 1)]])

    run_query_with_conjunction_of_two_different_predicate_fields()
    run_query_with_conjunction_of_same_predicate_field()
  end

  def run_query_with_conjunction_of_two_different_predicate_fields()
    assert_summary_features_matches(
      'select * from sources * where predicate(predicate_field, {"0x1":{"gender":"Female"}}, {}) '\
      'AND predicate(second_predicate, {"0x2":{"gender":"Female"}}, {})',
      {
        "subqueries(predicate_field).lsb" => 1,
        "subqueries(predicate_field).msb" => 0,
        "subqueries(second_predicate).lsb" => 2,
        "subqueries(second_predicate).msb" => 0
      }
    )
  end

  def run_query_with_conjunction_of_same_predicate_field()
    assert_summary_features_matches(
      'select * from sources * where predicate(second_predicate, {"0x1":{"gender":"Female"}}, {}) '\
      'AND predicate(second_predicate, {"0x2":{"gender":"Female"}}, {})',
      {
        "subqueries(second_predicate).lsb" => 3,
        "subqueries(second_predicate).msb" => 0
      }
    )
  end

  def write_odd_range_documents(file)
    docs = DocumentSet.new
    docs.add(generate_doc("0", "value in [0..46]"))
    docs.write_json(file)
  end

  def test_boolean_searcher_odd_range_query_terms
    set_description("Test effects of bug 6379387")
    write_odd_range_documents(@feed_file)
    deploy_and_feed

    run_odd_range_query_terms_test
    flush_predicate_attribute
    run_odd_range_query_terms_test
    restart_proton_helper
    run_odd_range_query_terms_test
  end

  def run_odd_range_query_terms_test
    assert_search('{}', '{"value":46L}', ["0"], "predicate_field")
    assert_search('{}', '{"value":48L}', [], "predicate_field")
    assert_search('{}', '{"value":47L}', [], "predicate_field")
  end

  def write_empty_boolean_documents(file)
    docs = DocumentSet.new
    docs.add(generate_doc("male", "gender in [male]"))
    docs.add(generate_doc("empty", nil))
    docs.add(generate_doc("false", "false"))
    docs.add(generate_doc("all", "true"))
    docs.write_json(file)
  end

  def test_boolean_searcher_empty_boolean_documents
    set_description("Test effects of bug 6400348")
    File.open(@feed_file, "w") {|file| write_empty_boolean_documents(file) }
    deploy_and_feed

    run_empty_boolean_documents_test
    flush_predicate_attribute
    run_empty_boolean_documents_test
    restart_proton_helper
    run_empty_boolean_documents_test
  end

  def run_empty_boolean_documents_test
    assert_search('{"gender":"male"}', '{}', ["all", "male"], "predicate_field")
    assert_search('{"foo":"bar"}', '{}', ["all"], "predicate_field")
    assert_search('{}', '{}', ["all"], "predicate_field")
  end

  def write_minimum_range_value_documents(file)
    docs = DocumentSet.new
    docs.add(generate_doc("one-value", "value in [-9223372036854775808..-9223372036854775808]"))
    docs.add(generate_doc("range", "value in [-9223372036854775808..0]"))
    docs.write_json(file)
  end

  def test_boolean_searcher_minimum_range_value
    set_description("Test effects of bug 6514175")
    File.open(@feed_file, "w") {|file| write_minimum_range_value_documents(file) }
    deploy_and_feed

    run_minimum_range_value_test
    flush_predicate_attribute
    run_minimum_range_value_test
    restart_proton_helper
    run_minimum_range_value_test
  end

  def run_minimum_range_value_test
    assert_search('{}', '{"value":-9223372036854775807L}', ["range"], "predicate_field")
    assert_search('{}', '{"value":-9223372036854775808L}', ["one-value", "range"], "predicate_field")
  end

  def test_partial_updates_on_predicate_field
    set_description("Test partial updates on predicate field")
    File.open(@feed_file, "w") {|file| write_documents_for_partial_update_test(file) }
    File.open(@update_file, "w") {|file| write_updates_for_partial_update_test(file) }
    deploy_and_feed

    assert_search('{"gender":"Female"}', '{}', ["female-NO", "female-SE"])
    assert_search('{"gender":"Male"}', '{}', ["male-NO", "male-SE"])
    assert_search('{"country":"Norway"}', '{}', ["female-NO", "male-NO"])
    assert_search('{"country":"Sweden"}', '{}', ["female-SE", "male-SE"])

    assert_document_summary([["female-NO", "('gender' in ['Female'] or 'country' in ['Norway'])\n"],
                             ["female-SE", "('gender' in ['Female'] or 'country' in ['Sweden'])\n"],
                             ["male-NO", "('gender' in ['Male'] or 'country' in ['Norway'])\n"],
                             ["male-SE", "('gender' in ['Male'] or 'country' in ['Sweden'])\n"]])

    feed(:file => @update_file)
    assert_search_and_document_summary_for_partial_update_test

    vespa.search["search"].first.restart
    wait_for_hitcount("?query=sddocname:test", 4)

    assert_search_and_document_summary_for_partial_update_test
  end

  def write_documents_for_partial_update_test(file)
    docs = DocumentSet.new
    docs.add(generate_doc("female-NO", "gender in [Female] or country in [Norway]"))
    docs.add(generate_doc("female-SE", "gender in [Female] or country in [Sweden]"))
    docs.add(generate_doc("male-NO", "gender in [Male] or country in [Norway]"))
    docs.add(generate_doc("male-SE", "gender in [Male] or country in [Sweden]"))
    docs.write_json(file)
  end

  def write_updates_for_partial_update_test(file)
    updates = DocumentSet.new
    updates.add(generate_update("female-SE", "gender in [Female] or country in [Denmark]"))
    updates.add(generate_update("male-NO", "gender in [Male] or country in [Denmark]"))
    updates.write_json(file, :update)
  end

  def assert_search_and_document_summary_for_partial_update_test
    assert_search('{"gender":"Female"}', '{}', ["female-NO", "female-SE"])
    assert_search('{"gender":"Male"}', '{}', ["male-NO", "male-SE"])
    assert_search('{"country":"Norway"}', '{}', ["female-NO"])
    assert_search('{"country":"Sweden"}', '{}', ["male-SE"])
    assert_search('{"country":"Denmark"}', '{}', ["female-SE", "male-NO"])

    assert_document_summary([["female-NO", "('gender' in ['Female'] or 'country' in ['Norway'])\n"],
                             ["female-SE", "('gender' in ['Female'] or 'country' in ['Denmark'])\n"],
                             ["male-NO", "('gender' in ['Male'] or 'country' in ['Denmark'])\n"],
                             ["male-SE", "('gender' in ['Male'] or 'country' in ['Sweden'])\n"]])
  end

  def test_predicate_optimizations_are_idempotent
    set_description("Test that predicate optimizations are idempotent")

    unoptimized_predicate = "not (not (gender in ['Male'] and age in [20..29] and true)) and country not in ['Sweden']"
    doc_id = "unoptimized-1"
    docs = DocumentSet.new
    docs.add(generate_doc(doc_id, unoptimized_predicate))
    docs.write_json(@feed_file)
    deploy_and_feed

    optimized_doc = vespa.document_api_v1.get("id:test:test::#{doc_id}")
    expected_optimized_predicate = "country not in [Sweden] and gender in [Male] and age in [20..29]"
    assert_equal(expected_optimized_predicate, optimized_doc.fields['predicate_field'])

    vespa.document_api_v1.put(optimized_doc)
    reoptimized_doc = vespa.document_api_v1.get("id:test:test::#{doc_id}")
    assert_equal(expected_optimized_predicate, reoptimized_doc.fields['predicate_field'])
  end


  def get_query(field, attributes, range_attributes)
    return "/search/?query=&nocache&yql=select * from sources * where "\
    "predicate(#{field}, #{attributes}, #{range_attributes})"
  end

  def assert_search(attributes, range_attributes, expected_hits,
                    field = "predicate_field")
    expected_hits = expected_hits.sort
    result = search(get_query(field, attributes, range_attributes))
    assert_hitcount(result, expected_hits.size)
    result.sort_results_by("documentid")
    for i in 0...expected_hits.size
      exp_docid = "id:test:test::#{expected_hits[i]}"
      puts "Expects that hit[#{i}].documentid == '#{exp_docid}'"
      assert_equal(exp_docid, result.hit[i].field['documentid'])
    end
  end

  def assert_subquery_search(attributes, expected_hits)
    expected_hits = expected_hits.sort
    result = search(get_query("predicate_field", attributes, "{}"))
    assert_hitcount(result, expected_hits.size)
    result.sort_results_by("documentid")
    for i in 0...expected_hits.size
      expected_hit = expected_hits[i];
      exp_docid = "id:test:test::#{expected_hit[0]}"
      puts "Expects that hit[#{i}].documentid == '#{exp_docid}'"
      assert_equal(exp_docid, result.hit[i].field['documentid'])
      actual_summaryfeatures = result.hit[i].field['summaryfeatures']
      assert_int_features(actual_summaryfeatures,
        {"subqueries(predicate_field).lsb" => expected_hit[1] & 0xFFFFFFFF,
         "subqueries(predicate_field).msb" => (expected_hit[1] >> 32) & 0xFFFFFFFF})
    end
  end

  def assert_summary_features_matches(query, expected_summaryfeatures)
    result = search('/search/?query=&yql=' + query)
    assert_hitcount(result, 1)
    actual_summaryfeatures = result.hit[0].field['summaryfeatures']
    assert_int_features(actual_summaryfeatures, expected_summaryfeatures)
  end

  def assert_int_features(actual_summaryfeatures, expected_summaryfeatures)
    expected_summaryfeatures.each do |name, expected_value|
      puts "assert_features: #{name}:#{expected_value}"
      assert(actual_summaryfeatures.has_key?(name), "Actual hash does not contain feature '#{name}'")
      actual_value = actual_summaryfeatures.fetch(name).to_i
      assert_equal(expected_value, actual_value,
        "Feature '#{name}' does not have expected score."\
        " Expected: #{expected_value}. Actual: #{actual_value}")
    end
  end

  def assert_document_summary(expected_hits, field = "predicate_field")
    expected_hits = expected_hits.sort { |x,y| x[0] <=> y[0] }
    result = search("?query=sddocname:test")
    assert_hitcount(result, expected_hits.size)
    result.sort_results_by("documentid")
    for i in 0...expected_hits.size
      exp_docid = "id:test:test::#{expected_hits[i][0]}"
      exp_field_value = expected_hits[i][1]
      puts "Expects that hit[#{i}].documentid == '#{exp_docid}'"
      puts "Expects that hit[#{i}].#{field} == '#{exp_field_value}'"
      assert_equal(exp_docid, result.hit[i].field['documentid'])
      assert_equal(exp_field_value, result.hit[i].field[field])
    end
  end

end
