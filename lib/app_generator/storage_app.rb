# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/app'

class StorageApp < App
  include ChainedSetter

  chained_forward :default_storage,
                  :redundancy => :redundancy,
                  :final_redundancy => :final_redundancy,
                  :transition_time => :transition_time,
                  :min_storage_up_ratio => :min_storage_up_ratio,
                  :min_time_between_cluster_states => :min_time_between_cluster_states,
                  :num_nodes => :num_nodes,
                  :fleet_controller => :fleet_controller,
                  :bucket_split_count => :bucket_split_count,
                  :bucket_split_size => :bucket_split_size,
                  :distribution_bits => :distribution_bits,
                  :max_nodes_per_merge => :max_nodes_per_merge,
                  :documentselection => :documentselection,
                  :garbagecollection => :garbagecollection,
                  :garbagecollectioninterval => :garbagecollectioninterval,
                  :distributor_base_port => :distributor_base_port,
                  :doc_type => :doc_type,
                  :streaming => :streaming,
                  :persistence_threads => :persistence_threads,
                  :num_distributor_stripes => :num_distributor_stripes

  def initialize
    super
    @content.search_type(:none)
    @content.provider(:proton)
    @transition_time = 0
  end

  def default_cluster(name="storage")
    storage_cluster(StorageCluster.new(name).default_group)
    self
  end

  def storage_cluster(cluster)
    @default_storage = cluster
    @content.storage(@default_storage)
    self
  end

  def sd(file_name, params = {})
    @default_storage.sd(file_name, params)
    super(file_name, params)
  end

end
