# Copyright Vespa.ai. All rights reserved.
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
    xmldata = '{"root":{"id":"toplevel","relevance":1.0,"fields":{"totalCount":0},"coverage":{"coverage":100,"documents":0,"degraded":{"match-phase":false,"timeout":true,"adaptive-timeout":false,"non-ideal-state":false},"full":true,"nodes":0,"results":1,"resultsFull":1},"errors":[{"code":12,"summary":"Timed out","source":"search","message":"Backend communication timeout on all nodes in group (distribution-keys: 0, 1)"},{"code":12,"summary":"Timed out","source":"search","message":"No time left for searching"}],"children":[{"id":"group:root:0","relevance":1.0,"continuation":{"this":""}}]}}'
    resultset = Resultset.new(xmldata, query)
  end

  def gen_resultset
    xmldata = '{"root":{"id":"toplevel","relevance":1.0,"fields":{"totalCount":10},"coverage":{"coverage":100}}}'
    resultset = Resultset.new(xmldata, nil)
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
