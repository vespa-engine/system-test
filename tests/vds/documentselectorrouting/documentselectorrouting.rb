# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class DocumentSelectorRoutingTest < VdsTest

  def setup
    set_owner("vekterli")
  end

  def test_feeding_succeeds_for_docs_without_matching_route_doc_selector
    set_description("Test that feeding documents that do not match any of " +
                    "the route selections does not fail the feed")

    deploy_app(default_app.doc_type("music", "music.year < 6"))
    start

    # Always succeeds
    doc = Document.new("music", "id:storage_test:music:n=1234:foo").
      add_field("year", 5)
    vespa.document_api_v1.put(doc)

    # Will throw if feeding fails on no possible selection.
    doc = Document.new("music", "id:storage_test:music:n=1234:bar").
      add_field("year", 10)
    vespa.document_api_v1.put(doc)

    doc = vespa.document_api_v1.get("id:storage_test:music:n=1234:bar")
    assert_equal(nil, doc)

    doc = vespa.document_api_v1.get("id:storage_test:music:n=1234:foo")
    assert(doc != nil)
  end

  def teardown
    stop
  end
end

