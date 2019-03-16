# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'search/utils/elastic_doc_generator'

class FeedAndQueryTestBase < SearchTest

  def setup
    @base_query = "query=sddocname:test&nocache&hits=0"
    Dir::mkdir("#{dirs.tmpdir}/generated")
  end

  def teardown
    stop
  end

  def generate_and_feed_docs(n_docs = 20)
    ElasticDocGenerator.write_docs(0, n_docs, dirs.tmpdir + "generated/docs.xml")
    feed(:file => dirs.tmpdir + "generated/docs.xml")
  end

  def assert_query_hitcount(exp_hitcount = 20, search_path = nil)
    hitcount = run_query(exp_hitcount, search_path)
    assert_equal(exp_hitcount, hitcount, "Expected #{exp_hitcount} hits, but was #{hitcount}")
  end

  def run_query(exp_hitcount = 20, search_path = nil)
    query = get_query(search_path)
    hitcount = search_withtimeout(10, query).hitcount
    puts "run_query(#{query}, #{exp_hitcount}): #{hitcount} hits" if search_path
    return hitcount
  end

  def get_query(search_path = nil)
    query = @base_query
    if search_path != nil
      query = query + "&model.searchPath=#{search_path}"
    end
    return query
  end

end

