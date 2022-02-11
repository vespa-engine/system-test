# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/app'

class SearchApp < App

  chained_forward :default_search,
                  :cluster_name => :set_name,
                  :redundancy => :redundancy,
                  :ready_copies => :ready_copies,
                  :visibility_delay => :visibility_delay,
                  :flush_on_shutdown => :flush_on_shutdown,
                  :garbagecollection => :garbagecollection,
                  :garbagecollectioninterval => :garbagecollectioninterval,
                  :doc_type => :doc_type,
                  :threads_per_search => :threads_per_search,
                  :allowed_lid_bloat => :allowed_lid_bloat,
                  :num_summary_threads => :num_summary_threads,
                  :initialize_threads => :initialize_threads,
                  :hwinfo_disk_writespeed => :hwinfo_disk_writespeed,
                  :hwinfo_disk_shared => :hwinfo_disk_shared,
                  :tune_searchnode => :tune_searchnode,
                  :disable_flush_tuning => :disable_flush_tuning,
                  :indexing => :indexing,
                  :persistence_threads => :persistence_threads,
                  :cpu_socket_affinity => :cpu_socket_affinity,
                  :resource_limits => :resource_limits,
                  :proton_resource_limits => :proton_resource_limits

  def initialize
    super
    @default_search = SearchCluster.new
    @content.search(@default_search)
    elastic
    config(ConfigOverride.new("vespa.config.content.fleetcontroller").
               add("min_time_between_new_systemstates", 100).
               add("min_distributor_up_ratio", 0.1).
               add("min_storage_up_ratio", 0.1).
               add("storage_transition_time", 0))
  end

  def cluster(search_cluster)
    if !search_cluster.docprocs.empty?
      raise "Adding docprocs is not valid - refer to a docproc cluster and chain explicitly, and inherit 'indexing' from that chain."
    end

    if @default_search != nil
      @content.clear_search
      @content.use_global_sd_files(true)
      @default_search = nil
    end
    @content.search(search_cluster)

    self
  end

  def sd(file_name, params = {})
    super(file_name, params)
    @default_search.sd(file_name, params) unless @default_search.nil?
    self
  end

  def num_parts(value)
    @default_search.num_parts(value)
    # Avoid using too much memory when we have multiple parts.
    # This must be called last in order to propagate jvm options to all components.
    if value > 1
      jvm_options = "-Xms64m -Xmx256m"
      @containers.jvmoptions = jvm_options
      @content._qrservers.default_jvm_options = jvm_options
    end
    self
  end

  def content_distribution_type(type)
    @content.distribution_type = type
    self
  end

  def search_type(value)
    if value == "ELASTIC"
      elastic
    elsif value == "STREAMING"
      streaming
    elsif value == "NONE"
      no_search
    end
    self
  end

  def elastic()
    @content.search_type(:indexed)
    self
  end

  def streaming()
    @content.search_type(:streaming)
    self
  end

  def no_search()
    @content.search_type(:none)
    self
  end

  def storage_clusters
    @content.get_storage_clusters
  end

end
