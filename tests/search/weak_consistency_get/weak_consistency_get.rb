require 'indexed_streaming_search_test'

class WeakInternalConsistencyGetTest < IndexedStreamingSearchTest

  def setup
    set_owner('vekterli')
    deploy_app(make_app())
    start
  end

  def teardown
    stop
  end

  def make_app
    SearchApp.new.sd(SEARCH_DATA + 'simple.sd').
      cluster_name('storage').
      num_parts(1).redundancy(1).ready_copies(1).
      storage(StorageCluster.new('storage', 1).distribution_bits(8)).
      config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
             add('use_weak_internal_read_consistency_for_client_gets', true))
  end

  def doc_id
    'id:test:simple::foo'
  end

  def feed_initial_document
    doc = Document.new('simple', doc_id).
      add_field('title', 'hello world'). # indexed, _not_ attribute
      add_field('date', 1234567)         # indexed _and_ attribute field
    vespa.document_api_v1.put(doc)
  end

  def update_existing_document
    update = DocumentUpdate.new('simple', doc_id)
    update.addOperation('assign', 'title', 'goodnight moon')
    update.addOperation('assign', 'date', 2345678)
    vespa.document_api_v1.update(update)
  end

  def test_weak_internal_consistent_gets_observe_stable_state_in_quiescent_cluster
    set_description('Ensure that changes to documents are visible even with weak internal ' +
                    'consistency when there is no concurrent feeding taking place')

    feed_initial_document
    fields = vespa.document_api_v1.get(doc_id).fields
    assert_equal('hello world', fields['title'])
    assert_equal(1234567, fields['date'])

    update_existing_document
    fields = vespa.document_api_v1.get(doc_id).fields
    assert_equal('goodnight moon', fields['title'])
    assert_equal(2345678, fields['date'])
  end

end

