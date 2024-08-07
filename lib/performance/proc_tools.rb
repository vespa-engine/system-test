# Copyright Vespa.ai. All rights reserved.
module Perf
  class ProcTools

    # Detect first intersection of the given threshold, from either side.
    # Touching the threshold does not count, unless at the first sample.
    # @return the first index where the signal crosses the threshold, or -1 if no intersection
    def self.first_intersection(signal, threshold)
      if signal[0] - threshold == 0.0
        return 0
      end

      initial_diff_sign = diff_sign(signal[0], threshold)

      (1..signal.size-1).each { |index|
        current_diff_sign = diff_sign(signal[index], threshold)
        if current_diff_sign != initial_diff_sign &&
            current_diff_sign != 0
          return index
        end
      }
      -1
    end

    def self.diff_sign(val1, val2)
      (val1 - val2) <=> 0.0
    end

  end
end

