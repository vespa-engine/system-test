# Copyright Vespa.ai. All rights reserved.

class WandPerformanceSpec
  attr_reader :type
  attr_reader :clients
  attr_reader :wand_hits
  attr_reader :search_threads
  attr_reader :doc_count
  attr_reader :filter
  attr_reader :threshold_factor

  def initialize(clients, wand_hits, search_threads, doc_count, filter="", threshold_factor = 1.0)
    @type = self.class.stype
    @clients = clients
    @wand_hits = wand_hits
    @search_threads = search_threads
    @doc_count = doc_count
    @filter = filter
    @threshold_factor = threshold_factor
  end

  def get_wand_field
    "features"
  end
  
  def get_wand_type
    @type
  end

  def get_rank_profile_base
    case @search_threads
    when 1
      return "one-search-thread"
    when 2
      return "two-search-threads"
    when 4
      return "four-search-threads"
    when 8
      return "eight-search-threads"
    when 16
      return "sixteen-search-threads"
    else
      return "one-search-thread"
    end
  end

  def get_rank_profile
    get_rank_profile_base
  end

  def get_fbench_append_str
    str = "&wand.field=#{get_wand_field}&wand.heapSize=#{@wand_hits}&wand.type=#{get_wand_type}&wand.thresholdBoostFactor=#{@threshold_factor}&ranking.profile=#{get_rank_profile}&timeout=5s"
    str += "&query=filter:#{@filter}" if !@filter.empty?
    return str
  end

  def get_query_file
    "regular"
  end

end

class ParallelWandSpec < WandPerformanceSpec
  def self.stype
    "parallel"
  end

  def initialize(clients, wand_hits, search_threads, doc_count, filter="", threshold_factor = 1.0)
    super(clients, wand_hits, search_threads, doc_count, filter, threshold_factor)
  end
end

class VespaWandSpec < WandPerformanceSpec
  def self.stype
    "vespa"
  end

  def initialize(clients, wand_hits, search_threads, doc_count, filter="")
    super(clients, wand_hits, search_threads, doc_count, filter)
  end
end

class DotProductOperatorSpec < WandPerformanceSpec
  def self.stype
    "dotproductoperator"
  end

  def initialize(clients, wand_hits, search_threads, doc_count, filter="")
    super(clients, wand_hits, search_threads, doc_count, filter)
  end

  def get_wand_type
    "dotProduct"
  end
end

class DotProductFeatureSpec < WandPerformanceSpec
  def self.stype
    "dotproductfeature"
  end

  def initialize(clients, wand_hits, search_threads, doc_count, filter="")
    super(clients, wand_hits, search_threads, doc_count, filter)
  end

  def get_fbench_append_str
    str = "&ranking.profile=#{get_rank_profile_base}-dotproduct"
    if @filter.empty?
      str += "&query=sddocname:test"
    else
      str += "&query=filter:#{@filter}"
    end
    return str
  end

  def get_query_file
    "dotproduct"
  end
end

class OrSpec < WandPerformanceSpec
  def self.stype
    "or"
  end

  def initialize(clients, wand_hits, search_threads, doc_count, filter="")
    super(clients, wand_hits, search_threads, doc_count, filter)
  end

  def get_rank_profile
    get_rank_profile_base + "-or"
  end
end
