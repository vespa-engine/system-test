# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class ImportedPosition < IndexedOnlySearchTest

  SAVE_RESULT = false

  def setup
    set_owner("toregge")
    set_description("Ensure that imported position indexing works as intended.")
  end

  def test_imported_position_simple
    run_imported_position_test("simple", 4, "my_pos", false)
  end

  def test_imported_position_array
    run_imported_position_test("array", 2, "my_pos", false)
  end

  def test_imported_nested_position_simple
    run_imported_position_test("simple", 4, "my_pos", true)
  end

  def test_imported_nested_position_array
    run_imported_position_test("array", 2, "my_pos", true)
  end

  def create_app(workdir, type, grandparent)
    app = SearchApp.new
    if grandparent
      app.sd("#{workdir}/nested/grandparent_#{type}_pos.sd", { :global => true })
      app.sd("#{workdir}/nested/parent_#{type}_pos.sd", { :global => true })
    else
      app.sd("#{workdir}/parent_#{type}_pos.sd", { :global => true })
    end
    app.sd("#{workdir}/child_#{type}_pos.sd")
    app
  end

  def run_imported_position_test(type, hits, pos_attribute, grandparent)
    workdir = "#{selfdir}imported_pos_#{type}"
    puts "workdir is #{workdir}"
    deploy_app(create_app(workdir, type, grandparent))
    start
    if grandparent
      feed_and_wait_for_docs("grandparent_#{type}_pos", hits,
                             :file => "#{workdir}/nested/grandparent_#{type}_feed.json",
                             :json => true)
      feed_and_wait_for_docs("parent_#{type}_pos", hits,
                             :file => "#{workdir}/nested/parent_#{type}_feed.json",
                             :json => true)
    else
      feed_and_wait_for_docs("parent_#{type}_pos", hits,
                             :file => "#{workdir}/parent_#{type}_feed.json",
                             :json => true)
    end
    feed_and_wait_for_docs("child_#{type}_pos", hits,
                           :file => "#{workdir}/child_#{type}_feed.json",
                           :json => true)
    run_query("yql=select * from sources * where geoLocation(\"#{pos_attribute}\", 12.123000, 98.987000, \"500 km\")%3B",
              "#{workdir}/child_#{type}_result1.json");
    resultname = type == "array" ? "result1" : "result2";
    run_query("yql=select * from sources * where geoLocation(\"#{pos_attribute}\", 12.123123, 98.987987, \"500 km\")%3B",
              "#{workdir}/child_#{type}_#{resultname}.json");
  end

  def run_query(query, file)
    if (SAVE_RESULT)
      save_result(query, file)
    else
      assert_result(query, file)
    end
  end

  def teardown
    stop
  end

end
