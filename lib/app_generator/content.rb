# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Content
  include ChainedSetter

  attr_reader :sd_files
  attr_reader :_qrservers
  attr_writer :distribution_type

  chained_setter :qrservers, :_qrservers
  chained_setter :search_type, :search_type
  chained_setter :use_global_sd_files
  chained_forward :search_clusters, :search => :push
  chained_forward :storage_clusters, :storage => :push

  def initialize
    @sd_files = []
    @_qrservers = Qrservers.new
    @search_type = :indexed
    @distribution_type = nil
    @provider = :proton
    @search_clusters = []
    @storage_clusters = []
    @use_global_sd_files = false
  end

  def sd(file_name, params = {})
    @sd_files.push(SDFile.new(file_name, (params[:global] ? true : false)))
    self
  end

  def clear_search()
    @search_clusters = []
    self
  end

  def set_indexing_cluster(name)
    @search_clusters.each do |cluster|
      cluster.indexing_cluster(name)
    end
  end

  def all_sd_files
    all = [].concat(@sd_files)
    @search_clusters.each do |cluster|
      all.concat(cluster.sd_files)
    end
    all
  end

  def provider(value)
    @provider = value
    @storage_clusters.each do |cluster|
      cluster.provider(value)
    end
    self
  end

  def is_indexed
    @search_type == :indexed
  end

  def storage_clusters_or_default
    return @storage_clusters unless @storage_clusters.empty?
    return [StorageCluster.new("storage").default_group]
  end

  def get_storage_clusters
    @storage_clusters
  end

  def to_indexed_xml(indent)
    XmlHelper.new(indent).
      to_xml(@_qrservers, :to_container_xml).
      to_xml(match_search_and_storage_clusters, :to_indexed_xml).to_s
  end

  class ContentCluster
    def initialize(search, storage)
      @search = search
      @storage = storage
      if search
        @name = search.get_storage_cluster
      else
        @name = storage.get_name
      end
      @distribution_type = nil
    end

    def set_distribution_type(type)
      @distribution_type = type
      self
    end

    def needs_cluster_tuning_tag?
      @distribution_type != nil ||
      @search.get_dispatch_policy != nil ||
      @search.get_min_node_ratio_per_group != nil ||
      @search.get_resource_limits != nil
    end

    # @search's <redundancy> and <group> takes precedence.
    def to_indexed_xml(indent)
      if @search
        xml = XmlHelper.new(indent).
            tag("content", :id => @name, :version => "1.0")
        if needs_cluster_tuning_tag?
          tuningTag = xml.tag("tuning")
          if (@distribution_type != nil)
            tuningTag.tag("distribution", :type => @distribution_type).close_tag
          end
          if (@search.get_dispatch_policy)
            dispatch = tuningTag.tag("dispatch")
            dispatch.tag("dispatch-policy").content(@search.get_dispatch_policy).close_tag
            dispatch.close_tag
          end
          if @search.get_min_node_ratio_per_group != nil
            tuningTag.tag("min-node-ratio-per-group").content(@search.get_min_node_ratio_per_group).close_tag
          end
          if @search.get_resource_limits != nil
            tuningTag.to_xml(@search.get_resource_limits)
          end
          xml = tuningTag.close_tag
        end
        xml.to_xml(@search, :cluster_parameters_xml).
            to_xml(@storage, :cluster_parameters_xml).to_s
      else
        @storage.to_xml(indent)
      end
    end

    def to_streaming_xml(indent)
      XmlHelper.new(indent).tag("content", :id => @name, :version => "1.0").
        to_xml(@search, :streaming_cluster_parameters_xml).
        to_xml(@storage, :streaming_cluster_parameters_xml).to_s
    end
  end

  def match_search_and_storage_clusters
    storage_map = {}
    @storage_clusters.each do |storage|
      storage_map[storage.get_name] = storage
    end
    clusters = []
    @search_clusters.each do |search|
      clusters.push(ContentCluster.new(
          search, storage_map[search.get_storage_cluster]).set_distribution_type(@distribution_type))
      storage_map[search.get_storage_cluster] = nil
    end
    storage_map.each do |name, storage|
      if storage
        clusters.push(ContentCluster.new(nil, storage).set_distribution_type(@distribution_type))
      end
    end
    clusters
  end

  def to_streaming_xml(indent)
    XmlHelper.new(indent).
	to_xml(@_qrservers, :to_container_xml).
        to_xml(match_search_and_storage_clusters, :to_streaming_xml).to_s
  end

  def to_xml(indent)
    qrs_clusters = @_qrservers.qrserver_list
    if qrs_clusters.length > 1
      for i in 1..(qrs_clusters.length-1)
        qrs_clusters[i].set_baseport(4080 + 10*i)
      end
    end

    if @search_type == :indexed
      return to_indexed_xml(indent)
    elsif @search_type == :streaming
      return to_streaming_xml(indent)
    else
      raise "Unknown search type #{@search_type}"
    end
  end

end
