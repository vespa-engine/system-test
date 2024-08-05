# Copyright Vespa.ai. All rights reserved.
require 'persistent_provider_test'

class MergingTest < PersistentProviderTest

  def setup
    set_owner("vekterli")
  end

  def test_merging
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
    # Take down one node
    vespa.stop_content_node("storage", "1")

    doc1_id = "id:storage_test:music:n=123:thequickbrownfoxjumpsoverthelazydogperhapsyoushouldexercisemoredog"
    doc2_id = "id:storage_test:music:n=123:lookatthisfancydocumentidjustlookatitmygoodnesshowfancyitis"

    # Feed to the other
    doc = Document.new("music", doc1_id)
    vespa.document_api_v1.put(doc)

    # Switch which nodes are up
    vespa.start_content_node("storage", "1")
    vespa.stop_content_node("storage", "0")

    vespa.storage["storage"].wait_until_ready

    # Feed another document

    doc = Document.new("music", doc2_id)
    vespa.document_api_v1.put(doc)

    # Take both nodes back up
    vespa.start_content_node("storage", "0")
    vespa.storage["storage"].wait_until_ready

    # Check that both documents are on both nodes
    statinfo = vespa.storage["storage"].storage["0"].stat(doc1_id)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))

    statinfo = vespa.storage["storage"].storage["0"].stat(doc2_id)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))
  end

  def test_ensure_merge_handler_gets_new_document_config
    deploy_app(make_merge_app(1))
    start

    # Feed music doc
    music_doc_id = "id:storage_test:music::thequickbrownfoxjumpsoverthelazydogperhapsyoushouldexercisemoredog"
    doc = Document.new("music", music_doc_id)
    vespa.document_api_v1.put(doc)

    # Deploy app with new document type. Feeding will work as the merge handler
    # is not involved in this scope.
    deploy_app_and_wait_until_config_has_been_propagated(make_merge_app(1, true))

    # Feed banana doc
    banana_doc_id = "id:storage_test:banana::lookatthisfancydocumentidjustlookatitmygoodnesshowfancyitis"
    doc = Document.new("banana", banana_doc_id)
    vespa.document_api_v1.put(doc)
    
    # Increase redundancy, forcing merge of documents with new doc type between
    # the nodes. Will fail unless merge handler properly uses the new document
    # config.
    deploy_app_and_wait_until_config_has_been_propagated(make_merge_app(2, true))
    wait_until_ready # will time out if merging fails
  end

  def make_merge_app(num_copies, include_2nd_doctype = false)
    app = default_app.num_nodes(2).
          redundancy(num_copies). # music SD added by default
          validation_override("redundancy-increase")
    if include_2nd_doctype
      app.sd(VDS + 'schemas/banana.sd');
    end
    app
  end

  def deploy_app_and_wait_until_config_has_been_propagated(app)
    gen = get_generation(deploy_app(app)).to_i
    wait_for_reconfig(gen, 600, true)
    wait_for_config_generation_proxy(gen)
  end

  def teardown
    stop
  end

end
