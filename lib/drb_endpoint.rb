# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'ssl_config'
require 'drb'

class DrbEndpoint
  @@self_service_mutex = Mutex.new
  @@self_uri = nil

  def initialize(endpoint)
    @endpoint = endpoint
    @ssl_config = SslConfig.new(cert_path: :default)
  end

  def secure?
    SslConfig.tls_enabled?
  end

  def tls_endpoint_uri(endpoint)
    "drbssl://#{endpoint}"
  end

  def insecure_endpoint_uri(endpoint)
    "druby://#{endpoint}"
  end

  def verify_cert_files_present
    if not @ssl_config.cert_path_contains_certs?
      raise "No certs/keys found on node. Please start node_server.rb " +
            "before running the test to auto-generate keypairs"
    end
  end

  def create_tls_client(endpoint, object)
    # Only do this once per class to avoid dangling threads and open ports for every client
    @@self_service_mutex.synchronize do
      if @@self_uri.nil?
        verify_cert_files_present
        # DRb has a completely bonkers API and basically offers no way of setting
        # client connection config aside from creating a dummy service and keeping
        # it running before starting the proper client..!
        # Luckily, setting a nil service object disallows anyone from calling
        # remote methods on ourselves. Or so the docs say, anyway.
        @@self_uri = "drbssl://#{Environment.instance.vespa_hostname}:0"
        DRb.start_service(@@self_uri, nil, @ssl_config.to_drb_openssl_config)
      end
    end

    uri = tls_endpoint_uri(endpoint)
    DRbObject.new(nil, uri)
  end

  def create_insecure_client(endpoint, object)
    uri = insecure_endpoint_uri(endpoint)
    DRbObject.new(nil, uri)
  end

  def create_client(with_object: nil)
    if secure?
      create_tls_client(@endpoint, with_object)
    else
      create_insecure_client(@endpoint, with_object)
    end
  end

  def start_tls_service(endpoint, object, auto_create_missing_keys)
    if auto_create_missing_keys
      @ssl_config.auto_create_keys_if_required
    end
    uri = tls_endpoint_uri(endpoint)
    DRb.start_service(uri, object, @ssl_config.to_drb_openssl_config)
  end

  def start_insecure_service(endpoint, object)
    uri = insecure_endpoint_uri(endpoint)
    DRb.start_service(uri, object) 
  end

  def start_service(for_object:, auto_create_missing_keys: true)
    if SslConfig.tls_enabled?
      start_tls_service(@endpoint, for_object, auto_create_missing_keys)
    else
      start_insecure_service(@endpoint, for_object)
    end
  end

  def join_service_thread
    DRb.thread.join
  end

end
