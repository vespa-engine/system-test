# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class RestartDataRetentionTest < IndexedOnlySearchTest

  def setup
    set_owner('vekterli')
    @data_dir = selfdir + 'grandparent_search/'
  end

  def teardown
    stop
  end

  def make_app
    app = SearchApp.new.
        sd(@data_dir + "grandparent.sd", { :global => true }).
        sd(@data_dir + "parent.sd", { :global => true }).
        sd(@data_dir + "child.sd").
        cluster_name('storage').
        enable_document_api.
        num_parts(1).redundancy(1).ready_copies(1).
        storage(StorageCluster.new('storage', 1).distribution_bits(8))
    app
  end

  def feed_docs_across_bucket_spaces
    feed(:file => @data_dir + "feed-0.json") # Reuse feed file from GC selection test case
  end

  def wait_until_doc_set_is(expected, bucket_space)
    puts "Waiting for document set in bucket space '#{bucket_space}' to be: #{expected}"
    docs = []
    60.times do |n|
      res = vespa.document_api_v1.visit(:cluster => 'storage', :selection => 'true',
                                        :bucketSpace => bucket_space, :wantedDocumentCount => 1000)
      docs = res['documents'].map{|d| d['id']}.sort.to_a
      if docs == expected
        puts "Document set matches!"
        return
      end
      sleep 1
    end
    flunk("Expected document set to be #{expected}, but was #{docs}")
  end

  def ensure_all_docs_present_across_bucket_spaces
    wait_until_doc_set_is(['id:test:child::0', 'id:test:child::1', 'id:test:child::2',
                           'id:test:child::3', 'id:test:child::4', 'id:test:child::5'],
                          'default')
    wait_until_doc_set_is(['id:test:grandparent::0', 'id:test:grandparent::1', 'id:test:parent::0',
                           'id:test:parent::1', 'id:test:parent::2', 'id:test:parent::3', ],
                          'global')
  end

  def test_all_docs_across_bucket_spaces_are_retained_upon_restart
    set_description('Explicitly test that node restarts retain document data across all bucket spaces')
    deploy_app(make_app)
    start

    feed_docs_across_bucket_spaces
    ensure_all_docs_present_across_bucket_spaces

    vespa.stop_content_node('storage', 0)
    start_node_and_wait('storage', 0)

    ensure_all_docs_present_across_bucket_spaces
  end

end

