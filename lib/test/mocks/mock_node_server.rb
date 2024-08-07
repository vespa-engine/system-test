# Copyright Vespa.ai. All rights reserved.

class MockNodeServer

  attr_reader :https_client, :tls_env

  def initialize
    @tls_env = TlsEnv.new
    @https_client = HttpsClient.new(tls_env)
  end

end