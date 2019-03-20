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

def make_graphs
  graphs = [ ]
  1.times do |flushidx|
    1.times do |largedocs|
      1.times do |largewin|
        2.times do |rescan|
          flushstr = flushidx != 0 ? "flush" : "noflush"
          docstr = largedocs != 0 ? "largedocs" : "smalldocs"
          winstr = largewin != 0 ? "largewin" : "smallwin"
          rescanstr = rescan != 0 ? "-rescan" : ""
          tagstr = "gc-" + docstr + "-" + winstr + "-" + flushstr + rescanstr
          graphs.push({ :filter => { :tag => [ tagstr ] },
                        :x => 'pass',
                        :y => 'gctime',
#                        :historic => true
                      })
        end
      end
    end
  end
  graphs
end


def main
  graphs = make_graphs

  fetcher = DatasetFetcher.new(ARGV)

  i = 0

  graphs.each do |g|
    name = "plot#{i}.png"
    puts "Plotting: #{g.inspect} to #{name}"
    mgr = DatasetManager.new(g, fetcher)
    p = Perf::Plotter.new(mgr.idproducer, mgr.xproducer, mgr.yproducer, mgr.datasets)
    p.title = g[:filter][:tag]
    p.ylabel = g[:y]
    p.xlabel = g[:x]
    p.plot(name, 768, 512, true)
    p = Perf::HTMLPrinter.new(mgr.idproducer, mgr.xproducer, mgr.yproducer, mgr.datasets)
    p.title = g[:filter][:tag]
    p.ylabel = g[:y]
    p.xlabel = g[:x]
    html = p.html
    puts html
    i += 1
  end
end

if __FILE__ == $0
  main
end
