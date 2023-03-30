# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# -*- coding: utf-8 -*-
require 'search_test'

module ResizeApps
  
  class ResizeAppBase
    attr_reader :dictsize, :numdocs, :num_child_docs, :nodes
    attr_accessor :slack_minhits, :slack_maxdocs_per_group

    include Assertions

    def initialize(test_case, dictsize, numdocs, num_child_docs, nodes, num_hosts, sps)
      @test_case = test_case
      @dictsize = dictsize
      @numdocs = numdocs
      @num_child_docs = num_child_docs
      @nodes = nodes
      @num_hosts = num_hosts
      @sps = sps
      @slack_minhits = 200
      @slack_maxdocs_per_group = 1100
      assert(num_hosts == 1 || num_hosts == 2 || num_hosts >= nodes)
    end

    def nodespec(nodeindex)
      if @num_hosts == 1
        # Override of baseport does not work properly yet
        return NodeSpec.new("node1", nodeindex)
      end
      if @num_hosts == 2
        # Keep things stable on node1, take everything up/down on node2
        if pollnode(true, nodeindex) == pollnode(false, nodeindex)
          return NodeSpec.new("node1", nodeindex)
        else
          return NodeSpec.new("node2", nodeindex)
        end
      end
      # Use full set of nodes
      assert(nodeindex < @num_hosts)
      nni = nodeindex + 1
      return NodeSpec.new("node#{nni}", nodeindex)
    end

    def get_base_sc(parts, r, rc)
      sc = SearchCluster.new("resize")
      if (@num_child_docs == 0)
        sc.sd(@test_case.selfdir + "resize.sd")
      else
        sc.sd(@test_case.selfdir + "resize.sd", { :global => true }).
          sd(@test_case.selfdir + "resizechild.sd")
      end
      sc.num_parts(parts).
        redundancy(r).
        indexing("default").
        ready_copies(rc)
    end
    
    def get_app(sc)
      # TODO: Remove config override when new functionality is added to distributor
      SearchApp.new.
        cluster(sc).
        num_hosts(@num_hosts).
        container(Container.new.
            search(Searching.new).
            docproc(DocumentProcessing.new)).
        storage(StorageCluster.new("resize", 41).distribution_bits(16)).
        validation_override("cluster-size-reduction").
        config(ConfigOverride.new("vespa.config.content.core.stor-distributormanager").
               add("inhibit_merge_sending_on_busy_node_duration_sec", 1)).
        config(ConfigOverride.new("vespa.config.content.fleetcontroller").
               add("min_time_between_new_systemstates", 1000))
    end

    def sp(nodeindex)
      @sps[nodeindex]
    end

    def slack_maxhits
      250
    end

    def slack_mindocs
      60
    end

    def slack_maxdocs
      @slack_maxdocs_per_group * num_groups
    end

    def num_groups
      1
    end
  end

  class GrowApp < ResizeAppBase
    def initialize(test_case, dictsize, numdocs, num_child_docs, num_hosts)
      super(test_case, dictsize, numdocs, num_child_docs, 4, num_hosts,
            [ "0/0", "1/0", "2/0", "3/0" ])
    end

    def get_sc(lr, before)
      get_base_sc(before ? 3 : 4, lr, lr).
        group(create_groups(lr, before))
    end

    def create_groups(lr, before)
      if before
        NodeGroup.new(0, "mytopgroup").
          node(nodespec(0)).
          node(nodespec(1)).
          node(nodespec(2))
      else
        NodeGroup.new(0, "mytopgroup").
          node(nodespec(0)).
          node(nodespec(1)).
          node(nodespec(2)).
          node(nodespec(3))
      end
    end

    def feedname
      "grow"
    end

    def pollnode(before, nodeindex)
      nodeindex < (before ? 3 : 4)
    end

    def growing
      true
    end

    def slack_minhits
      250
    end

  end

  class ShrinkApp < ResizeAppBase
    def initialize(test_case, dictsize, numdocs, num_child_docs, num_hosts)
      super(test_case, dictsize, numdocs, num_child_docs, 4, num_hosts,
            [ "0/0", "1/0", "2/0", "3/0" ])
    end

    def get_sc(lr, before)
      get_base_sc(before ? 4 : 2, lr, lr).
        group(create_groups(lr, before))
    end

    def create_groups(lr, before)
      if before
        NodeGroup.new(0, "mytopgroup").
          node(nodespec(0)).
          node(nodespec(1)).
          node(nodespec(2)).
          node(nodespec(3))
      else
        NodeGroup.new(0, "mytopgroup").
          node(nodespec(0)).
          node(nodespec(1))
      end
    end

    def feedname
      "shrink"
    end

    def pollnode(before, nodeindex)
      nodeindex < (before ? 4 : 2)
    end

    def growing
      false
    end

    def stopnodes
      [ 2, 3 ]
    end

    def slack_maxhits
      1500
    end

    def slack_mindocs
      1100
    end
  end

  class HDGrowApp < ResizeAppBase

    def initialize(test_case, dictsize, numdocs, num_child_docs, num_hosts)
      super(test_case, dictsize, numdocs, num_child_docs, 9, num_hosts,
            [ "0/0", "1/0", "0/1", "1/1", "0/2", "1/2", "2/0", "2/1", "2/2" ])
    end

    def get_sc(lr, before)
      get_base_sc(before ? 6 : 9, lr * 3, lr * 3).
        group(create_groups(lr, before))
    end

    def create_groups(lr, before)
      if before
        NodeGroup.new(0, "mytopgroup").
          distribution("#{lr}|#{lr}|*").
          group(NodeGroup.new(0, "mygroup0").
                node(nodespec(0)).
                node(nodespec(1))).
          group(NodeGroup.new(1, "mygroup1").
                node(nodespec(2)).
                node(nodespec(3))).
          group(NodeGroup.new(2, "mygroup2").
                node(nodespec(4)).
                node(nodespec(5)))
      else
        NodeGroup.new(0, "mytopgroup").
          distribution("#{lr}|#{lr}|*").
          group(NodeGroup.new(0, "mygroup0").
                node(nodespec(0)).
                node(nodespec(1)).
                node(nodespec(6))).
          group(NodeGroup.new(1, "mygroup1").
                node(nodespec(2)).
                node(nodespec(3)).
                node(nodespec(7))).
          group(NodeGroup.new(2, "mygroup2").
                node(nodespec(4)).
                node(nodespec(5)).
                node(nodespec(8)))
      end
    end

    def pollnode(before, nodeindex)
      nodeindex < (before ? 6 : 9)
    end

    def growing
      true
    end

    def feedname
      "hdgrow"
    end

    def num_groups
      3
    end
  end

  class HDShrinkApp < ResizeAppBase

    def initialize(test_case, dictsize, numdocs, num_child_docs, num_hosts)
      super(test_case, dictsize, numdocs, num_child_docs, 9, num_hosts,
            [ "0/0", "1/0", "2/0", "0/1", "1/1", "2/1", "0/2", "1/2", "2/2" ])
    end

    def get_sc(lr, before)
      get_base_sc(before ? 9 : 6, lr * 3, lr * 3).
        group(create_groups(lr, before))
    end

    def create_groups(lr, before)
      if before
        NodeGroup.new(0, "mytopgroup").
          distribution("#{lr}|#{lr}|*").
          group(NodeGroup.new(0, "mygroup0").
                node(nodespec(0)).
                node(nodespec(1)).
                node(nodespec(2))).
          group(NodeGroup.new(1, "mygroup1").
                node(nodespec(3)).
                node(nodespec(4)).
                node(nodespec(5))).
          group(NodeGroup.new(2, "mygroup2").
                node(nodespec(6)).
                node(nodespec(7)).
                node(nodespec(8)))
      else
        NodeGroup.new(0, "mytopgroup").
          distribution("#{lr}|#{lr}|*").
          group(NodeGroup.new(0, "mygroup0").
                node(nodespec(0)).
                node(nodespec(1))).
          group(NodeGroup.new(1, "mygroup1").
                node(nodespec(3)).
                node(nodespec(4))).
          group(NodeGroup.new(2, "mygroup2").
                node(nodespec(6)).
                node(nodespec(7)))
      end
    end

    def pollnode(before, nodeindex)
      return false if nodeindex >= 9
      return true if before
      return (nodeindex % 3) <= 1
    end

    def growing
      false
    end

    def feedname
      "hdshrink"
    end

    def stopnodes
      [ 2, 5, 8 ]
    end

    def slack_maxhits
      1500
    end

    def slack_mindocs
      500
    end

    def num_groups
      3
    end
  end
end

class PollQuery
  attr_reader :doctype, :field, :value, :exphits, :slack_minhits, :slack_maxhits

  def initialize(doctype, field, value, exphits, slack_minhits, slack_maxhits)
    @doctype = doctype
    @field = field
    @value = value
    @exphits = exphits
    @slack_minhits = slack_minhits
    @slack_maxhits = slack_maxhits
  end

  def hit_count_query_string
    "/search/?query=#{@field}:#{@value}&nocache&hits=0&ranking=unranked&timeout=5.0&model.restrict=#{@doctype}"
  end
end

class StatsBase
  def initialize(test_case)
    @test_case = test_case
    reset
  end

  def reset
    @sample_start_time = nil
    @sample_end_time = nil
  end

  def set_sample_start_time
    if @sample_start_time.nil?
      @sample_start_time = Time.new.to_f
    end
  end

  def set_sample_end_time
    @sample_end_time = Time.new.to_f
  end

  def elapsed_sample_time
    if @sample_start_time.nil? || @sample_end_time.nil?
      return 3600.0
    else
      return @sample_end_time - @sample_start_time
    end
  end

  def elapsed_sample_time_normal
    return elapsed_sample_time < 1.0
  end

  def elapsed_sample_time_fmt
    fmt = "%8.3f" % elapsed_sample_time
    unless elapsed_sample_time_normal
      fmt += " (ignored)"
    end
    return fmt
  end
end

class PollQueryStats < StatsBase

  include Assertions

  def initialize(test_case, poll_query, poll_queries_index)
    super(test_case)
    @poll_query = poll_query
    @poll_queries_index = poll_queries_index
    @hit_count = nil
    @hit_count_initial = nil
    @hit_count_prev = nil
    @node_hit_count_vector = nil
    @normalized_node_hit_count_vector = nil
    @normalized_node_hit_count_vector_initial = nil
    @node_hit_count_vector_prev = nil
    @hit_count_min = nil
    @hit_count_max = nil
    @hit_count_min_filtered = nil
  end

  def puts(str)
    @test_case.puts(str)
  end

  def set_hit_count(hit_count, fromstarttime)
    @hit_count = hit_count
    if elapsed_sample_time_normal
      @hit_count_min = hit_count if @hit_count_min.nil? || @hit_count_min > hit_count
      @hit_count_max = hit_count if @hit_count_max.nil? || @hit_count_max < hit_count
      if !fromstarttime.nil? && fromstarttime > 3.0
        @hit_count_min_filtered = hit_count if @hit_count_min_filtered.nil? || @hit_count_min_filtered > hit_count
      end
    end
  end

  def reset
    super
    @hit_count_prev = @hit_count
    @node_hit_count_vector_prev = @node_hit_count_vector
    @node_hit_count_vector = Array.new
    @normalized_node_hit_count_vector = Array.new
  end

  def push_node_hit_count(node_hit_count)
    @node_hit_count_vector.push(node_hit_count)
    @normalized_node_hit_count_vector.push(node_hit_count.to_i)
    set_sample_end_time
  end

  def fixup_node_hit_count(node_hit_count, is_poll_thread, growing, fromstarttime)
    consider_fixup = (is_poll_thread && growing && !@normalized_node_hit_count_vector_initial.nil?)
    # Work around glitch where new dispatch node is used, causing 0 hits
    # temporarily from any node.
    if consider_fixup && fromstarttime.nil? && node_hit_count == 0
      # Use initial value for hits from node instead of glitched value
      @normalized_node_hit_count_vector_initial[@node_hit_count_vector.size]
    elsif consider_fixup && (fromstarttime.nil? || fromstarttime < 3.0) && @normalized_node_hit_count_vector_initial[@node_hit_count_vector.size] == 0 && node_hit_count > 0.6 * @hit_count
      # Search path might be ignored when searching only on new node due to dispatch using old config.
      # Instead, the original nodes are used. Assume this happens if number of hits is greater than
      # 60 percent of hits from all nodes.
      0
    else
      node_hit_count
    end
  end

  def set_initial
    @hit_count_initial = @hit_count
    @normalized_node_hit_count_vector_initial = @normalized_node_hit_count_vector
  end

  def changed_from_initial
    @hit_count != @hit_count_initial || @normalized_node_hit_count_vector != @normalized_node_hit_count_vector_initial
  end

  def changed_from_prev
    @hit_count != @hit_count_prev || @node_hit_count_vector != @node_hit_count_vector_prev
  end

  def report(is_poll_thread)
    fmthc = "%8d" % @hit_count
    fmthcv = []
    @node_hit_count_vector.each do |nhc|
      fmthcv.push("%6s" % nhc.to_s)
    end
    chcs = fmthcv.join(" ")
    if is_poll_thread
      puts "Polling poll_queries_index=#{@poll_queries_index} #{fmthc} hits, nodes #{chcs} #{elapsed_sample_time_fmt}"
    else
      puts "Got     poll_queries_index=#{@poll_queries_index} #{fmthc} hits, nodes #{chcs} #{elapsed_sample_time_fmt}"
    end
  end

  def report_range
    exphits = @poll_query.exphits
    check_minhits = exphits - @poll_query.slack_minhits
    check_maxhits = exphits + @poll_query.slack_maxhits
    puts "Hits poll_queries_index=#{@poll_queries_index} in range from #{@hit_count_min}..#{@hit_count_max} (filtered #{@hit_count_min_filtered}..#{@hit_count_max}) during document move, assert range within #{check_minhits}..#{check_maxhits}"
    assert(@hit_count_max.nil? || @hit_count_max <= check_maxhits, "Too many hits (#{@hit_count_max} > #{check_maxhits})")
    assert(@hit_count_min_filtered.nil? || @hit_count_min_filtered >= check_minhits, "Too few hits (#{@hit_count_min_filtered} < #{check_minhits})")
  end

  def is_unsettled_grow
    node_hit_count_min = nil
    node_hit_count_max = nil
    @node_hit_count_vector.each do |node_hit_count|
      node_hit_count_i = node_hit_count.to_i
      node_hit_count_min = node_hit_count_i if node_hit_count_min.nil? || node_hit_count_min > node_hit_count_i
      node_hit_count_max = node_hit_count_i if node_hit_count_max.nil? || node_hit_count_max < node_hit_count_i
    end
    return node_hit_count_min < node_hit_count_max * 0.9
  end
end

class ExploreDocCount
  attr_reader :expdocs, :slack_mindocs, :slack_maxdocs

  def initialize(doctype, key, expdocs, slack_mindocs, slack_maxdocs)
    @doctype = doctype
    @key = key
    @expdocs = expdocs
    @slack_mindocs = slack_mindocs
    @slack_maxdocs = slack_maxdocs
  end

  def get_node_doc_count(test_case, node)
    if node.nil?
      return 0
    else
      begin
        json = node.get_state_v1_custom_component("/documentdb/#{@doctype}")
        if json.nil?
          return 0
        else
          return json["documents"][@key].to_i
        end
      rescue Exception => e
        test_case.puts(e.message)
        test_case.puts(e.backtrace.inspect)
        return 0
      rescue
        return 0
      end
    end
  end
end

class ExploredDocCountStats < StatsBase
  attr_reader :explore_doc_count

  include Assertions

  def initialize(test_case, explore_doc_count, explore_doc_count_index)
    super(test_case)
    @explore_doc_count = explore_doc_count
    @explore_doc_count_index = explore_doc_count_index
    @node_doc_count_vector = nil
    @doc_count = nil
    @doc_count_min = nil
    @doc_count_max = nil
  end

  def puts(str)
    @test_case.puts(str)
  end

  def set_doc_count(doc_count)
    @doc_count = doc_count
    if elapsed_sample_time_normal
      @doc_count_min = doc_count if @doc_count_min.nil? || @doc_count_min > doc_count
      @doc_count_max = doc_count if @doc_count_max.nil? || @doc_count_max < doc_count
    end
  end

  def reset
    super
    @node_doc_count_vector = Array.new
  end

  def sample(node)
    set_sample_start_time
    @node_doc_count_vector.push(@explore_doc_count.get_node_doc_count(@test_case, node))
    set_sample_end_time
  end

  def aggregate
    doc_count = 0
    @node_doc_count_vector.each do |node_doc_count|
      doc_count += node_doc_count
    end
    set_doc_count(doc_count)
  end

  def report_range
    expdocs = @explore_doc_count.expdocs
    check_mindocs = expdocs - @explore_doc_count.slack_mindocs
    check_maxdocs = expdocs + @explore_doc_count.slack_maxdocs
    puts "Docs poll_explore_index=#{@explore_doc_count_index} in range from #{@doc_count_min}..#{@doc_count_max} during document move, assert range within #{check_mindocs}..#{check_maxdocs}"
    assert(@doc_count_max.nil? || @doc_count_max <= check_maxdocs, "Too many docs (#{@doc_count_max} > #{check_maxdocs})")
    assert(@doc_count_min.nil? || @doc_count_min >= check_mindocs, "Too few docs (#{@doc_count_min} < #{check_mindocs})")
  end

  def report(is_poll_thread)
    fmt_doc_count = "%8d" % @doc_count
    fmt_node_doc_count_vector = []
    @node_doc_count_vector.each do |node_doc_count|
      fmt_node_doc_count_vector.push("%6s" % node_doc_count.to_s)
    end
    fmt_node_doc_counts = fmt_node_doc_count_vector.join(" ")
    if is_poll_thread
      puts "Polling poll_explore_index=#{@explore_doc_count_index} #{fmt_doc_count} docs, nodes #{fmt_node_doc_counts} #{elapsed_sample_time_fmt}"
    else
      puts "Got     poll_explore_index=#{@explore_doc_count_index} #{fmt_doc_count} docs, nodes #{fmt_node_doc_counts} #{elapsed_sample_time_fmt}"
    end
  end
end

class VespaModelWrapper
  attr_reader :vespa_model, :refs

  def initialize(m, cv, vespa_model)
    @m = m
    @cv = cv
    @vespa_model = vespa_model
    @refs = 0
  end

  def increfs
    @refs += 1
  end

  def release
    @m.synchronize do
      @refs -= 1
      if @refs == 0
        @cv.broadcast
      end
    end
  end
end

class ResizePollState

  def initialize(test_case, m, cv, poll_queries, explore_doc_count_vector, qrserver, rapp)
    @test_case = test_case
    @m = m
    @cv = cv
    @poll_queries = poll_queries
    @qrserver = qrserver
    @rapp = rapp
    @active = false
    @thread = nil
    @starttime = nil
    @endtime = nil
    @endtimecandidate = nil
    @poll_query_stats_settle = 0
    @before = true
    @poll_query_stats = Array.new(poll_queries.size) { |poll_queries_index| PollQueryStats.new(test_case, poll_queries[poll_queries_index], poll_queries_index) }
    @explore_doc_count_vector = explore_doc_count_vector
    @explored_doc_count_stats_vector = make_explorered_doc_count_stats_vector(explore_doc_count_vector)
    @vespa_model_wrapper = nil
    @set_initial_poll_query_stats = false
  end

  def puts(str)
    @test_case.puts(str)
  end

  def hitcount(poll_query)
    @qrserver.search(poll_query.hit_count_query_string).hitcount
  end

  def node_hitcount(poll_query, nodeindex)
    sp = @rapp.sp(nodeindex)
    query_string = poll_query.hit_count_query_string + "&model.searchPath=#{sp}"
    @qrserver.search(query_string).hitcount
  end

  def poll_query_stats_changed_from_initial
    changed = false
    @poll_query_stats.each do |poll_query_stat|
      if poll_query_stat.changed_from_initial
        changed = true
      end
    end
    changed
  end

  def poll_query_stats_changed_from_prev
    changed = false
    @poll_query_stats.each do |poll_query_stat|
      if poll_query_stat.changed_from_prev
        changed = true
      end
    end
    changed
  end

  def is_unsettled_grow
    unsettled = false
    @poll_query_stats.each do |poll_query_stat|
      if poll_query_stat.is_unsettled_grow
        unsettled = true
      end
    end
    unsettled
  end

  def report_ranges
    @poll_query_stats.each { |poll_query_stat| poll_query_stat.report_range }
    @explored_doc_count_stats_vector.each { |explored_doc_count_stats| explored_doc_count_stats.report_range }
  end

  def get_vespa_model_wrapper
    @m.synchronize do
      if @vespa_model_wrapper.nil?
        return nil
      else
        @vespa_model_wrapper.increfs
        return @vespa_model_wrapper
      end
    end
  end

  def set_vespa_model(vespa_model)
    @m.synchronize do
      old_vespa_model_wrapper = @vespa_model_wrapper
      if vespa_model.nil?
        @vespa_model_wrapper = nil
      else
        @vespa_model_wrapper = VespaModelWrapper.new(@m, @cv, vespa_model)
      end
      if old_vespa_model_wrapper.nil?
        return
      else
        # Wait for poll thread to stop using old vespa model
        while old_vespa_model_wrapper.refs != 0 && @active
          @cv.wait(@m)
        end
      end
    end
  end

  def make_explorered_doc_count_stats_vector(explore_doc_count_vector)
    Array.new(explore_doc_count_vector.size) { |explore_doc_count_index| ExploredDocCountStats.new(@test_case, explore_doc_count_vector[explore_doc_count_index], explore_doc_count_index) }
  end

  def show_state(is_poll_thread = false, verbose = false)
    # Todo: Extract idealstate_diff metrics from all distributors
    hc = 0
    explored_doc_count_stats_vector = nil
    vespa_model_wrapper = get_vespa_model_wrapper
    begin
      if is_poll_thread
        poll_query_stats = @poll_query_stats
        starttime = @starttime
        if starttime.nil?
            fromstarttime = nil
        else
          fromstarttime = Time.new.to_f - starttime.to_f
        end
        if !vespa_model_wrapper.nil?
          explored_doc_count_stats_vector = @explored_doc_count_stats_vector
        end
      else
        poll_query_stats = Array.new(@poll_queries.size) { |poll_queries_index| PollQueryStats.new(@test_case, @poll_queries[poll_queries_index], poll_queries_index) }
        starttime = nil
        fromstarttime = nil
        if !vespa_model_wrapper.nil?
          explored_doc_count_stats_vector = make_explorered_doc_count_stats_vector(@explore_doc_count_vector)
        end
      end
      @poll_queries.size.times do |poll_queries_index|
        poll_query = @poll_queries[poll_queries_index]
        hc = hitcount(poll_query)
        poll_query_stats[poll_queries_index].set_hit_count(hc, fromstarttime)
        poll_query_stats[poll_queries_index].reset
      end
      if !explored_doc_count_stats_vector.nil?
        explored_doc_count_stats_vector.each do |explored_doc_count_stats|
          explored_doc_count_stats.reset
        end
      end
      before = isbefore
      unsettled = false
      @rapp.nodes.times do |nodeindex|
        @poll_queries.size.times do |poll_queries_index|
          poll_query = @poll_queries[poll_queries_index]
          if @rapp.pollnode(before, nodeindex)
            poll_query_stats[poll_queries_index].set_sample_start_time
            nhc = node_hitcount(poll_query, nodeindex)
            nhc = poll_query_stats[poll_queries_index].fixup_node_hit_count(nhc, is_poll_thread, @rapp.growing, fromstarttime)
            unsettled = true unless nhc == 0 || @rapp.pollnode(false, nodeindex)
            unsettled = true unless nhc != 0 || @rapp.pollnode(true, nodeindex)
          else
            nhc = "-"
          end
          poll_query_stats[poll_queries_index].push_node_hit_count(nhc)
        end
        if !explored_doc_count_stats_vector.nil?
          if @rapp.pollnode(before, nodeindex)
            node = vespa_model_wrapper.vespa_model.search["resize"].searchnode[nodeindex]
          else
            node = nil
          end
          explored_doc_count_stats_vector.each do |explored_doc_count_stats|
            explored_doc_count_stats.sample(node)
          end
        end
      end
      if !explored_doc_count_stats_vector.nil?
        explored_doc_count_stats_vector.each do |explored_doc_count_stats|
          explored_doc_count_stats.aggregate
        end
      end
      if is_poll_thread
        unless @set_initial_poll_query_stats
          poll_query_stats.each { |poll_query_stat| poll_query_stat.set_initial }
          @set_initial_poll_query_stats = true
        end
        if @rapp.growing && is_unsettled_grow
          unsettled = true
        end
        if @starttime.nil?
          if poll_query_stats_changed_from_initial
            puts "Setting poll move starttime"
            @m.synchronize do
              @starttime = Time.new
              @poll_query_stats_settle = 0
              @endtimecandidate = @starttime
            end
          end
        end
        unless @starttime.nil?
          if @endtime.nil?
            if !poll_query_stats_changed_from_prev && !unsettled
              @poll_query_stats_settle = @poll_query_stats_settle + 1
              if @poll_query_stats_settle >= 50
                puts "Setting poll move endtime"
                @m.synchronize do
                  @endtime = @endtimecandidate
                end
              end
            else
              @poll_query_stats_settle = 0
              @endtimecandidate = Time.new
            end
          end
        end
        #      return unless verbose
      end
      poll_query_stats.each { |poll_query_stat| poll_query_stat.report(is_poll_thread) }
      if !explored_doc_count_stats_vector.nil?
        explored_doc_count_stats_vector.each { |explored_doc_count_stats| explored_doc_count_stats.report(is_poll_thread) }
      end
    rescue
      if !vespa_model_wrapper.nil?
        vespa_model_wrapper.release
        vespa_model_wrapper = nil
      end
      raise
    end
    if !vespa_model_wrapper.nil?
      vespa_model_wrapper.release
    end
  end

  def movestarted
    @m.synchronize do
      return !@starttime.nil?
    end
  end

  def hasmovetime
    @m.synchronize do
      return !@starttime.nil? && !@endtime.nil?
    end
  end

  def inactive
    @m.synchronize do
      return !@active
    end
  end

  def isbefore
    @m.synchronize do
      return @before
    end
  end

  def clearbefore
    @m.synchronize do
      @before = false
    end
  end

  def movetime
    return -1.0 unless hasmovetime
    @m.synchronize do
      return @endtime.to_f - @starttime.to_f
    end
  end

  def poll_state(verbose = false)
    # puts "#### starting poll_state thread ####"
    iters = 0
    wantbreak = false
    while true
      @m.synchronize do
        wantbreak = !@active
      end
      if wantbreak
        # puts "#### breaking out of poll_state thread ####"
        break
      end
      # puts "#### running poll_state thread ####"
      show_state(true, verbose)
      sleep 0.2
      iters = iters + 1
    end
    # puts "#### ending poll_state thread ####"
  end

  def create_thread(verbose = false)
    # puts "########## create poll_state thread ##########"
    @m.synchronize do
      @active = true
    end
    thread = Thread.new(verbose) do |pverbose|
      begin
        poll_state(pverbose)
      rescue Exception => e
        puts "poll_state thread got exception"
        puts e.message
        puts e.backtrace.inspect
      rescue
        puts "poll_state thread got unknown exception"
      ensure
        @m.synchronize do
          @active = false
        end
      end
    end
    @m.synchronize do
      @thread = thread
    end
  end

  def join
#    puts "### join 1 ###"
    @m.synchronize do
      return if @thread.nil?
    end
#    puts "### join 2 ###"
    @m.synchronize do
      @active = false
    end
#    puts "### join 3 ###"
    @thread.join
    @thread = nil
#    puts "### join 4 ###"
  end
end

class ResizeContentClusterBase < SearchTest

  def setup
    set_owner("toregge")
    @doc_type = "resize"
    @id_prefix = "id:test:#{@doc_type}::"
    @m = Mutex.new
    @cv = ConditionVariable.new
    @feeder = nil
    @nodestate_cli_app = "vespa-set-node-state"
    @gendata_app = "vespa-gen-testdocs"
    @smalldictsize = 10000
    @bigddictsize = 1000000
    @smallnumdocs = 5000
    @bignumdocs = 100000
    @rapp = nil
    @poll_state = nil
    @valgrind = false
    @poll_queries = nil
    @explore_doc_count_vector = nil
  end

  def setup_late(rapp)
    @rapp = rapp
    @poll_queries = [ PollQuery.new("resize", "a1", "1", rapp.numdocs, rapp.slack_minhits, rapp.slack_maxhits) ]
    expdocs = 2 * rapp.numdocs * rapp.num_groups
    slack_maxdocs = rapp.slack_maxdocs
    if rapp.num_child_docs != 0
      deltanodes = rapp.growing ? rapp.num_groups : 2 * rapp.num_groups
      expdocs = (rapp.nodes - deltanodes) * rapp.numdocs
      slack_maxdocs = deltanodes * rapp.numdocs
    end
    @explore_doc_count_vector = [ ExploreDocCount.new("resize", "ready", expdocs, rapp.slack_mindocs, slack_maxdocs) ]
    if rapp.num_child_docs != 0
      @poll_queries.push(PollQuery.new("resizechild", "a1", "1", rapp.num_child_docs, rapp.slack_minhits, rapp.slack_maxhits))
      @poll_queries.push(PollQuery.new("resizechild", "my_a1", "1", rapp.num_child_docs, rapp.slack_minhits, rapp.slack_maxhits))
      @explore_doc_count_vector.push(ExploreDocCount.new("resizechild", "ready", 2 * rapp.num_child_docs * rapp.num_groups, rapp.slack_mindocs, rapp.slack_maxdocs))
    end
  end

  def hit_count_query_string
    "/search/?query=sddocname:resize&nocache&hits=0&ranking=unranked&timeout=5.0&model.restrict=resize"
  end

  def hit_count_query_string_child
    "/search/?query=sddocname:resizechild&nocache&hits=0&ranking=unranked&timeout=5.0&model.restrict=resizechild"
  end

  def get_cluster
    vespa.storage["resize"]
  end

  def get_clustercontroller
    get_cluster.get_master_fleet_controller
  end

  def set_node_state(nodeindex, state)
    get_clustercontroller.set_node_state("storage", nodeindex, state)
  end

  def wait_node_state(nodeindex, state)
    get_cluster.wait_for_current_node_state("storage", nodeindex, state)
  end

  def get_cluster_state
    get_cluster.get_cluster_state
  end

  def settle_cluster_state(check_states = "ui") 
    clusterstate = get_cluster_state
    get_cluster.wait_for_cluster_state_propagate(clusterstate, 300,
                                                 check_states)
  end

  def settle_cluster_state_allnodes
    settle_cluster_state("uimrd")
  end

  def set_node_state_tryonce(nodeindex, state, reason)
    # fails sometimes just after clustercontrollers start/stop
    vespa.adminserver.
      execute("#{@nodestate_cli_app} --type storage --index #{nodeindex} " +
              "--config-request-timeout 60 " \
              "#{state} #{reason}")
  end

  def set_node_state_doit(nodeindex, state, reason)
    needretry = true
    4.times do |r|
      begin
        if needretry 
          set_node_state_tryonce(nodeindex, state, reason)
          needretry = false
        end
      rescue Exception => e
        puts "set_node_state_tryonce(#{nodeindex}, #{state}, #{reason}) got exception, retry=#{r}"
        puts e.message
        puts e.backtrace.inspect
        raise if r >= 3
      end
    end
  end

  def set_node_down_doit(nodeindex)
    set_node_state_doit(nodeindex, "down", "resizedown")
  end

  def set_node_retired_doit(nodeindex)
    set_node_state_doit(nodeindex, "retired", "resizeretired")
  end

  def set_node_down_settle(nodeindex)
    wait_node_state(nodeindex, 'd')
  end

  def set_node_retired_settle(nodeindex)
    wait_node_state(nodeindex, 'r')
  end

  def set_node_retired(nodeindex)
    set_node_retired_doit(nodeindex)
    set_node_retired_settle(nodeindex)
    settle_cluster_state_allnodes
  end

  def set_nodes_retired(nodes)
    nodes.each do |nodeindex|
      set_node_retired_doit(nodeindex)
    end
    nodes.each do |nodeindex|
      set_node_retired_settle(nodeindex)
    end
    settle_cluster_state_allnodes
  end

  def set_nodes_down(nodes)
    nodes.each do |nodeindex|
      set_node_down_doit(nodeindex)
    end
    nodes.each do |nodeindex|
      set_node_down_settle(nodeindex)
    end
    settle_cluster_state_allnodes
  end

  def stop_node
    @leave_loglevels = true
    vespa.stop_base
    @leave_loglevels = false
  end

  def start_node
    vespa.start_base
    # vespa.adminserver.execute("vespa-logctl -c configserver debug=on", :exceptiononfailure => false)
    # vespa.adminserver.execute("vespa-logctl -c configproxy debug=on", :exceptiononfailure => false)
    sleep 1 # to make sure vespa-logctl has effect
  end

  def stop_retired_nodes
    if @num_hosts == 1
      stopnodes = @rapp.stopnodes
      stopnodes.each do |nodeindex|
        vespa.content_node("resize", nodeindex).stop
      end
      wait_timeout = 30
      wait_timeout *= VALGRIND_TIMEOUT_MULTIPLIER if @valgrind
      stopnodes.each do |nodeindex|
        needretry = true
        4.times do |r|
          if needretry 
            begin
              vespa.storage["resize"].
                wait_for_current_node_state("storage", nodeindex, 'sdm',
                                            wait_timeout)
              needretry = false
            rescue Exception => e
              puts "stop_retired_nodes got exception, retry=#{r}"
              puts e.message
              puts e.backtrace.inspect
              if r >= 3
                raise
              end
            rescue
              puts "stop_retired_nodes got unknown exception, retry=#{r}"
              if r >= 3
                raise
              end
            end
          end
        end
      end
    else
      stopnodes = { }
      @rapp.stopnodes.each do |nodeindex|
        name = vespa.content_node("resize", nodeindex).name
        puts "(stop_retired_nodes) Name for nodeindex #{nodeindex} is #{name}"
        stopnodes[name] = vespa.nodeproxies[name]
      end
      vespa.stop_base(stopnodes)
    end
  end

  def start_select_nodes(startnodes)
    threadlist = []
    startnodes.each_value do |handle|
      vespa.setup_sanitizers(handle)
      vespa.setup_valgrind(handle)
      threadlist << Thread.new(handle) do |my_handle|
        my_handle.start_base
      end
    end
    threadlist.each do |thread|
      thread.join
    end
  end

  def start_initial_nodes
    startnodes = { }
    @rapp.nodes.times do |nodeindex|
      if @rapp.pollnode(true, nodeindex)
        name = vespa.content_node("resize", nodeindex).name
        puts "(start_initial_nodes) Name for nodeindex #{nodeindex} is #{name}"
        startnodes[name] = vespa.nodeproxies[name]
      end
    end
    start_select_nodes(startnodes)
  end
  
  def start_new_nodes
    if @num_hosts == 1
      startnodes = [ ]
      @rapp.nodes.times do |nodeindex|
        unless @rapp.pollnode(true, nodeindex)
          startnodes << nodeindex
        end
      end
      startnodes.each do |nodeindex|
        vespa.content_node("resize", nodeindex).start
      end
      wait_timeout = 30
      wait_timeout *= VALGRIND_TIMEOUT_MULTIPLIER if @valgrind
      startnodes.each do |nodeindex|
        needretry = true
        4.times do |r|
          if needretry 
            begin
              vespa.storage["resize"].
                wait_for_current_node_state("storage", nodeindex, 'u',
                                            wait_timeout)
              needretry = false
            rescue Exception => e
              puts "start_new_nodes got exception, retry=#{r}"
              puts e.message
              puts e.backtrace.inspect
              if r >= 3
                raise
              end
            rescue
              puts "start_new_nodes got unknown exception, retry=#{r}"
              if r >= 3
                raise
              end
            end
          end
        end
      end
    else
      startnodes = { }
      @rapp.nodes.times do |nodeindex|
        unless @rapp.pollnode(true, nodeindex)
          name = vespa.content_node("resize", nodeindex).name
          puts "(start_new_nodes) Name for nodeindex #{nodeindex} is #{name}"
          startnodes[name] = vespa.nodeproxies[name]
        end
      end
      start_select_nodes(startnodes)
    end
  end

  def restart_node(app, clean = false)
    stop_node
#    clean_node if clean
    deploy_app(app, :no_init_logging => true)
    start_node
    wait_for_content_cluster
  end

  def wait_for_content_cluster
    vespa.storage["resize"].wait_until_all_services_up(600)
  end

  def make_workdir(basedir)
    vespa.adminserver.remote_eval("Dir.mkdir(\"#{basedir}\")")
  end

  def clean_workdir(basedir)
    vespa.adminserver.
      remote_eval("FileUtils.remove_dir(\"#{basedir}\", :force => true)")
  end

  def generate_feed(name, dictsize, numdocs, num_child_docs, basedir)
    @workdir = basedir
    clean_workdir(basedir)
    make_workdir(basedir)
    basedirarg = "--basedir #{basedir}"
    vespa.adminserver.
      execute("#{@gendata_app} gentestdocs #{basedirarg} " +
              "--idtextfield i1 " +
              "--randtextfield i2 " +
              "--consttextfield a1,1 " +
              "--numwords #{dictsize} " +
              "--mindocid 0 " +
              "--docidlimit #{numdocs} " +
              "--doctype resize " +
              "--json " +
           name)
    if num_child_docs != 0
      vespa.adminserver.
        execute("#{@gendata_app} gentestdocs #{basedirarg} " +
                "--idtextfield i1 " +
                "--randtextfield i2 " +
                "--consttextfield a1,1 " +
                "--prefixtextfield ref,id:test:resize::,#{numdocs} " +
                "--numwords #{dictsize} " +
                "--mindocid 0 " +
                "--docidlimit #{num_child_docs} " +
                "--doctype resizechild " +
                "--json " +
                name + "-child")
    end
  end

  def clean_feed
    return if @workdir.nil?
    clean_workdir(@workdir)
    @workdir = nil
  end

  def startandfeed(app, feedname, dictsize, numdocs, num_child_docs, basedir)
    deploy_app(app)
    generate_feed(feedname, dictsize, numdocs, num_child_docs, basedir)
    start_initial_nodes
    wait_for_content_cluster
    feedfile("#{basedir}/#{feedname}",
             :localfile => true, :timeout => 240)
    wait_for_hitcount(hit_count_query_string, numdocs)
    if num_child_docs != 0
      feedfile("#{basedir}/#{feedname}-child",
               :localfile => true, :timeout => 240)
      wait_for_hitcount(hit_count_query_string_child, num_child_docs)
    end
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def unregister_poll_state
    @poll_state.join unless @poll_state.nil?
    @poll_state = nil
  end

  def create_poll_state(register = false)
    res = ResizePollState.new(self, @m, @cv, @poll_queries, @explore_doc_count_vector,
                              qrserver, @rapp)
    if register
      unregister_poll_state
      @poll_state = res
    end
    return res
  end

  def start_poll_state(verbose = false)
    poll_state = create_poll_state(true)
    poll_state.show_state(false, true)
    poll_state.create_thread(verbose)
    return poll_state
  end

  def show_state
    create_poll_state().show_state(false, true)
  end

  def continue_poll(poll_state)
    300.times do |i|
      wantbreak = poll_state.hasmovetime || poll_state.inactive
      if poll_state.movestarted
        poll_state.show_state(false, true)
      else
        if i == 0
          if wantbreak
            puts "Not waiting for document moves"
          else
            puts "Waiting for document moves to start"
          end
        end
      end
      break if wantbreak
      sleep 1
    end
    unregister_poll_state
    poll_state.report_ranges
    if poll_state.hasmovetime
      movetime = poll_state.movetime
      puts "Polled document move time is #{movetime} seconds"
      return movetime
    else
#      raise "Failed to get move time"
      puts "Failed to get move time"
      return nil
    end
  end

  def redeploy(app)
    node = vespa.search["resize"].first
    deploy_output = deploy_app(app)
    gen = get_generation(deploy_output).to_i
    node.wait_for_config_generation(gen)
    return deploy_output
  end

  def redeploy_and_poll(app)
    poll_state = start_poll_state
    redeploy(app)
    continue_poll(poll_state)
  end

  def wait_for_hitcounts(numdocs, num_child_docs)
    wait_for_hitcount(hit_count_query_string, numdocs)
    if num_child_docs != 0
      wait_for_hitcount(hit_count_query_string_child, num_child_docs)
    end
  end

  def assert_hitcounts(numdocs, num_child_docs)
    assert_hitcount(hit_count_query_string, numdocs)
    if num_child_docs != 0
      assert_hitcount(hit_count_query_string_child, num_child_docs)
    end
  end

  def perform_grow(rapp)
    set_expected_logged(/Rpc port config has changed/)
    setup_late(rapp)
    bsc = rapp.get_sc(2, true)
    bapp = rapp.get_app(bsc)
    asc = rapp.get_sc(2, false)
    aapp = rapp.get_app(asc)
    puts "perform grow before" 
    puts bapp.services_xml
    puts "perform grow after"
    puts aapp.services_xml
    numdocs = rapp.numdocs
    num_child_docs = rapp.num_child_docs
    startandfeed(bapp, rapp.feedname, rapp.dictsize, numdocs, num_child_docs, dirs.tmpdir + "resizefeed")
    poll_state = start_poll_state
    redeploy(aapp)
    start_new_nodes
    poll_state.clearbefore
    poll_state.set_vespa_model(vespa)
    continue_poll(poll_state)
    assert_hitcounts(numdocs, num_child_docs)
    poll_state.set_vespa_model(nil)
    restart_node(aapp)
    sleep 4
    poll_state.show_state(false, true)
    wait_for_hitcounts(numdocs, num_child_docs)
  end

  def perform_shrink(rapp)
    setup_late(rapp)
    bsc = rapp.get_sc(2, true)
    bapp = rapp.get_app(bsc)
    asc = rapp.get_sc(2, false)
    aapp = rapp.get_app(asc)
    puts "perform shrink before" 
    puts bapp.services_xml
    puts "perform shrink after" 
    puts aapp.services_xml
    puts rapp.stopnodes
    numdocs = rapp.numdocs
    num_child_docs = rapp.num_child_docs
    startandfeed(bapp, rapp.feedname, rapp.dictsize, numdocs, num_child_docs, dirs.tmpdir + "/resizefeed")
    poll_state = start_poll_state
    poll_state.set_vespa_model(vespa)
    set_nodes_retired(rapp.stopnodes)
    continue_poll(poll_state)
    assert_hitcounts(numdocs, num_child_docs)
    poll_state.set_vespa_model(nil)
    set_nodes_down(rapp.stopnodes)
    sleep 4
    poll_state.show_state(false, true)
    assert_hitcounts(numdocs, num_child_docs)
    stop_retired_nodes
    sleep 4
    poll_state.show_state(false, true)
    restart_node(aapp)
    sleep 4
    poll_state.show_state(false, true)
    wait_for_hitcounts(numdocs, num_child_docs)
  end

  def teardown
    unregister_poll_state
    clean_feed
    stop
  end
end
