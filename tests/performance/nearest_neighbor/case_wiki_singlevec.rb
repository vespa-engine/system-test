# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/common_wiki_base'

class NearestNeighborWikiSinglevec < CommonWikiBase

  def setup
    super
    set_owner("boeker")
  end

  def test_wiki_singlevec
    set_description("Test feed and query performance for the Wikipedia (simple english) data set (485851 docs) with one embedding vector (paragraph) per document")
    run_wiki_test(@paragraph_docs, "paragraph")
  end


end
