# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/resultmodel'
require 'performance/dataprinter'
require 'performance/statistics'

class DatasetManager
  attr_reader :xproducer, :yproducer, :idproducer, :datasets
  attr_reader :x, :y, :title, :yaxis_title, :xaxis_title, :historic
  attr_reader :excluded

  def initialize(params, result_fetcher=nil, verbose=false)
    id = params[:id]
    @y = y = params[:y]
    @x = x = params[:x]
    @title = (params[:title] || "No title set")
    @xaxis_title = params[:xaxis_title]
    @yaxis_title = params[:yaxis_title]
    @verbose = verbose
    @historic = params[:historic]
    @excluded = []
    @sort_by_version = false

    #puts "Starting fetching: #{Time.now}"
    results = result_fetcher.fetch.clone
    #puts "Fetched: #{results.size}"
    #puts "Ending fetching: #{Time.now}"
    if params[:filter] and params[:filter].kind_of? Hash
      results.delete_if do |r|
        keep = true
        params[:filter].each do |f,v|
          begin
            v = [v] unless v.kind_of? Array
            keep = v.collect { |val| val.to_s }.include?(name_to_producer(f.to_s).call(r).to_s)
            #puts "value: #{name_to_producer(f.to_s).call(r).to_s}"
            #puts "f,v: #{f}, #{v}: #{keep}"
          #rescue
            #@excluded << r
            #keep = false
          end
          break if !keep
        end

        !keep
      end
    end

    ds = Perf::Dataset.new(results)

    #puts params.inspect
    if params[:historic]
      @xproducer = Perf::versionproducer
      @sort_by_version = true
      $stderr.puts "X producer: version" if @verbose
      aggregator = nil
      if params[:aggregator]
        aggregator = params[:aggregator]
        @yproducer = name_to_producer(y) #produceraggregator(ds, name_to_producer(params[:aggregator]), name_to_producer(y))
        @idproducer = produceraggregator(ds, name_to_producer(params[:aggregator]), name_to_producer(x))
        resultgrouper = produceraggregator(ds, name_to_producer(aggregator), name_to_producer(x))
        $stderr.puts "ID producer: #{params[:aggregator]}" if @verbose
        $stderr.puts "Y producer: #{y}" if @verbose
        $stderr.puts "Result grouper: #{aggregator}" if @verbose
      else
        @yproducer = name_to_producer(y)
        @idproducer = name_to_producer(x)
        resultgrouper = name_to_producer(x)
        $stderr.puts "ID producer: #{x}" if @verbose
        $stderr.puts "Y producer: #{y}" if @verbose
        $stderr.puts "Result grouper: #{x}" if @verbose
      end
    else
      @yproducer = name_to_producer(y)
      $stderr.puts "Y producer: #{y}" if @verbose
      if params[:aggregator] and !params[:aggregator].empty?
        @xproducer = produceraggregator(ds, name_to_producer(params[:aggregator]), name_to_producer(x))
        $stderr.puts "X producer: #{params[:aggregator]}" if @verbose
      else
        @sort_by_version = (x == 'version')
        @xproducer = name_to_producer(x)
        $stderr.puts "X producer: #{x}" if @verbose
      end
      if params[:plotid] && !params[:plotid].empty?
        resultgrouper = name_to_producer(params[:plotid])
        @idproducer = name_to_producer(params[:plotid])
        $stderr.puts "ID producer: #{params[:plotid]}" if @verbose
        $stderr.puts "Result grouper: #{params[:plotid]}" if @verbose
      else
        resultgrouper = Perf::versionproducer
        @idproducer = Perf::versionproducer
        $stderr.puts "ID producer: version" if @verbose
        $stderr.puts "Result grouper: version" if @verbose
      end
    end

    @resultgrouper = resultgrouper
    #puts "Filtering before result split"
    ds_filtered = exclude_from_dataset(ds, [
                                            @idproducer,
                                            @xproducer,
                                            @resultgrouper,
                                            @yproducer])

    @datasets = []
    ds_filtered.split(resultgrouper).map do |k, v|
      @datasets << v
    end
    @datasets.sort! { |x,y| resultgrouper.call(x.values.first) <=> resultgrouper.call(y.values.first) }
  end

  def sort!(buckets)
    if @sort_by_version
      buckets.sort! { |x, y|
        xval = split_version(x[0])
        yval = split_version(y[0])
        xval <=> yval
      }
    else
      buckets.sort! do |a, b|
        a[0] <=> b[0]
      end
    end
  end

  def split_version(version)
    version.split(/[.-]/).map { |e| e.to_i }
  end

  def exclude_from_dataset(ds, producers)
    #puts producers.inspect
    keep = []
    ds.values.each do |result|
      if producers.all? do |producer|
          # Ignore if not set
          return true if not producer
          if not producer.call(result)
            #puts "No data found using producer: #{producer}"
            false
          else
            true
          end
        end
        keep << result
      else
      end
    end
    #puts "Keeping: #{keep.size}, of: #{ds.size}"
    Perf::Dataset.new(keep)
  end

  def excluded
    @excluded.uniq
  end

  def produceraggregator(dataset, aggregator, selector)
    resultmap = {}
    #puts "Filtering before aggregator"
    dataset = exclude_from_dataset(dataset, [aggregator, selector])
    ds = dataset.split(aggregator)
    ds.each { |result|
      x = result[1].average(selector)
      result[1].values.each do |r|
        resultmap[r] = x
      end
    }

    Proc.new do |result|
      resultmap[result]
    end
  end

  def self.key_to_human(key)
    if key[1]
      key[0].humanize + " src: " + key[1]
    else
      key[0].humanize
    end
  end

  def self.key_to_string(key)
    if key[1]
      "#{key[0]},#{key[1]}"
    else
      key[0]
    end
  end

  def self.string_to_key(str)
    if str =~ /^([^,]+),([^,]+)$/
      [$1, $2]
    else
      [str, nil]
    end
  end

  def name_to_producer(name)
    if name == 'qps'
      Perf::qpsproducer
    elsif name == 'clients'
      Perf::clientproducer
    elsif name == 'latency' or name == 'avgresponsetime'
      Perf::avglatencyproducer
    elsif name == 'latency99' or name == '99p'
      Perf::latency99producer
    elsif name == 'latency95' or name == '95p'
      Perf::latency95producer
    elsif name == 'version'
      Perf::versionproducer
    elsif name == 'blank'
      Proc.new do |result|
        '[]'
      end
    else
      key,source = DatasetManager.string_to_key(name)
      Perf::customproducer(key, source)
    end
  end

end
