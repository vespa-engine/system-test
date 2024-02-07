# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/search_app'

def singlenode_streaming_2storage(sd_file)
  # the search cluster is used for content setup.
  # the storage cluster is used for storage/search setup.
  SearchApp.new.streaming().
    enable_document_api.
    cluster(SearchCluster.new.sd(sd_file).num_parts(2).storage_cluster("storage"))
end

def singlenode_2cols_realtime(sd_file)
  SearchApp.new.sd(sd_file).num_parts(2)
end

