# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class StorageCluster
  include ChainedSetter

  chained_setter :redundancy
  chained_setter :final_redundancy
  chained_setter :distribution_bits
  chained_setter :bucket_split_size
  chained_setter :bucket_split_count
  chained_setter :max_nodes_per_merge
  chained_setter :distributor_base_port
  chained_setter :provider
  chained_setter :persistence_threads
  chained_setter :documentselection
  chained_setter :garbagecollection
  chained_setter :garbagecollectioninterval
  chained_setter :selection, :documentselection
  chained_setter :num_distributor_stripes
  chained_forward :fleet_controllers,
                  :min_storage_up_ratio => :min_storage_up_ratio,
                  :min_distributor_up_ratio => :min_distributor_up_ratio,
                  :transition_time => :transition_time,
                  :fleet_controller => :fleet_controller,
                  :min_time_between_cluster_states => :min_time_between_cluster_states,
                  :disable_fleet_controllers => :disable
  chained_forward :config, :config => :add
  chained_forward :groups, :group => :push

  def initialize(name = "storage", redundancy = 1)
    @name = name
    @redundancy = redundancy
    @final_redundancy = nil
    @groups = []
    @bucket_split_size = nil
    @bucket_split_count = nil
    @persistence_threads = nil
    @documentselection = nil
    @garbagecollection = nil
    @garbagecollectioninterval = nil
    @config = ConfigOverrides.new
    @fleet_controllers = FleetControllers.new
    @provider = :proton
    @sd_files = []
    @doc_types = []
    @streaming = false
    @max_nodes_per_merge = 16
    @num_distributor_stripes = nil
  end

  def sd(file_name, params = {})
    @sd_files.push(SDFile.new(file_name, (params[:global] ? true : false)))
    self
  end

  def get_name
    @name
  end

  def default_group
    group(NodeGroup.new(0, nil).default_nodes(1, 0))
    self
  end

  def num_nodes(num)
    @groups.clear
    group(NodeGroup.new(0, nil).default_nodes(num, 0))
    self
  end

  def doc_type(name, selection=nil)
    @doc_types << DocumentTypeDecl.new(name, selection)
    self
  end

  def streaming
    @streaming = true
    self
  end

  def provider_xml(indent)
    XmlHelper.new(indent).
      tag("engine").
      tag_always(@provider).to_s
  end

  def documentdefinitions_xml(indent)
    # Explicit doc type listing takes precedence, if present.
    sds = @doc_types.empty? ? @sd_files : []

    mode = @streaming ? "streaming" : "store-only"

    XmlHelper.new(indent).
      tag("documents", :"selection" => @documentselection,
                       :"garbage-collection" => @garbagecollection,
                       :"garbage-collection-interval" => @garbagecollectioninterval).
        list_do(sds) { |helper, sd|
          helper.tag("document", :mode => mode, :type => File.basename(sd.file_name, '.sd')).
          close_tag }.
        list_do(@doc_types) { |helper, dt|
          helper.tag("document", :type => dt.type, :selection => dt.selection, :mode => mode).
          close_tag 
        }
  end

  def content_streaming_xml(indent)
    if @streaming
      if @sd_files.size != 1
        raise "Streaming search only supports 1 sd file per cluster, " +
          "got #{@sd_files.size} (#{@sd_files.join(",")})"
      end
      sd_name = File.basename(@sd_files[0], '.sd')
    else
      nil
    end
  end

  def distributormanager_config(indent)
    if @num_distributor_stripes
      cfg = ConfigOverride.new("vespa.config.content.core.stor-distributormanager")
      cfg.add("num_distributor_stripes", @num_distributor_stripes)
      return XmlHelper.new(indent).to_xml(cfg)
    else
      return ""
    end
  end

  def cluster_parameters_xml(indent, redundancy)
    xml = XmlHelper.new(indent).
      tag("redundancy").content(redundancy).close_tag.
      to_xml(@config).
      call {|indent| distributormanager_config(indent)}.
      tag("tuning").
      tag("bucket-splitting", :"max-documents" => @bucket_split_count,
                              :"max-size" => @bucket_split_size,
                              :"minimum-bits" => @distribution_bits).close_tag
    if (@max_nodes_per_merge != 16)
      xml = xml.tag("merges", :"max-nodes-per-merge" => @max_nodes_per_merge).close_tag
    end
    xml.to_xml(@persistence_threads).
      to_xml(@fleet_controllers, :tuning_xml).
      close_tag.
      call {|indent| documentdefinitions_xml(indent)}.to_s
  end

  def streaming_cluster_parameters_xml(indent, include_redundancy = true)
    cluster_parameters_xml(indent, include_redundancy ? @redundancy : nil) +
    provider_xml(indent)
  end

  def to_xml(indent)
    redundancy = @redundancy
    replyafter = nil

    if @final_redundancy
      replyafter = @redundancy
      @redundancy = @final_redundancy
    end

    XmlHelper.new(indent).
      tag("content", :id => @name,
	             :version => "1.0",
                     :"distributor-base-port" => @distributor_base_port).
        tag("redundancy", :"reply-after" => replyafter).content(@redundancy).close_tag.
        to_xml(@groups).
        call {|indent| streaming_cluster_parameters_xml(indent, false)}.to_s
  end

end
