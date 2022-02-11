# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class SearchCluster
  include ChainedSetter

  attr_reader :sd_files, :docprocs

  chained_setter :selection, :documents_selection
  chained_setter :visibility_delay
  chained_setter :flush_on_shutdown
  chained_setter :indexing, :indexing_cluster
  chained_setter :indexing_chain
  chained_setter :storage_cluster
  chained_setter :num_parts
  chained_setter :redundancy
  chained_setter :ready_copies
  chained_setter :indexing_cluster
  chained_setter :garbagecollection
  chained_setter :garbagecollectioninterval
  chained_setter :threads_per_search
  chained_setter :allowed_lid_bloat
  chained_setter :num_summary_threads
  chained_setter :initialize_threads
  chained_setter :hwinfo_disk_writespeed
  chained_setter :hwinfo_disk_shared
  chained_setter :dispatch
  chained_setter :search_coverage
  chained_setter :dispatch_policy
  chained_setter :min_node_ratio_per_group
  chained_setter :persistence_threads
  chained_setter :resource_limits
  chained_setter :proton_resource_limits
  chained_forward :config, :config => :add
  chained_forward :docprocs, :docproc => :push
  chained_forward :node_groups, :group => :push

  # only for compatibility with old SearchApp style.
  chained_setter :set_name, :name

  def initialize(name = "search")
    @name = name
    @sd_files = []
    @doc_types = []
    @visibility_delay = nil
    @flush_on_shutdown = nil
    @documents_selection = nil
    @dispatch_policy= nil
    @min_node_ratio_per_group = nil
    @num_parts = 1
    @redundancy = 1
    @ready_copies = 1
    @docprocs = []
    @indexing_cluster = nil
    @indexing_chain = nil
    @storage_cluster = nil
    @tuning = {}
    @node_groups = []
    @config = ConfigOverrides.new
    @garbagecollection = nil
    @garbagecollectioninterval = nil
    @threads_per_search = 4
    @allowed_lid_bloat = 100
    @num_summary_threads = nil
    @initialize_threads = 16
    @dispatch = nil
    @search_coverage = nil
    @hwinfo_disk_writespeed = 150.0
    @hwinfo_disk_shared = true
    @persistence_threads = nil
    @resource_limits = nil
    @proton_resource_limits = nil
  end

  def sd(file_name, params = {})
    @sd_files.push(SDFile.new(file_name, (params[:global] ? true : false), params[:selection]))
    self
  end

  def get_storage_cluster
    @storage_cluster || @name
  end

  def get_dispatch_policy
    return @dispatch_policy
  end

  def get_min_node_ratio_per_group
    return @min_node_ratio_per_group
  end

  def get_node_groups
    return @node_groups unless @node_groups.empty?
    node_groups = []
    for i in 0...@redundancy do
      node_groups.push(NodeGroup.new(i, "mygroup").
                       default_nodes(@num_parts, 0))
    end
    node_groups
  end

  def get_resource_limits
    @resource_limits
  end

  def doc_type(name, selection=nil)
    @doc_types << DocumentTypeDecl.new(name, selection)
    self
  end

  def docdefinitions_xml(indent, indexing_mode)
    # Explicit doc type listing takes precedence, if present.
    sds = @doc_types.empty? ? @sd_files : []
    XmlHelper.new(indent).
      tag("documents", :selection => @documents_selection,
          :"garbage-collection" => @garbagecollection,
          :"garbage-collection-interval" => @garbagecollectioninterval).
        tag("document-processing",  "cluster".to_sym => @indexing_cluster, "chain".to_sym => @indexing_chain).close_tag.
        list_do(sds) { |helper, sd|
          helper.tag("document", :type => File.basename(sd.file_name, '.sd'),
                                 :mode => indexing_mode,
                                 :global => (sd.global ? "true" : nil),
                                 :selection => sd.selection).
          close_tag }.
        list_do(@doc_types) { |helper, dt|
          helper.tag("document", :type => dt.type, :selection => dt.selection, :mode => indexing_mode).
          close_tag }
  end

  def proton_config(indent)
    proton = ConfigOverride.new("vespa.config.search.core.proton")
    proton.add("numthreadspersearch", @threads_per_search)
    proton.add("numsummarythreads", @num_summary_threads) if @num_summary_threads != nil
    proton.add("initialize", ConfigValue.new("threads", @initialize_threads))
    proton.add("lidspacecompaction", ConfigValue.new("allowedlidbloat", @allowed_lid_bloat))
    if @hwinfo_disk_shared || !@hwinfo_disk_writespeed.nil?
      values = ConfigValues.new
      if @hwinfo_disk_shared
        values.add("shared", @hwinfo_disk_shared)
      end
      if !@hwinfo_disk_writespeed.nil?
        values.add("writespeed", @hwinfo_disk_writespeed)
      end
      proton.add("hwinfo", ConfigValue.new("disk", values))
    else
      if @hwinfo_disk_shared
        proton.add("hwinfo", ConfigValue.new("disk", ConfigValue.new("shared", @hwinfo_disk_shared)))
      end
      if !@hwinfo_disk_writespeed.nil?
        proton.add("hwinfo", ConfigValue.new("disk", ConfigValue.new("writespeed", @hwinfo_disk_writespeed)))
      end
    end
    XmlHelper.new(indent).to_xml(proton)
  end

  def dispatch_xml(indent)
    @dispatch.to_xml(indent) if @dispatch != nil
  end

  def search_coverage_xml(indent)
    @search_coverage.to_xml(indent) if @search_coverage != nil
  end

  def indexing_xml_elastic(indent)
  end

  def cluster_parameters_xml(indent, search_type_tag = "index", search_type_attrs = {})
    XmlHelper.new(indent).
      tag("redundancy").content(@redundancy).close_tag.
      tag("tuning").to_xml(@persistence_threads).close_tag.
      to_xml(@config).
      call {|indent| proton_config(indent)}.
      call {|indent| indexing_xml_elastic(indent)}.
      call {|indent| docdefinitions_xml(indent, search_type_tag)}.
      call {|indent| dispatch_xml(indent)}.
      call {|indent| search_coverage_xml(indent)}.
      to_xml(get_node_groups[0].strip_name()).
      tag("engine").
        tag("proton").
          tag("visibility-delay").content(@visibility_delay).close_tag.
          tag("searchable-copies").content(var_if(search_type_tag == "index", @ready_copies)).close_tag.
          tag("flush-on-shutdown").content(@flush_on_shutdown).close_tag.
          call {|indent| tuning_to_xml(indent)}.
          call {|indent| proton_resource_limits_to_xml(indent)}.to_s
  end

  def tune_searchnode(map)
    @tuning[:searchnode] = {} if !@tuning.key?(:searchnode)
    @tuning[:searchnode].merge!(map)
    self
  end

  def tuning_to_xml(indent)
    XmlHelper.new(indent).
      tag("tuning").content(tuning_sub_tag_to_xml(indent + "  ", @tuning)).close_tag.to_s
  end

  def proton_resource_limits_to_xml(indent)
    @proton_resource_limits.to_xml(indent) if @proton_resource_limits != nil
  end

  def tuning_sub_tag_to_xml(indent, sub_tag)
    helper = XmlHelper.new(indent)
    sub_tag.each do |key,value|
      if value.kind_of? Hash
        helper.tag(key.to_s).content(tuning_sub_tag_to_xml(indent + "  ", value)).close_tag
      else
        helper.tag(key.to_s).content(value.to_s).close_tag
      end
    end
    helper.to_s
  end

  def to_indexed_xml(indent)
    XmlHelper.new(indent).
      tag("content", :id => @name,
	             :version => "1.0").
        call {|indent| cluster_parameters_xml(indent)}.to_s
  end

  def streaming_cluster_parameters_xml(indent)
    if @sd_files.size != 1
      raise "Streaming search only supports 1 sd file per cluster, " +
            "got #{@sd_files.size} (#{@sd_files.join(",")})"
    end

    sd_name = File.basename(@sd_files[0].file_name, '.sd')
    cluster_parameters_xml(indent, "streaming", { :name => sd_name })
  end

  def disable_flush_tuning
    tune_searchnode(
      {:flushstrategy => {:native => { :total => {:maxmemorygain => 32000000000, :diskbloatfactor => 10.0},
                                       :component => {:maxmemorygain => 32000000000, :diskbloatfactor => 10.0, :maxage => 86400},
                                       :transactionlog => {:maxsize => 10000000000}
                                     } } }
    )
  end
end
