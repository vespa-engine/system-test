# Copyright Vespa.ai. All rights reserved.

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
