# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class NearFieldSet < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def verify_query(query, expected_hits, failures)
    result = search(query)
    actual_hits = result.hitcount
    if actual_hits == expected_hits
      puts "PASS: #{query['yql']}"
    else
      puts "FAIL: #{query['yql']} (got #{actual_hits} hits, expected #{expected_hits})"
      failures << "Query '#{query['yql']}' returned #{actual_hits} hits, expected #{expected_hits}"
    end
  end

  def test_near_with_fieldset
    failures = []
    deploy_app(SearchApp.new
      .sd(selfdir+"test.sd")
      .container(Container.new
        .config(ConfigOverride.new("container.qr-searchers")
          .add("sendProtobufQuerytree", true))
        .search(Searching.new)
        .docproc(DocumentProcessing.new)
        .documentapi(ContainerDocumentApi.new)))
    start
    feed_and_wait_for_docs("test", 4, :file => selfdir+"docs.json")
    verify_query({'yql' => 'select * from sources * where a contains "a1" AND a contains "a2"'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where a contains near("a1", "a2")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where a contains near("a1", "a2", !"a3")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where a contains near("a1", "a2", !"bogus")'}, 1, failures)

    verify_query({'yql' => 'select * from sources * where b contains "b1" AND b contains "b2"'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where b contains near("b1", "b2")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where b contains near("b1", "b2", !"b3")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where b contains near("b1", "b2", !"bogus")'}, 1, failures)

    verify_query({'yql' => 'select * from sources * where ab contains "a1" AND ab contains "a2"'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains "b1" AND ab contains "b2"'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains near("a1", "a2")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains near("b1", "b2")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains near("a1", "a2", !"a3")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains near("b1", "b2", !"b3")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains near("a1", "a2", !"bogus")'}, 1, failures)
    verify_query({'yql' => 'select * from sources * where ab contains near("b1", "b2", !"bogus")'}, 1, failures)

    assert_equal("", failures.join("\n"))
  end

end
