# Copyright Vespa.ai. All rights reserved.
require 'document'
require 'indexed_only_search_test'

class MaxDocumentSize < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    @id = 0
    @one_mib = 1024 * 1024
  end

  def test_max_document_size
    deploy_application('1MiB')
    start
    vespa.adminserver.execute("vespa-get-config -n vespa.config.content.core.stor-distributormanager -i mystorage/distributor/0 | grep max_document_operation_message_size_bytes")

    # feed a bit less than 1 MiB
    feed(@one_mib - 1000)

    begin
      # feed a bit more than 1 MiB, should fail
      feed(@one_mib + 1000)
      raise "An error should have been raised when feeding more than 1 MiB"
    rescue HttpResponseError => e
      assert_equal(400, e.response_code)
      assert(e.response_message.include? "exceeds maximum configured limit")
    end
  end

  def feed(characters)
    @id = @id + 1
    doc = Document.new("id:ns:test::#{@id}")
    # Create doc with characters / 2, since we add one space between characters
    doc.add_field("my_str", (0..characters/2).map { |i| i % 10 }.join(' '))

    puts "Feeding a doc with #{characters} bytes"
    documentapi = DocumentApiV1.new(vespa.adminserver.hostname, Environment.instance.vespa_web_service_port, self)
    documentapi.put(doc, { :brief => true })
  end

  def deploy_application(max_document_size)
    deploy_app(SearchApp.new.
                 storage(StorageCluster.new("mystorage").max_document_size(max_document_size)).
                 cluster(SearchCluster.new.sd("#{selfdir}/test.sd").storage_cluster("mystorage")))
  end

  def teardown
    stop
  end

end
