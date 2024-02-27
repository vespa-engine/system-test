# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class GlobalParentsToolTest < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    @test_dir = selfdir + "global_parents_feed/"
    @cluster_name = "my_cluster"
  end

  def make_app
    SearchApp.new.
      sd(@test_dir + "campaign.sd", { :global => true }).
      sd(@test_dir + "ad.sd").
      cluster_name(@cluster_name).
      redundancy(1).
      num_parts(1).
      enable_document_api
  end

  def test_tools_with_global_parents
    set_description("Test tools (vespa-stat, vespa-visit) with global parents")
    deploy_app(make_app)
    start
    feed(:file => @test_dir + "campaign-batch-1-7.json")
    vespa.storage[@cluster_name].validate_cluster_bucket_state()
    check_visit("default", make_exp_ad_ids)
    check_stat("default", ad(1))
    check_document_v1_get(ad(1))
    check_document_v1_visit("ad", make_exp_ad_ids)
    check_visit("global", make_exp_campaign_ids)
    check_stat("global", campaign(1))
    check_document_v1_get(campaign(1))
    check_document_v1_visit("campaign", make_exp_campaign_ids)
  end

  def check_visit(bucketspace, exp_ids)
    visitres = vespa.adminserver.execute("vespa-visit --jsonoutput --bucketspace #{bucketspace}")
    ids = extract_ids(JSON.parse(visitres))
    puts "'#{exp_ids}' == '#{ids}' ? "
    assert_equal(exp_ids, ids)
  end

  def check_stat(bucketspace, doc)
    statres = vespa.adminserver.execute("vespa-stat -o #{doc} -s #{bucketspace}")
    matchres = /BucketId\((0x[0-9a-f]*)\)/.match(statres)
    assert(matchres)
    bucket = matchres[1]
    statres = vespa.adminserver.execute("vespa-stat -b #{bucket} -s #{bucketspace} -d")
    matchres = /Doc\(([a-z0-9:]*)\)/.match(statres)
    assert(matchres)
    assert_equal(doc, matchres[1])
  end

  def check_document_v1_get(doc)
    matchres = /id:([^:]*):([^:]*):[^:]*:(.*)/.match(doc)
    assert(matchres)
    namespace = matchres[1]
    doctype = matchres[2]
    id = matchres[3]
    http = http_connection
    response = http.get("/document/v1/#{namespace}/#{doctype}/docid/#{id}")
    assert_equal("200", response.code)
    jsonResponse = JSON.parse(response.body)
    assert_equal(doc, jsonResponse["id"])
  end

  def check_document_v1_visit(doctype, exp_ids)
    ids = []
    http = http_connection
    contToken = ""
    maxdocs = exp_ids.size
    for pass in 0..maxdocs
      response = http.get("/document/v1/test/#{doctype}/docid/" + contToken)
      assert_equal("200", response.code)
      jsonResponse = JSON.parse(response.body)
      jsonResponse["documents"].each do |doc|
        ids.push(doc["id"])
      end
      if (jsonResponse.has_key?("continuation"))
        contToken = "?continuation=" + jsonResponse["continuation"]
      else
        break
      end
    end
    ids = ids.sort
    assert_equal(maxdocs, ids.size)
    assert_equal(exp_ids, ids)
  end

  def http_connection
    container = vespa.container["doc-api/0"]
    http = https_client.create_client(container.name, container.http_port)
    http.read_timeout=190
    http
  end

  def extract_ids(docs)
    ids = []
    docs.each { |doc| ids.push(doc["id"]) }
    ids.sort
  end

  def make_exp_ad_ids()
    ids = []
    35.times { |i| ids.push(ad(i + 1)) }
    ids.sort
  end

  def make_exp_campaign_ids()
    ids = []
    7.times { |i| ids.push(campaign(i + 1)) }
    ids.sort
  end

  def campaign(id)
    "id:test:campaign::#{id}"
  end

  def ad(id)
    "id:test:ad::#{id}"
  end

  def teardown
    stop
  end

end
