# Copyright Vespa.ai. All rights reserved.
require 'rpc/rpcwrapper'

class Slobrok < VespaNode
  def initialize(*args)
    super(*args)
    @sb = nil
  end

  def lookup_rpc_server(str)
    #names, specs
    begin
      slobrok().slobrok_lookupRpcServer(str)
    rescue StandardError
      return [], []
    end
  end


  private
  def slobrok
    @sb or @sb = RpcWrapper.new(@name, @ports[0], tls_env())
  end
end
