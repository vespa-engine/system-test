# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Tokenize < IndexedSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("yngve")
    set_description("Ensure that tokenization works as intended.")
  end

  def test_tokenize_string
    run_test("str", 1)
  end

  def run_test(type, hits)
    deploy_app(SearchApp.new.sd("#{selfdir}/#{type}_type.sd"))
    start
    feed_and_wait_for_docs("#{type}_type", hits, :file => "#{selfdir}/#{type}_feed.xml")
    run_query("query=sddocname:#{type}_type",
              "#{selfdir}/#{type}_result.xml");
  end

  def run_query(query, file)
    if (SAVE_RESULT)
      save_result(query, file)
    else
      assert_result(query, file, "documentid")
    end
  end

  def teardown
    stop
  end

end
