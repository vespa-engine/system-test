# Copyright Vespa.ai. All rights reserved.
require "test/mocks/resultset_generator"
require 'test/mocks/mock_node_server'


class MockQrserver < Qrserver

  attr_accessor :return_query

  def initialize(service_entry)
    super(service_entry, nil, MockNodeServer.new)
    @generator = ResultsetGenerator.new
    @resultsetdelay = 0
    @delaystart = nil
    @error = false
  end

  def search(query, port=0, header = nil, verbose = true, params = {})
    if @error
      resultset = @generator.get_error_resultset(query)
      return resultset
    end
    if !@return_query
      query = nil
    end
    if @resultsetdelay != 0
      if @delaystart == nil
        @delaystart = Time.now
        resultset = Resultset.new(nil, nil)
      else
        if Time.now - @delaystart < @resultsetdelay
          resultset = Resultset.new(nil, nil)
        else
          @resultsetdelay = 0
          @delaystart = nil
          resultset = @generator.get_resultset(query)
        end
      end
    else
      resultset = @generator.get_resultset(query)
    end
    if header != nil
      resultset.responsecode = 200
      resultset.responseheaders = {"testheader" => "unittest"}
    end
    return resultset
  end

  def set_error(error)
    @error = error
  end

  def get_resultset()
    return @generator.get_resultset()
  end

  def set_delay(delay)
    @resultsetdelay = delay
  end
end
