# Copyright Vespa.ai. All rights reserved.
require 'vds_multi_model_test'

class DynamicSplitCount < VdsMultiModelTest

  def setup
    @valgrind=false

    set_owner("vekterli")
    deploy_app(default_app.bucket_split_count(5))
    start
  end

  def wait_until_bucket_count_at_least(n_buckets)
    cnt = 0
    while cnt < 200
      buckets = vespa.storage['storage'].storage['0'].get_bucket_count
      puts "Found #{buckets} buckets on content node"
      break if buckets >= n_buckets
      sleep 1
    end
    assert cnt < 200
  end

  def test_dynamicsplitbuckets_one_user
    docids = []

    100.times { |i|
      docid = "id:storage_test:music:n=1234:" + i.to_s
      docids.push(docid)

      # Make the docs a bit larger.
      doc = Document.new(docid).
	add_field("title", "a" * 540)

      vespa.document_api_v1.put(doc)
    }

    wait_until_bucket_count_at_least 12

    output = vespa.storage["storage"].storage["0"].execute("vespa-visit")
    actualdocids = JSON.parse(output).map { | doc | doc['id'] }
    assert_equal(docids.sort, actualdocids.sort)
  end

  def test_dynamicsplitbuckets_many_users
    docids = []

    100.times { |i|
      user = 1234 + i * 65536;

      docid = "id:storage_test:music:n=" + user.to_s + ":myfile"
      docids.push(docid)
      # Make the docs a bit larger.
      doc = Document.new(docid).
	add_field("title", "a" * 540)

      vespa.document_api_v1.put(doc)
    }

    # Wait until we have at least 5 splits or timeout
    wait_until_bucket_count_at_least 5

    output = vespa.storage["storage"].storage["0"].execute("vespa-visit")
    actualdocids = JSON.parse(output).map { | doc | doc['id'] }
    assert_equal(docids.sort, actualdocids.sort)
  end

end

