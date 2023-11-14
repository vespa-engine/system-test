# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

# Wrapper for JSON metrics with helper functions for accessing parts of the JSON structure.
class JSONMetrics

  def initialize(metrics)
    @metrics = metrics
    if !metrics.nil? && !metrics.has_key?("values") && metrics.has_key?("metrics") && metrics["metrics"].has_key?("values")
      # state v1 metrics
      @metrics = metrics["metrics"]
    end
  end

  def json
    @metrics
  end

  def has_metric_values?
    not (@metrics.nil? or @metrics['values'].nil?)
  end

  # return a list of all metrics whose name match expr
  def extract(expr)
    result = []
    @metrics["values"].each do |metric|
      if metric["name"] =~ expr
        result << metric
      end
    end
    result
  end

  def subset_of(dimensions, dimensions_subset)
    dimensions.merge(dimensions_subset) == dimensions
  end

  # get the complete metric for the (first) metric with the given name
  # where the given dimensions are a subset of the dimensions of the metric.
  def get_all(name, dimensions_subset = {})
    @metrics["values"].each do |metric|
      if metric["name"] == name && subset_of(metric["dimensions"], dimensions_subset)
        return metric
      end
    end
    nil
  end

  # get the values for the (first) metric with the given name
  # where the given dimensions are a subset of the dimensions of the metric.
  def get(name, dimensions_subset = {})
    metric = get_all(name, dimensions_subset)
    metric ? metric["values"] : nil
  end

end
