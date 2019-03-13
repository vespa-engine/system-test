# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class LegacyMetric
  def initialize(name, output_name)
    @name = name
    @output_name = output_name
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
      tag("metric", :name => @name, :"output-name" => @output_name).to_s
  end

end

class LegacyConsumer
  include ChainedSetter

  chained_forward :metrics, :add => :push

  def initialize(name)
    @name = name
    @metrics = []
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
      tag("consumer", :name => @name).
        to_xml(@metrics).to_s
  end

end

class MetricConsumers
  include ChainedSetter

  chained_forward :consumers, :add => :push

  def initialize()
    @consumers = []
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
      tag("metric-consumers").
        to_xml(@consumers).to_s
  end

end

