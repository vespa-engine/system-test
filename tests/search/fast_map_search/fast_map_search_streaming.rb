# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'
require 'search/fast_map_search/fast_map_search_base'

class FastMapSearchStreaming < StreamingSearchTest

  def add_streaming_selection_query_parameter
    true
  end

  include FastMapSearchBase

end
