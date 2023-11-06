# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class AdvancedGet < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def test_gettimestamp
    doc = Document.new("music", "id:storage_test:music:n=1234:0").
      add_field("title", "mytitle").
      add_field("body", "body")

    vespa.document_api_v1.put(doc)

    ret = get_doc_as_xml("id:storage_test:music:n=1234:0")

    assert_equal(doc, Document.create_from_xml(ret.root))
    assert(ret.root.attributes["lastmodifiedtime"].to_i > 0)
  end

  def get_doc_as_xml(id)
    output = vespa.storage['storage'].storage["0"].execute("vespa-get --xmloutput #{id}")
    REXML::Document.new(output)
  end

  def teardown
    stop
  end
end

