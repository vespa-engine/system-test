# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/common_wiki_base'

class NearestNeighborWikiMultivec < CommonWikiBase

  def setup
    super
    set_owner("boeker")
  end

  def test_wiki_multivec
    set_description("Test feed and query performance for the Wikipedia (simple english) data set (187340 docs) with multiple embedding vectors (paragraphs) per document")
    run_wiki_test(@wiki_docs, "wiki")
  end


end
