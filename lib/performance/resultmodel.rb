# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'builder'
require 'xml'

require 'rexml/document'
require 'performance/system'

module Perf

  def Perf.qpsproducer
    Proc.new do |result|
      if result.metric("qps")!=nil
        qps = result.metric("qps").to_f
      else
        totalqueries = result.metric('successfulrequests')
        totaltime = result.metric('runtime')
        qps = totalqueries.to_f / totaltime.to_f
        qps.to_f
      end
    end
  end

  def Perf.clientproducer
    Proc.new do |result|
      clients = result.parameters['clients']
      clients.to_i
    end
  end

  def Perf.versionproducer
    Proc.new do |result|
      result.vespa_version
    end
  end

  def Perf.avglatencyproducer
    Proc.new do |result|
      res = result.metric('avgresponsetime')
      res.to_f
    end
  end

  def Perf.latency99producer
    Proc.new do |result|
      res = result.metric('99 percentile')
      res.to_f
    end
  end

  def Perf.latency95producer
    Proc.new do |result|
      res = result.metric('95 percentile')
      res.to_f
    end
  end

  def Perf.metricproducer(metric_name, source=nil)
    Proc.new do |result|
      res = result.metric(metric_name, source)
      res.to_f
    end
  end

  def Perf.customproducer(parameter_name, source=nil)
    Proc.new do |result|
      res = nil
      if (result.has_parameter?(parameter_name))
        res = result.parameter(parameter_name)
      else
        res = result.metric(parameter_name, source)
      end

      if res =~ /^-?\d+\.\d+([eE][+\-]?\d+)?$/
        res.to_f
      elsif res =~ /^-?\d+$/
        res.to_i
      else
	res = 0.0 if res == 'NaN'
        res
      end
    end
  end

  class Result
    attr_accessor :parameters, :metrics, :vespa_version

    def initialize(vespa_version)
      @vespa_version = vespa_version
      @parameters = {}
      @metrics = {}
    end

    def add_metric(metric_name, value, source=nil)
      #puts "Adding: #{metric_name} => #{value}"
      @metrics[[metric_name, source]] = value
    end

    def add_parameter(parameter_name, value)
      @parameters[parameter_name] = value
    end

    def has_parameter?(parameter_name)
      #puts "Has params: #{@parameters.keys.inspect}"
      return @parameters.has_key?(parameter_name)
    end

    def metric(metric_name, source=nil)
      metric = @metrics[[metric_name, source]]
      unless metric
        @metrics.each do |key, value|
          k,s = key
          metric = value if k == metric_name and source.nil?
        end
      end
      metric
    end

    def has_metric?(metric_name, source=nil)
      return @metrics.has_key?([metric_name, source])
    end

    def parameter(param_name)
      @parameters[param_name]
    end

    def to_s
      {
        :parameters => @parameters,
        :metrics => @metrics.transform_keys { |m, s| s.nil? ? [m] : [m, s] },
      }.to_s
    end

    def Result.read(path)
      f = File.new(path)
      xml = REXML::Document.new(f)

      Result.read_xml(xml)
    end

    def Result.read_string_fast(string)
      Result.read_xml_v2_fast(XML::Parser.string(string).parse)
    end

    def Result.read_string(string)
      xml = REXML::Document.new(string)

      Result.read_xml(xml)
    end

    def Result.read_xml(xml)
      root = xml.root

      result_version = root.attributes['version'].to_i
      if result_version == 1 then
        r = Result.read_xml_v1(root)
      elsif result_version == 2 then
        r = Result.read_xml_v2(root)
      else
        puts "Invalid version '#{result_version}'"
        r = nil
      end
      return r
    end

    def Result.read_xml_v1(root)
      version = root.elements['vespa'].attributes['version']
      r = Result.new(version)

      vespa = root.elements['vespa']
      r.add_metric('runtime', vespa.elements['runtime'].text.to_i)
      r.add_metric('successfulrequests', vespa.elements['queries'].text.to_i)
      r.add_metric('minresponsetime', vespa.elements['minresponsetime'].text.to_f)
      r.add_metric('maxresponsetime', vespa.elements['maxresponsetime'].text.to_f)
      r.add_metric('avgresponsetime', vespa.elements['responsetime'].text.to_f)
      r.add_parameter('clients', vespa.elements['clients'].text.to_i)

      vespa.elements.each('percentile') do |e|
        p = e.attributes['type']
        r.add_metric("#{p} percentile", e.text.to_f)
      end

      system = root.elements['system']
      hosts = system.elements['hosts']
      hosts.elements.each('host') do |h|
        hostname = h.attributes['hostname']
        r.add_metric('cpu_util', h.elements['cpuutil'].text.to_f, hostname)
      end
      return r
    end

    def Result.read_xml_v2_fast(doc)
      root = doc.root
      r = nil
      root.each_element do |e|
        if e.name == 'version'
          r = Result.new(e.content)
        end
      end

      root.each_element do |e|
        if e.name == 'parameters'
          e.each_element do |p|
            value = p.content
            #puts "Param value: " + value
            name = p.attributes.get_attribute('name').value
            #puts "Pname: #{name}"
            r.add_parameter(name, value)
          end
        elsif e.name == 'metrics'
          e.each_element do |m|
            # TODO: Should convert to appropriate type
            value = m.content
            #puts "Metric value: " + value
            name = m.attributes.get_attribute('name').value
            #puts "Name: #{name}"
            source = m.attributes.get_attribute('source')
            r.add_metric(name, value, source ? source.value : nil)
          end
        end
      end
      r
    end

    def Result.read_xml_v2(root)
      version = root.elements['version'].text
      r = Result.new(version)
      params = root.elements['parameters']
      params.elements.each do |e|
        name = e.attributes['name']
        # XXX: Should convert to appropriate type
        value = e.text
        r.add_parameter(name, value)
      end

      metrics = root.elements['metrics']
      metrics.elements.each do |e|
        name = e.attributes['name']
        source = e.attributes['source']
        # XXX: Should convert to appropriate type
        value = e.text
        r.add_metric(name, value, source)
      end
      return r
    end

    def to_obj
      o = {}
      o[:version] = @vespa_version
      o[:metrics] = []
      o[:metrics] = @metrics.to_a.collect do |x|
        name, value = x
        m = {}
        m[:name] = name[0]
        m[:value] = value
        m[:source] = name[1] if name[1]
        m
      end
      o[:parameters] = @parameters.to_a.collect do |x|
        name, value = x
        {
          :name => name,
          :value => value
        }
      end
      o
    end

    def write(file)
      f = File.open(file, "w")
      xml = Builder::XmlMarkup.new( :indent => 2, :target => f )
      xml.instruct! :xml, :encoding => "ASCII"
      xml.result 'version' => '2.0' do |r|
        r.version @vespa_version
        r.metrics do |m|
          @metrics.each do |name,value|
            if name[1] == nil then
              m.metric value, :name => name[0]
            else
              m.metric value, :name => name[0], :source => name[1]
            end
          end
        end

        r.parameters do |p|
          @parameters.each do |name,value|
            p.parameter value, :name => name
          end
        end
      end
      f.close
    end
  end
end


# res = Perf::Result.read(ARGV[0])
# puts res.metrics.inspect

# puts res.parameters.inspect


# puts Perf::qpsproducer.call(res)
