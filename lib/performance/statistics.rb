# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'distribution'

module Perf

  # A data set is a collection of result objects
  class Dataset
    def initialize(values)
      @values = values
    end

    # Produces average of values returned from applying producer to each result.
    def average(producer)
      total = 0
      @values.each do |result|
        total += producer.call(result)
      end
      avg = total / @values.length
      return avg.to_f
    end

    def variance(producer)
      avg = average(producer)
      var = 0.0
      @values.each do |result|
        val = producer.call(result)
        diff = val - avg
        var += (diff * diff)
      end
      var.to_f
    end

    def stddev(producer)
      res = 0
      begin
        var = variance(producer)
        res = Math.sqrt(var)
      rescue Errno::EDOM
      end
      res.to_f
    end

    def add_value(value)
      @values << value
    end

    def produce_values1d(producer)
      @values.map{|item| producer.call(item) }
    end

    def produce_value1d(producer)
      producer.call(@values[0])
    end

    def size
      return @values.length
    end

    def values
      @values
    end

    # Splits a dataset into buckets, and provides the ability to output of aggregated values for each bucket.
    def split(selector)
      buckets = Hash.new()
      @values.each do |result|
        selval = selector.call(result)
        if buckets.has_key?(selval) then
          bucket = buckets[selval]
          bucket.add_value(result)
          buckets[selval] = bucket
        else
          bucket = Dataset.new([result])
          buckets[selval] = bucket
        end
      end
      return buckets
    end
  end

  # A filtered data set is a collection of result objects that are equal in a single
  # dimension
  class FilteredDataset < Dataset
    def initialize(values, groupproducer, groupby)
      d = []
      values.each do |result|
        field = groupproducer.call(result)
        if field == groupby then
          d << result
        end
      end
      super(d)
    end
  end

  class Statistics
    def initialize(d1, d2, producer)
      @x1 = d1.average(producer)
      @v1 = d1.variance(producer)
      @n1 = d1.size
      @x2 = d2.average(producer)
      @v2 = d2.variance(producer)
      @n2 = d2.size
    end

    def compute(confidence)
      t = Distribution::T.p_value(1 - ((1 - confidence) / 2), @n1 - 1)
      spool = ((@n1 - 1) * @v1) + ((@n2 - 1) * @v2)
      spool /= (@n1 + @n2 - 2)
      spool = Math.sqrt(spool)
      s = spool * Math.sqrt((1.0 / @n1) + (1.0 / @n2))
      d = (@x1 - @x2).to_f
      e = t * s
      return spool, s, d, e
    end

    def absolute_difference(confidence)
      (spool, s, d, e) = compute(confidence)
      return d, e
    end

    def relative_difference(confidence)
      (spool, s, d, e) = compute(confidence)
      return (d * 100 / @x2), (e * 100 / @x2)
    end

    def difference(confidence)
      (spool, s, d, e) = compute(confidence)
      return d.abs > e
    end
  end

end
