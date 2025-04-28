# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class AdvancedGet < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def test_gettimestamp
    doc = Document.new("id:storage_test:music:n=1234:0").
      add_field("title", "mytitle").
      add_field("body", "body")

    vespa.document_api_v1.put(doc)

    ret = get_doc("id:storage_test:music:n=1234:0")

    assert_equal(doc, Document.create_from_json(ret))
  end

  def get_doc(id)
    output = vespa.storage['storage'].storage["0"].execute("vespa-get #{id}")
    JSON.parse(output).first
  end

  def teardown
    stop
  end
end

