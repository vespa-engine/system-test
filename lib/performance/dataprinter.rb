# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'gnuplot'

module Perf

  # Class creating a plot of one or more data sets
  class DataPrinter
    attr_accessor :xlabel, :ylabel, :title
    def initialize(idproducer, xproducer, yproducer, datasets, mgr=nil)
      @mgr = mgr
      @xlabel = "x"
      @ylabel = "y"
      @title = "title"

      @idproducer = idproducer
      @xproducer = xproducer
      @yproducer = yproducer
      @datasets = datasets
    end

    def loop_dataset(fn)
      @datasets.each do |dataset|
        # for each dataset...
        buckets = dataset.split(@xproducer).to_a
        @mgr.sort!(buckets)
        xvalues = buckets.map {|e| e[0] }
        yvalues = buckets.map {|e| e[1].average(@yproducer) }
        ystddev = buckets.map {|e| e[1].stddev(@yproducer) }
        id = dataset.produce_value1d(@idproducer)

        #puts "Xvalues: #{xvalues.inspect}"
        #puts "Yvalues: #{yvalues.inspect}"
        #puts "Ystddev: #{ystddev.inspect}"
        #puts "Id: #{id.inspect}"

        fn.call(xvalues, yvalues, ystddev, id)
      end
    end
  end

  class JSONPrinter < DataPrinter
    def initialize(mgr)
      super(mgr.idproducer, mgr.xproducer, mgr.yproducer, mgr.datasets, mgr)
      @mgr = mgr
      @obj = {}
    end

    def json_generator
      @obj[:errors] = {}
      if @mgr.excluded.size > 0
        @obj[:errors][:excluded] = mgr.excluded.size
      end
      @obj[:values] = {}
      Proc.new do |xvalues, yvalues, ystddev, id|
        @obj[:values][id] = xvalues.zip(yvalues)
      end
    end

    def data
      loop_dataset(json_generator)
      xs = {}
      # Google charts require that ids are all strings
      ids = @obj[:values].keys.collect { |k| k.to_s }
      @obj[:values].keys.each do |k|
        @obj[:values][k].each do |v|
          xs[v[0]] = []
        end
      end
      @obj[:values].keys.each do |k|
        @obj[:values][k].each do |v|
          xs[v[0]] << v[1]
        end
      end

      xs = xs.reject { |k, v| v.length != ids.length }
      values =  xs.keys.collect { |k|
        [k] + xs[k]
      }
      @mgr.sort!(values)
      @obj[:values] = [[@mgr.x] + ids] + values
      @obj[:yaxis] = (@mgr.yaxis_title || "")
      @obj[:yaxis] = @mgr.y if @obj[:yaxis].empty?
      if @mgr.historic
        @obj[:xaxis] = (@mgr.xaxis_title || "")
        @obj[:xaxis] = 'builds' if @obj[:xaxis].empty?
      else
        @obj[:xaxis] = (@mgr.xaxis_title || "")
        @obj[:xaxis] = @mgr.x if @obj[:xaxis].empty?
      end
      @obj[:title] = @mgr.title
      @obj[:title] = @title if not @obj[:title] or @obj[:title].empty?
      @obj
    end
  end

  class HTMLPrinter < DataPrinter
    def initialize(*args)
      super(*args)
      @html = nil
    end

    def html_generator
      @html = "<h3>#{@title}</h3>\n"
      Proc.new do |xvalues, yvalues, ystddev, id|
        @html += "<h4>#{id}</h4>\n"
        @html += "<table border=\"1\">\n"
        @html += "<tr>\n"
        @html += "<th>#{@xlabel}</th>\n"
        @html += "<th>#{@ylabel} (average)</th>\n"
        @html += "<th>#{@ylabel} (standard deviation)</th>\n"
        @html += "</tr>\n"

        xvalues.zip(yvalues).zip(ystddev).each do |data,ydev|
          @html += "<tr>\n"
          @html += "<td>#{data[0]}</td>\n"
          @html += "<td>#{data[1]}</td>\n"
          @html += "<td>#{ydev}</td>\n"
          @html += "</tr>\n"
        end
        @html += "</table>"
      end
    end

    def html
      loop_dataset(html_generator)
      @html
    end
  end

  class Plotter < DataPrinter
    attr_accessor :xdata, :timefmt, :xformat
    def initialize(*args)
      super(*args)
      @xdata = nil
      @timefmt = nil
      @xformat = nil
    end

    def plot_generator(lineformat, plot)
      Proc.new do |xvalues, yvalues, ystddev, id|
        if lineformat == "errorlines" then
          plot.data << Gnuplot::DataSet.new( [xvalues, yvalues, ystddev] ) do |ds|
            ds.with = lineformat
            ds.title = id
            ds.linewidth = 2
            ds.using = "1:2:3"
          end
        else
          plot.data << Gnuplot::DataSet.new( [xvalues, yvalues] ) do |ds|
            ds.with = lineformat
            ds.linewidth = 2
            ds.title = id
            ds.using = "1:2"
          end
        end
      end
    end

    def plot(name, xsize, ysize, errorbars=false)
      if errorbars
        plot_new(name, xsize, ysize, "errorlines")
      else
        plot_new(name, xsize, ysize, "linespoints")
      end
    end

    def plot_new(name, xsize, ysize, lineformat="linespoints")
      Gnuplot.open do |gp|
        Gnuplot::Plot.new(gp) do |plot|
          plot.title(@title)
          plot.ylabel(@ylabel)
          plot.xlabel(@xlabel)
          plot.set("xdata", @xdata) if @xdata
          plot.set("timefmt", "\"#{@timefmt}\"") if @timefmt
          plot.set("format x", "\"#{@xformat}\"") if @xformat

          loop_dataset(plot_generator(lineformat, plot))
          plot.set("output", name)
          plot.set("terminal", "png size #{xsize}, #{ysize}")
        end
      end
    end
  end

end
