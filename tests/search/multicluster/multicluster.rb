# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'cgi'

class MultiCluster < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    set_description("Test searching with 2 content clusters, with one doc type in each, where the 2 doc types has a field with same name, except case")
  end

  def test_2_clusters_2_doc_types_field_name_equal_except_case
    cluster1 = SearchCluster.new("cluster1").sd(selfdir + "music.sd")
    cluster2 = SearchCluster.new("cluster2").sd(selfdir + "music2.sd")
    deploy_app(SearchApp.new.cluster(cluster1).cluster(cluster2))
    start

    feed_music_documents

    [:yql, :vespa].each do |query_language|
      ["artist"].each do |field|
        ["Pixies", "Portishead"].each do |term|
          ["cluster1,cluster2", nil].each do |sources|
            expect_hits(query_language, field, term, sources, 1)
          end
        end
      end
    end
    # with YQL we get: Field 'ARTIST' does not exist.
    expect_hits(:yql, "ARTIST", "Pixies", nil, 0)
    expect_hits(:vespa, "ARTIST", "Pixies", nil, 1)
    [:yql, :vespa].each do |query_language|
      ["title"].each do |field|
        ["Surfer"].each do |term|
          ["cluster1", "cluster1,cluster2", nil].each do |sources|
            expect_hits(query_language, field, term, sources, 1)
          end
        end
      end
    end
    # only field 'TITLE' contains 'dummy'
    expect_hits(:yql, "title", "dummy", nil, 0)
    expect_hits(:vespa, "title", "dummy", nil, 0)
    [:yql, :vespa].each do |query_language|
      ["TITLE"].each do |field|
        ["Dummy"].each do |term|
          ["cluster2", "cluster1,cluster2", nil].each do |sources|
            expect_hits(query_language, field, term, sources, 1)
          end
        end
      end
    end
    # only field 'title' contains 'Surfer'
    expect_hits(:yql, "TITLE", "Surfer", nil, 0)
    expect_hits(:vespa, "TITLE", "Surfer", nil, 0)
  end

  def expect_hits(query_language, field, term, sources, numhits)
    query = create_query(query_language, field, term, sources)
    puts "Query: #{CGI.unescape(query)}"
    search_and_assert_hitcount(query, numhits)
  end

  def create_query(query_language, field, term, sources)
    if query_language.eql?(:yql)
      s = sources ? sources : '*'
      q = "yql=select * from sources #{s} where #{field} contains \"#{term}\"&trace.level=1"
    else
      s = sources ? "&sources=#{sources}" : ''
      q = "query=#{field}:#{term}#{s}&trace.level=1"
    end
    q
  end

  def feed_music_documents
    vespa.document_api_v1.put(
      Document.new('music', 'id:test:music::1').
        add_field("artist", 'Pixies').
        add_field('title', 'Surfer Rosa'))
    vespa.document_api_v1.put(
      Document.new('music', 'id:test:music2::1').
        add_field("artist", 'Portishead').
        add_field('TITLE', 'Dummy'))
  end

  def search_and_assert_hitcount(query, expected_hit_count)
    begin
      assert_hitcount(query, expected_hit_count)
    rescue => e
      raise "Query '#{query}' failed: #{e.message}\nResult:\n #{JSON.pretty_generate(search(query).parse_json)}"
    end
  end

  def teardown
    stop
  end

end
