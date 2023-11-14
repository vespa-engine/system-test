# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Metrics
  include ChainedSetter

  chained_forward :consumers, :consumer => :push

  def initialize()
    @consumers = []
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
        tag("metrics").
        to_xml(@consumers).to_s
  end
end

class Consumer
  include ChainedSetter

  chained_forward :metrics, :metric => :push
  chained_forward :metric_sets, :metric_set => :push

  def initialize(id)
    @id = id
    @metric_sets = []
    @metrics = []
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
        tag("consumer", :id => @id).
        to_xml(@metric_sets).
        to_xml(@metrics).
        to_s
  end
end

class MetricSet
  def initialize(id)
    @id = id
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
        tag("metric-set", :id => @id).to_s
  end
end

class Metric
  def initialize(id, displayname = nil)
    @id = id
    @dispname = displayname
  end

  def to_xml(indent="")
    if @dispname
      XmlHelper.new(indent).
          tag("metric", { :id => @id, "display-name" => @dispname }).to_s
    else
      XmlHelper.new(indent).
          tag("metric", :id => @id).to_s
    end
  end
end
