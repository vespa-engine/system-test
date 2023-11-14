# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class MockNodeServer

  attr_reader :https_client, :tls_env

  def initialize
    @tls_env = TlsEnv.new
    @https_client = HttpsClient.new(tls_env)
  end

end