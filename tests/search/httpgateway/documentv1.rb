# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'cgi'
require 'app_generator/search_app'

class DocumentV1Test < SearchTest

  def setup
    set_owner("valerijf")
    set_description("Test operations in document/v1 api.")
  end

  def test_fieldpath
    deploy_application
    feedData = File.read(selfdir+"feedV1.json")
    feedDataUpdate = File.read(selfdir+"feedpathdata.json")
    start(240)
    # Feed ok test
    http = http_connection
    httpheaders={}
    response = http.post("/document/v1/fruit/banana/docid/doc1", feedData, httpheaders)
    assert_equal("200", response.code)
    response = http.put("/document/v1/fruit/banana/docid/doc1", feedDataUpdate, httpheaders)
    assert_equal("200", response.code)
    response = http.get("/document/v1/fruit/banana/docid/doc1")
    assert_equal("200", response.code)
    assert_json_string_equal("{\"id\":\"id:fruit:banana::doc1\"," +
       "\"fields\":{\"colour\":\"yellow\",\"similarfruits\":[\"banana\"]," +
       "\"string_string_map\":{\"foo\":\"crazy\"}}," +
       "\"pathId\":\"/document/v1/fruit/banana/docid/doc1\"}", response.body)
  end

  def test_realtimefeed
    deploy_application
    # Has color yellow
    feedData = File.read(selfdir+"feedV1.json")
    # Changes to color red
    feedDataUpdate = File.read(selfdir+"feedV1update.json")
    feedDataBroken = File.read(selfdir+"feedV1broken.json")
    start(240)
    http = http_connection
    httpheaders={}
    numDocuments = 3500

    # Do some cleanup so the test can run over and over without deleting index if it fails
    i = 0
    while i < numDocuments  do
        # Feed ok test
        response = http.delete("/document/v1/fruit/banana/docid/doc" + i.to_s, httpheaders)
        assert_equal("200", response.code)
        i += 1
    end

    # Get zero result test
    response = http.get("/document/v1/fruit/banana/docid/doc1")
    assert_equal("404", response.code)
    assert_json_string_equal(
       "{\"pathId\":\"/document/v1/fruit/banana/docid/doc1\", \"id\":\"id:fruit:banana::doc1\"}",
       response.body)

    # Visit zero result test
    response = http.get("/document/v1/fruit/banana/docid/")
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"documents\":[], \"pathId\":\"/document/v1/fruit/banana/docid/\"}",
      response.body)

    # Feed with conditional feed, but document is non existing.
    response = http.post("/document/v1/fruit/banana/docid/doc1?condition=banana.colour==''", feedData, httpheaders)
    assert_equal("412", response.code)

    # Feed ok test
    # Add route flag as well just to see that it works if route is set.
    response = http.post("/document/v1/fruit/banana/docid/doc1?route=default", feedData, httpheaders)
    assert_equal("200", response.code)   
    assert_json_string_equal(
      "{\"pathId\":\"/document/v1/fruit/banana/docid/doc1\", \"id\":\"id:fruit:banana::doc1\"}", 
      response.body)

    # Empty route should fail
    response = http.post("/document/v1/fruit/banana/docid/doc1?route=", feedData, httpheaders)
    assert_equal("400", response.code)

    # Feed, but with wrong condition
    response = http.post("/document/v1/fruit/banana/docid/doc1?condition=banana.colour=='wrong'&route=default", feedData, httpheaders)
    assert_equal("412", response.code)

    # Visit ok test
    response = http.get("/document/v1/fruit/banana/docid/")
    assert_equal("200", response.code)
    # Visit completes before covering the entire global bucket space, hence the continuation token.
    assert_json_string_equal(
      "{\"documents\": [{\"id\":\"id:fruit:banana::doc1\",\"fields\":{\"colour\":\"yellow\"}}]," +
      "\"pathId\":\"/document/v1/fruit/banana/docid/\"," +
      "\"continuation\":\"AAAACAAAAAAAAADDAAAAAAAAAMIAAAAAAAABAAAAAAEgAAAAAAAAQwAAAAAAAAAA\"}",
      response.body)

    # Conditional feed, with true condition
    response = http.post("/document/v1/fruit/banana/docid/doc1?condition=banana.colour=='yellow'", feedData, httpheaders)
    assert_equal("200", response.code)   
    assert_json_string_equal(
      "{\"pathId\":\"/document/v1/fruit/banana/docid/doc1\", \"id\":\"id:fruit:banana::doc1\"}",
      response.body)

    # Conditional update, with true condition
    response = http.put("/document/v1/fruit/banana/docid/doc1?condition=banana.colour=='yellow'", feedDataUpdate, httpheaders)
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"id\":\"id:fruit:banana::doc1\",\"pathId\":\"/document/v1/fruit/banana/docid/doc1\"}",
      response.body)

    # Verify that update happened
    response = http.get("/document/v1/fruit/banana/docid/doc1", httpheaders)
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"pathId\":\"/document/v1/fruit/banana/docid/doc1\",\"id\":\"id:fruit:banana::doc1\",\"fields\":{\"colour\":\"red\"}}", 
     response.body)

    # Delete document with wrong condition
    response = http.delete("/document/v1/fruit/banana/docid/doc1?condition=banana.colour=='wrong'", httpheaders)
    assert_equal("412", response.code)
    assert_match /TEST_AND_SET_CONDITION_FAILED/, response.body
    
    # Delete again, same document, correct condition
    response = http.delete("/document/v1/fruit/banana/docid/doc1?condition=banana.colour=='red'", httpheaders)
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"id\":\"id:fruit:banana::doc1\",\"pathId\":\"/document/v1/fruit/banana/docid/doc1\"}", 
      response.body)

    # Verify document is gone
    response = http.get("/document/v1/fruit/banana/docid/")
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"documents\": [],\"pathId\":\"/document/v1/fruit/banana/docid/\"}", 
      response.body)

    # Feed non-URL-encoded ID — horrible but customers do this today :'(
    response = http.post("/document/v1/fruit/banana/docid/vg.no/latest/news/!", feedData, httpheaders)
    assert_equal("200", response.code)   
    assert_json_string_equal(
      "{\"pathId\":\"/document/v1/fruit/banana/docid/vg.no/latest/news/!\", \"id\":\"id:fruit:banana::vg.no/latest/news/!\"}", 
      response.body)

    # Feed challenging ID
    response = http.post("/document/v1/fruit/banana/docid/vg.no%2Flatest%2Fnews%2F%21", feedData, httpheaders)
    assert_equal("200", response.code)   
    assert_json_string_equal(
      "{\"pathId\":\"/document/v1/fruit/banana/docid/vg.no%2Flatest%2Fnews%2F%21\", \"id\":\"id:fruit:banana::vg.no/latest/news/!\"}", 
      response.body)
    http.delete("/document/v1/fruit/banana/docid/vg.no%2Flatest%2Fnews%2F%21", httpheaders)

    # Send document with wrong field
    response = http.post("/document/v1/fruit/banana/docid/doc1", feedDataBroken, httpheaders)
    assert_equal("400", response.code)
    assert_match /No field 'habla babla' in the structure of type 'banana'/, response.body
    #
    # Update, with create = false
    response = http.put("/document/v1/fruit/banana/docid/doc1?create=false", feedDataUpdate, httpheaders)
    assert_equal("200", response.code)
    assert_json_string_equal(
       "{\"id\":\"id:fruit:banana::doc1\",\"pathId\":\"/document/v1/fruit/banana/docid/doc1\"}",
       response.body)
    response = http.get("/document/v1/fruit/banana/docid/doc1")
    assert_equal("404", response.code)

    # Conditional update, with true condition
    response = http.put("/document/v1/fruit/banana/docid/doc1?create=true", feedDataUpdate, httpheaders)
    assert_equal("200", response.code)
    assert_json_string_equal(
       "{\"id\":\"id:fruit:banana::doc1\",\"pathId\":\"/document/v1/fruit/banana/docid/doc1\"}",
       response.body)
    response = http.get("/document/v1/fruit/banana/docid/doc1")
    assert_equal("200", response.code)
    assert_json_string_equal(
       "{\"pathId\":\"/document/v1/fruit/banana/docid/doc1\",\"id\":\"id:fruit:banana::doc1\"," +
       "\"fields\":{\"colour\":\"red\"}}",
       response.body)

    # Feed some documents
    i = 0
    while i < numDocuments  do
        # Feed ok test
        response = http.post("/document/v1/fruit/banana/docid/doc" + i.to_s, feedData, httpheaders)
        assert_equal("200", response.code)   
        i +=1
    end

    # Visit all documents and update banana colour
    contToken = ""
    for q in 0..numDocuments
      response = http.put("/document/v1/fruit/banana/docid/?selection=true" + contToken, feedDataUpdate, httpheaders)
       assert_equal("200", response.code)
       jsonResponse = JSON.parse(response.body)
       if (jsonResponse.has_key?("continuation"))
          contToken = "&continuation=" + jsonResponse["continuation"] 
       else
          break
       end
    end

    # Visit all documents and refeed them
    contToken = ""
    for q in 0..numDocuments
      response = http.post("/document/v1/fruit/banana/docid/?destination=default" + contToken)
       assert_equal("200", response.code)
       jsonResponse = JSON.parse(response.body)
       if (jsonResponse.has_key?("continuation"))
          contToken = "&continuation=" + jsonResponse["continuation"] 
       else
          break
       end
    end

    # Visit all documents, verify colour and the total number of documents
    found = 0
    contToken = ""
    # Avoid infinite loop in case of cycles, numDocuments is absolute max
    for q in 0..numDocuments
       # Visit zero result test
       response = http.get("/document/v1/fruit/banana/docid/" + contToken)
       assert_equal("200", response.code)
       jsonResponse = JSON.parse(response.body)
       jsonResponse["documents"].each do |document|
          found += 1
          assert_equal("red", document["fields"]["colour"])
       end
       if (jsonResponse.has_key?("continuation"))
          contToken = "?continuation=" + jsonResponse["continuation"] 
       else
          break
       end
    end
    assert_equal(numDocuments, found)

    # Visit all documents and delete them
    contToken = ""
    for q in 0..numDocuments
       response = http.delete("/document/v1/fruit/banana/docid/?selection=true&destination=content" + contToken)
       assert_equal("200", response.code)
       jsonResponse = JSON.parse(response.body)
       jsonResponse["documents"].each do 
          found += 1
       end
       if (jsonResponse.has_key?("continuation"))
          contToken = "&continuation=" + jsonResponse["continuation"] 
       else
          break
       end
    end

    # Visit all documents and verify there are none
    found = 0
    contToken = ""
    for q in 0..numDocuments
       response = http.get("/document/v1/fruit/banana/docid/" + contToken)
       assert_equal("200", response.code)
       jsonResponse = JSON.parse(response.body)
       jsonResponse["documents"].each do 
          found += 1
       end
       if (jsonResponse.has_key?("continuation"))
          contToken = "?continuation=" + jsonResponse["continuation"] 
       else
          break
       end
    end
    assert_equal(0, found)

    assert(verify_with_retries(http, {"PUT" => 3504, "UPDATE" => 3, "REMOVE" => 3502}, {"PUT" => 4, "REMOVE" => 1}))
  end

  def deploy_application
    deploy_app(SearchApp.new.container(Container.new("node1").
                                       documentapi(ContainerDocumentApi.new)).
               cluster(SearchCluster.new("content").sd(selfdir+"banana.sd")).
               config(ConfigOverride.new("metrics.manager").add("reportPeriodSeconds", 3600)).
               monitoring("vespa", 300))
  end

  def http_connection
    container = vespa.container.values.first
    http = https_client.create_client(container.name, container.http_port)
    http.read_timeout=190
    http
  end

  def verify_with_retries(http, success_ops= {}, failed_ops = {})
    for i in 0..10
      if verify_metrics(http, success_ops, failed_ops)
        return true
      end
      sleep(0.5)
    end
    return verify_metrics(http, success_ops, failed_ops, true)
  end

  def verify_metrics(http, success_ops, failed_ops, errors = false)
    metrics_json = JSON.parse(http.get("/state/v1/metrics").body)
    metrics = metrics_json["metrics"]["values"]

    expect_metrics = {"OK" => success_ops, "REQUEST_ERROR" => failed_ops}
    actual_metrics = {"OK" => {}, "REQUEST_ERROR" => {}}
    for metric in metrics
      if metric["name"] == "feed.operations"
        status = metric["dimensions"]["status"]
        operation = metric["dimensions"]["operation"]
        value = metric["values"]["count"]
        actual_metrics[status][operation] = value
      end
    end

    if actual_metrics == expect_metrics
      return true
    else
      if errors
        puts "Expected feed metrics to be:"
        puts expect_metrics
        puts "But actually got:"
        puts actual_metrics
      end
      return false
    end
  end

  def teardown
    stop
  end
end
