# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/resultmodel'
require 'performance/datasetmanager'

module Perf

  class ComparePerformance
    def initialize(currentResult, prevResult)
      @currentResult = currentResult
      @prevResult = prevResult
      @prev_fetcher = PerformanceResultFetcher.new(@prevResult)
      @current_fetcher = PerformanceResultFetcher.new(@currentResult)
    end

    def getPrevMgr(g)
      DatasetManager.new(g, @prev_fetcher)
    end

    def getCurrMgr(g)
      DatasetManager.new(g, @current_fetcher)
    end
  end


  class PerformanceResultFetcher

    def initialize(results)
      @results = results
    end

    def fetch
      @results
    end
  end

  def Perf.check_performance_results(tc, graphs, method, current)
    tc.output("Checking results for #{method} with graphs #{graphs} on data #{current}")
    message = ""
    graphs.each do |g|
      if g[:title]
        title = "#{g[:title]}: "
      else
        title = ''
      end
      if g[:y_max]!=nil || g[:y_min]!=nil
        curr_mgr = DatasetManager.new(g, PerformanceResultFetcher.new(current))

        curr_mgr.datasets.each do |curr_dataset|
          curr_buckets = curr_dataset.split(curr_mgr.xproducer).to_a
          curr_buckets.sort! do |a, b|
            a[0] <=> b[0]
          end

          #Check y_min and y_max
          curr_yvalues = curr_buckets.map { |e| e[1].average(curr_mgr.yproducer) }
          curr_yvalues.each do |curr_yvalue|
            if (!g[:y_max].nil? && curr_yvalue > g[:y_max])
              message << "#{title}#{g[:y]} above limit(#{g[:y_max]}) : "+(sprintf "%.2f", curr_yvalue.to_s) +"\n"
            end
            if (!g[:y_min].nil? && curr_yvalue < g[:y_min])
              message << "#{title}#{g[:y]} under limit(#{g[:y_min]}) : "+(sprintf "%.2f", curr_yvalue.to_s) +"\n"
            end
          end
        end
      end
    end
    message
  end

  #Default implementation
  #Requires y_min,y_max and/or allowed_percent_change to be set in graphs
  #Will skip any graphs if those are not set. Implement yourself if necessary
  def Perf.compare_performance_results(graphs, method, current, prev)
    compare = ComparePerformance.new(current,prev)
    puts "Comparing results for #{method} with graphs #{graphs}"
    message = ""
    #prev_fetcher = PerformanceResultFetcher.new(prev)
    #current_fetcher = PerformanceResultFetcher.new(current)
    graphs.each do |g|
      if g[:title]
        title = "#{g[:title]}: "
      else
        title = ''
      end
      if g[:y_max]!=nil || g[:y_min]!=nil || g[:allowed_percent_change]!=nil
        prev_mgr = compare.getPrevMgr(g)
        curr_mgr = compare.getCurrMgr(g)

        curr_mgr.datasets.each do |curr_dataset|
          curr_buckets = curr_dataset.split(curr_mgr.xproducer).to_a
          curr_buckets.sort! do |a, b|
            a[0] <=> b[0]
          end

          prev_buckets = []
          # Why is only the last used? "Magic" check for .empty?
          prev_mgr.datasets.each do |prev_dataset|
            prev_buckets = prev_dataset.split(prev_mgr.xproducer).to_a
            prev_buckets.sort! do |a, b|
              a[0] <=> b[0]
            end
          end

          #Check y_min and y_max
          curr_yvalues = curr_buckets.map { |e| e[1].average(curr_mgr.yproducer) }
          prev_yvalues = prev_buckets.map { |e| e[1].average(prev_mgr.yproducer) }
          curr_yvalues.each_with_index do |curr_yvalue, index|
            if (!g[:y_max].nil? && curr_yvalue > g[:y_max])
              message << "#{title}#{g[:y]} above limit(#{g[:y_max]}) : "+(sprintf "%.2f", curr_yvalue.to_s) +"\n"
            end
            if (!g[:y_min].nil? && curr_yvalue < g[:y_min])
              message << "#{title}#{g[:y]} under limit(#{g[:y_min]}) : "+(sprintf "%.2f", curr_yvalue.to_s) +"\n"
            end

            #check allowed_percent_change IF dataset size is the same on cur and prev.
            if curr_mgr.datasets.size==prev_mgr.datasets.size
              #puts "cur #{curr_yvalue} prev #{prev_yvalues.fetch(index)}"
              if (!g[:allowed_percent_change].nil?)
                percent_change = (((curr_yvalue-prev_yvalues.fetch(index))/prev_yvalues.fetch(index))*100)
                if (percent_change.abs >g[:allowed_percent_change])
                  percent_change_rounded = sprintf "%.2f", percent_change
                  message << "#{title}#{g[:y]} changed too much(allow #{g[:allowed_percent_change]}%) : #{percent_change_rounded}%\n"
                end
              end
            end
          end
        end
      end
    end
    message
  end

end
