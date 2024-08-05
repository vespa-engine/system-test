# Copyright Vespa.ai. All rights reserved.

require 'vds_multi_model_test'
require 'gatewayxmlparser'

class SplitBucketCount < VdsMultiModelTest

  def setup
    @valgrind=false

    set_owner("vekterli")
    deploy_app(default_app.bucket_split_count(5))
    start
  end

  def test_dynamicsplitbuckets_count
    docids = []

    100.times { |i|
      user = 1234 + i * 65536;

      docid = "id:storage_test:music:n=" + user.to_s + ":" + i.to_s
      docids.push(docid)

      doc = Document.new("music", docid)
      vespa.document_api_v1.put(doc)
    }

    cnt = 0
    timeout = 60
    while cnt < timeout
      buckets = vespa.storage['storage'].storage['0'].get_bucket_count

      break if buckets >= 12
      cnt += 1
      print "Count is #{cnt}\n"

      sleep 1
    end

    assert(cnt < timeout, "Failed to split within #{timeout} seconds")

    output = vespa.storage["storage"].storage["0"].execute("vespa-visit --xmloutput")
    parser = GatewayXMLParser.new("<result>" + output + "</result>")
    documents = parser.documents

    cmpdocids = []

    documents.each { |document|
      cmpdocids.push(document.documentid)
    }

    assert_equal(docids.sort, cmpdocids.sort.uniq)
  end

  def teardown
    stop
  end
end

