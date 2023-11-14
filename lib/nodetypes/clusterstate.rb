# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class ClusterState
  attr_accessor :storage,:distributor,:clusterstate

  def initialize
    @storage = {}
    @distributor = {}
    @clusterstate = nil
  end  

  def ==(other)
    return (storage.size != other.storage.size || distributor != other.distributor.size || clusterstate != other.clusterstate)
  end

end
