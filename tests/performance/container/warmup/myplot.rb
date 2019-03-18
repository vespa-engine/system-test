#!/usr/bin/env ruby
# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

if File.exist?(File.dirname(__FILE__) + "/../lib/.svn")
  $:.push(File.dirname(__FILE__) + "/../lib/")
else
  $:.push("#{Environment.instance.vespa_home}/lib/vespa/systemtestlib/")
end

require 'rubygems'
require 'performance/statistics'
require 'performance/resultmodel'
require 'performance/dataprinter'
require 'performance/datasetmanager'
require 'getoptlong'

class DatasetFetcher

  def initialize(dirs)
    @dirs = dirs
  end

  def fetch
    rs = []

    @dirs.each do |d|
      Dir.glob(d + '/*.xml').each do |f|
        r = Perf::Result.read(f)
        rs << r
      end
    end

    rs
  end
end

def main
  graphs = [
      {
          :x => 'time',
          :y => 'request-rate',
          :historic => false,
          :filter => {
              :legend => "helloWorld_http_1.1"
          }
      },
      {
          :x => 'time',
          :y => 'request-latency',
          :historic => false,
          :filter => {
              :legend => "helloWorld_http_1.1"
          }
      },
      {
          :x => 'time',
          :y => 'request-rate-sma_short',
          :historic => false,
          :filter => {
              :legend => "helloWorld_http_1.1-sma_short"
          }
      },
      {
          :x => 'time',
          :y => 'request-rate-sma_long',
          :historic => false,
          :filter => {
              :legend => "helloWorld_http_1.1-sma_long"
          }
      },
      {
          :x => 'legend', # works for historic graphs
          :y => 'stable_time',
          :title => 'Build vs. warm-up period length [s]',
          :historic => true,
          :filter => {
              :legend => 'helloWorld_http_1.1-historic_stable_time'
          }
      }
  ]


  fetcher = DatasetFetcher.new(ARGV)

  i = 0

  graphs.each do |g|
    name = "plot#{i}.png"
    puts "Plotting: #{g.inspect} to #{name}"
    mgr = DatasetManager.new(g, fetcher)
    p = Perf::Plotter.new(mgr.idproducer, mgr.xproducer, mgr.yproducer, mgr.datasets)
    p.title = name
    p.ylabel = g[:y]
    p.xlabel = g[:x]

    p.plot(name, 1920, 1200, true)

    #puts p.html()
    i += 1
  end
end

if __FILE__ == $0
  main
end
