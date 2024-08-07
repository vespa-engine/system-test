# Copyright Vespa.ai. All rights reserved.
module Perf
  module TextReport

    class Builder
      def initialize(header, params={})
        @ss = "#{header}\n\n"
        @indent_level = 0
        @duration = params[:duration]
        @n_ops = params[:n_ops]
      end

      def indent
        ' ' * (@indent_level * 2)
      end

      def open_group(desc)
        @ss << indent << desc << ":\n"
        @indent_level += 1
      end

      def close_group
        @indent_level -= 1
      end

      def handle_warning(desc, metric, opts)
        return if not opts[:warn_if_exceeding]
        limit = opts[:warn_if_exceeding]
        if metric > limit
          @ss << "  <--- !!! exceeding warning threshold of #{limit} !!!"
        end
      end

      def single_metric(desc, metric, opts={})
        suffix = opts[:suffix] || ''
        @ss << indent << "%s: %.2f%s" % [desc, metric, suffix]
        handle_warning(desc, metric, opts)
        @ss << "\n"
      end

      def avg_metric(desc, metric, opts={})
        unit = opts[:unit] ? ' ' + opts[:unit] : ''
        per_op = @n_ops ? (", %.2f%s/op" % [metric.to_f / @n_ops, unit]) : ''
        @ss << indent << "%s: %d (%.2f%s/s%s)" % [desc, metric, metric.to_f / @duration, unit, per_op]
        handle_warning(desc, metric, opts)
        @ss << "\n"
      end

      def to_s
        @ss
      end
    end

  end
end
