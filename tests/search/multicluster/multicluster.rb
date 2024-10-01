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
      ["title", "TITLE"].each do |field|
        ["Surfer", "Dummy"].each do |term|
          ["cluster1,cluster2", nil].each do |s|
            query = create_query(query_language, field, term, s)
            puts "Query: #{CGI.unescape(query)}"
            search_and_assert_hitcount(query, 1)
          end
        end
      end
    end
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
