# Copyright Vespa.ai. All rights reserved.
require 'vds_test'
require 'environment'

class VisitorResumeTest < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app)
    start
  end

  def test_visitorresume
    doc = Document.new("music", "id:storage_test:music:n=1234:doc").
      add_field("title", "title")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:n=4567:doc").
      add_field("title", "title")
    vespa.document_api_v1.put(doc)

    output = vespa.storage["storage"].storage["0"].execute("vespa-visit --progress #{Environment.instance.vespa_home}/tmp/resume.txt -s \"id.user=1234 or id.user=4567\"")
    progress_file = vespa.storage["storage"].storage["0"].execute("cat #{Environment.instance.vespa_home}/tmp/resume.txt")
    doc_ids = JSON.parse(output).map { | doc | doc['id'] }.sort

    assert_equal(2, doc_ids.size)
    assert_equal("id:storage_test:music:n=1234:doc", doc_ids[0])
    assert_equal("id:storage_test:music:n=4567:doc", doc_ids[1])

    # Write new progress file with userdoc 1234 bucket set to not started
    vespa.storage["storage"].storage["0"].execute("echo -e \"VDS bucket progress file\n11\n0\n1\n2\n80000000000004d2:0\n\" > #{Environment.instance.vespa_home}/tmp/resume2.txt")

    output = vespa.storage["storage"].storage["0"].execute("vespa-visit --progress #{Environment.instance.vespa_home}/tmp/resume2.txt -s \"id.user=1234 or id.user=4567\"")
    progress_file2 = vespa.storage["storage"].storage["0"].execute("cat #{Environment.instance.vespa_home}/tmp/resume2.txt")
    doc_ids = JSON.parse(output).map { | doc | doc['id'] }.sort

    assert_equal(1, doc_ids.size)
    assert_equal("id:storage_test:music:n=1234:doc", doc_ids[0])

    visited_buckets = progress_file.split(/\n/)[3] # Finished buckets
    visited_buckets2 = progress_file2.split(/\n/)[3]

    assert_equal(visited_buckets, visited_buckets2)
    #assert_equal(buckets_before_second_visit.to_i + 17, visited_buckets2.to_i)
  end

  def teardown
    begin
      vespa.storage["storage"].storage["0"].execute("rm #{Environment.instance.vespa_home}/tmp/resume*.txt")
    ensure
      stop
    end
  end

end
