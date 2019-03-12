# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# To change this template, choose Tools | Templates
# and open the template in the editor.


class ResultsetGenerator

  def initialize
    @resultsets = {}
    @resultset = gen_resultset
  end

  def add_resultset(query, result)
    @resultsets[query] = result
  end

  def get_resultset(query = nil)
    if @resultsets.has_key?(query)
      resultset = @resultsets[query]
    else
      resultset = @resultset
    end
    if (query)
      resultset.query = query
    end
    return resultset
  end

  def get_error_resultset(query = nil)
    xmldata = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<result total-hit-count=\"0\">\n<error code=\"10\">Backend communication error</error>\n<errordetails>\n<error source=\"search\" error=\"Backend communication error\" code=\"10\">\nsc0.num0 failed: Received error from backend in sc0.num0: All searchnodes are down. This might indicate that no index is available yet. (3)\n</error>\n</errordetails>\n</result>\n"
    resultset = Resultset.new(xmldata, query)
  end

  def gen_resultset
    resultset = Resultset.new(nil, nil)
    (0..9).each { |i|
      hit = Hit.new
      hit.add_field("relevancy", i.to_s)
      hit.add_field("title", i.to_s + "blues")
      hit.add_field("artist", (9 - i).to_s + "metallica")
      resultset.add_hit(hit)
      resultset.hitcount = 10
    }
    return resultset
  end

end
