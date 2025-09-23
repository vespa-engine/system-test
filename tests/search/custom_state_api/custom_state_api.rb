# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class CustomStateApi < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_custom_component_api
    set_description("Test that we can access the /state/v1/custom/component api")
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")
    @node = @vespa.search["search"].first
    assert_root_resources(@node.get_state_v1(""))
    assert_custom_component_api(get_page(""))
  end

  def get_page(path)
    @node.get_state_v1_custom_component(path)
  end

  def assert_keys(exp_keys, page)
    assert_equal(exp_keys.size, page.size)
    assert_equal(exp_keys.sort, page.keys.sort)
  end

  def assert_root_resources(root)
    resources = root["resources"]
    puts "assert_root_resources: #{resources.join(',')}"
    assert_equal(1, resources.count { |elem| elem["url"].end_with?("/state/v1/custom/component") })
  end

  def assert_custom_component_api(page)
    # We only test part of the page as the details are unit tested in searchcore.
    puts "assert_custom_component_api: #{page}"
    assert_keys(["documentdb", "threadpools", "flushengine", "matchengine", "tls", "hwinfo", "resourceusage", "session", "mallocinfo"], page)

    doc_dbs = page["documentdb"]
    assert_equal(1, doc_dbs.size)
    assert_equal("ONLINE", doc_dbs["test"]["status"]["state"])
    assert_equal("test", doc_dbs["test"]["documentType"])
    assert_equal(1, doc_dbs["test"]["documents"]["active"].to_i) unless is_streaming

    assert_equal("ONLINE", page["matchengine"]["status"]["state"])

    assert_document_db(get_page("/documentdb/test"))
    assert_thread_pools(get_page("/threadpools"))
    assert_flush_engine(get_page("/flushengine"))
    assert_tls(get_page("/tls"))
    assert_hw_info(get_page("/hwinfo"))
    assert_resource_usage(get_page("/resourceusage"))
    assert_mallocinfo(get_page("/mallocinfo"))
  end

  def assert_document_db(page)
    assert_keys(["bucketdb", "documents", "documentType", "threadingservice", "maintenancecontroller", "status", "subdb"], page)
    assert_equal(1, page["bucketdb"]["numBuckets"].to_i)
    assert_bucket_db(get_page("/documentdb/test/bucketdb"))
    assert_ready_subdb(get_page("/documentdb/test/subdb/ready"))
  end

  def assert_bucket_db(page)
    assert_keys(["buckets", "numBuckets"], page)
    assert_equal(1, page["numBuckets"].to_i)
    assert_equal(1, page["buckets"].size)
  end

  def assert_ready_subdb(page)
    assert_keys(["documentmetastore", "documentstore", "attribute", "attributewriter", "index"], page)
    assert_attribute_writer(get_page("/documentdb/test/subdb/ready/attributewriter"))
    assert_index(get_page("/documentdb/test/subdb/ready/index"))
  end

  def assert_attribute_writer(page)
    assert_keys(["write_contexts"], page)
    assert(page["write_contexts"].size > 0) unless is_streaming
  end

  def assert_index(page)
    assert_keys(["lastSerialNum", "diskIndexes", "memoryIndexes", "pending_urgent_flush", "write_contexts"], page)
  end

  def assert_thread_pools(page)
    assert_keys(["shared", "match", "docsum", "flush", "proton", "field_writer"], page)
    assert_field_writer(get_page("/threadpools/field_writer"))
  end

  def assert_field_writer(page)
    assert_keys(["type", "num_executors", "executor", "executors"], page)
    assert(page["executors"].size > 0)
  end

  def assert_flush_engine(page)
    assert_keys(["allTargets", "flushingTargets", "flush_history"], page)
    assert(!page["allTargets"].empty?)
  end

  def assert_tls(page)
    assert_keys(["test"], page)
  end

  def assert_hw_info(page)
    assert_keys(["disk", "memory", "cpu"], page)
    assert(page["disk"]["size_bytes"].to_i > 0)
    assert(page["memory"]["size_bytes"].to_i > 0)
    assert(page["cpu"]["cores"].to_i > 0)
  end

  def assert_resource_usage(page)
    assert_keys(["disk", "memory", "attribute_address_space"], page)
  end

  def assert_mallocinfo(page)
    # Only the 'malloc_impl' field is certain to be present. The rest are platform/implementation-specific.
    assert page.has_key? 'malloc_impl'
  end


end
