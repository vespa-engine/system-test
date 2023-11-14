# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class SearchCoverage
  include ChainedSetter

  chained_setter :minimum
  chained_setter :min_wait_after_coverage_factor
  chained_setter :max_wait_after_coverage_factor

  def initialize()
    @minimum = 1
    @min_wait_after_coverage_factor = 0
    @max_wait_after_coverage_factor = 1
  end

  def to_xml(indent)
    helper = XmlHelper.new(indent)
    if @minimum < 1 && (@min_wait_after_coverage_factor > 0 || @max_wait_after_coverage_factor < 1)
      helper.tag("search").tag("coverage")
      if @minimum > 0
        helper.tag("minimum").content(@minimum).close_tag
      end
      if @min_wait_after_coverage_factor > 0
        helper.tag("min-wait-after-coverage-factor").content(@min_wait_after_coverage_factor).close_tag
      end
      if @max_wait_after_coverage_factor < 1
        helper.tag("max-wait-after-coverage-factor").content(@max_wait_after_coverage_factor).close_tag
      end
      helper.close_tag.close_tag
    end
  end
end
