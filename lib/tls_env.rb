# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'openssl'
require 'json'

class TlsEnv

  attr_reader :ssl_ctx, :ca_certificates_file, :certificate_file, :private_key_file

  def initialize
    # Change to `true` to dump stacktrace every time a SSL context is created.
    # Useful for finding places that does not have propagation of a shared TlsEnv instance.
    @debug_print = false
    get_openssl_ctx_from_env_or_nil
  end

  def tls_enabled?
    ssl_ctx != nil
  end

  private
  def ssl_ctx_from_pems(ca_pem, cert_pem, privkey_pem, disable_hostname_validation)
    ca_store = OpenSSL::X509::Store.new
    ca_store.add_cert(OpenSSL::X509::Certificate.new(ca_pem)) # TODO multiple CA certs
    ssl_ctx = OpenSSL::SSL::SSLContext.new
    ssl_ctx.cert_store = ca_store
    ssl_ctx.cert = OpenSSL::X509::Certificate.new(cert_pem)
    begin
      ssl_ctx.key = OpenSSL::PKey::EC.new(privkey_pem)
    rescue # Not EC, try again with RSA
      ssl_ctx.key = OpenSSL::PKey::RSA.new(privkey_pem)
    end
    ssl_ctx.verify_mode = disable_hostname_validation ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
    ssl_ctx
  end

  private
  def field_or_throw(obj, field_name)
    raise "Field '#{field_name}' not found in JSON object" if obj[field_name].nil?
    obj[field_name]
  end

  private
  def get_openssl_ctx_from_env_or_nil
    cfg_file = ENV['VESPA_TLS_CONFIG_FILE']
    mode = ENV['VESPA_TLS_INSECURE_MIXED_MODE']
    if not cfg_file or mode == 'plaintext_client_mixed_server'
      puts 'Vespa TLS is not configured, continuing with insecure connections' if @debug_print
      return nil
    end
    if @debug_print
      puts "Using TLS config file '#{cfg_file}' for secure communication with Vespa services"
      puts Thread.current.backtrace
    end
    json = JSON.parse(File.read(cfg_file))
    files = field_or_throw(json, 'files')
    disable_hostname_validation = json['disable-hostname-validation'] ? json['disable-hostname-validation'] : false

    @ca_certificates_file = field_or_throw(files, 'ca-certificates')
    @certificate_file = field_or_throw(files, 'certificates')
    @private_key_file = field_or_throw(files, 'private-key')
    ca_pem      = File.read(@ca_certificates_file)
    cert_pem    = File.read(@certificate_file)
    privkey_pem = File.read(@private_key_file)

    @ssl_ctx = ssl_ctx_from_pems(ca_pem, cert_pem, privkey_pem, disable_hostname_validation)
  end


end

