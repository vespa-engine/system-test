# Copyright Vespa.ai. All rights reserved.
module Perf
  class Filter

    # Simple Moving Average (sliding window).
    def self.sma(input, length)
      raise ArgumentError, "length must be >0" unless length > 0
      raise ArgumentError, "input must be longer than #{length}." unless input.size > length

      output = Array.new
      acc = 0
      for index in 0..input.size-1
        acc += input[index]
        if index < length
          output[index] = acc.to_f / (index +1)  # init with avg of first 'index' samples
        else
          acc -= input[index-length]
          output[index] = acc.to_f / (length)
        end
        #puts "output[#{index}]=#{output[index]}"
      end
      output
    end

  end
end

