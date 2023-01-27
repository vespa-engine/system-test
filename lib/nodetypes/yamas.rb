# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'
require 'json'

module Yamas

  def parseMetrics(data)
    return [] if data.empty?

    json = JSON.parse(data)
    messages = []
    json['metrics'].each do |metric|
        messages.push(metric)
    end
    messages
  end

  # Execute metricsproxy-client on the given node for service e.g vespa.qrserver
  def get_yamas_metrics_yms(node,service,params={})
    ret = node.execute("#{Environment.instance.vespa_home}/libexec/vespa/metricsproxy-client getMetricsForYamas " + service , params.merge({:exitcode => true, :noecho => true}))
    data = ret[1]
    parseMetrics(data)
  end

  # Get the float associated with a metric name in a set of YAMAS
  # messages.  To find the metric for the cluster 'europe', pass a
  # dimension filter of {'clustername' => 'europe'}.
  def get_metric(messages, name, defaultval=0.0, dimension_filter={})
    messages.each do |m|
      metric = m['metrics']
      dimensions = m['dimensions']
      if metric != nil
        value = metric[name]
        if value != nil

          # All key/value pairs in dimension_filter must match a
          # key/value pair in dimensions.
          should_filter = false
          dimension_filter.each do |filter_name, filter_value|
            if dimensions.key?(filter_name)
              if dimensions[filter_name] != filter_value
                should_filter = true
                break
              end
            end
          end

          if !should_filter
            return Float(value)
          end
        end
      end
    end
    return defaultval
  end

  ## Convert a set of YAMAS messages to a hash of all reported metric names
  def get_metrics_hash(messages)
    metrics = []
    messages.each do |m|
      metric = m['metrics']
      if metric != nil
        metric.each do |name, value|
		      metrics[name] = value
	      end
      end
    end
    return metrics
  end

  # get metrics directly from metricsproxy in JSON format using RPC
  def get_yamas_metrics_rpc(service,wrapper)
    jsondata = wrapper.getMetricsForYamas(service)[0]
    result = JSON.parse(jsondata)
    return result
  end

end
