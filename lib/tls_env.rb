# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'openssl'
require 'json'

class TlsEnv

  CONFIG_FILE_ENV_VAR = 'VESPA_TLS_CONFIG_FILE'
  DISABLE_TLS_ENV_VAR = 'VESPA_FACTORY_SYSTEMTESTS_DISABLE_TLS'

  attr_reader :ssl_ctx, :ca_certificates_file, :certificate_file, :private_key_file

  def initialize
    # Change to `true` to dump stacktrace every time a SSL context is created.
    # Useful for finding places that does not have propagation of a shared TlsEnv instance.
    @debug_print = false

    generate_tls_config_if_missing
    write_tls_config_path_to_default_env_if_present
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
  def generate_tls_config_if_missing
    unless ENV[CONFIG_FILE_ENV_VAR] or ENV[DISABLE_TLS_ENV_VAR]
      ssl_config = SslConfig.new(cert_path: :default)
      ssl_config.auto_create_keys_if_required
      tls_config_file = ssl_config.cert_file('tls-config.json')
      tls_config =
        {
          'disable-hostname-validation' => true,
          'files' => {
            'private-key' => ssl_config.host_private_key,
            'certificates' => ssl_config.host_cert,
            'ca-certificates' => ssl_config.ca_cert
          }
        }
      json = JSON.pretty_generate(tls_config)
      File.open(tls_config_file, 'w') do |f|
        f.syswrite(json)
      end
      FileUtils.chown(ssl_config.user, nil, tls_config_file)
      puts "Environment variable VESPA_TLS_CONFIG_FILE is not assigned, setting it to #{tls_config_file}."
      ENV[CONFIG_FILE_ENV_VAR] = tls_config_file
    end
  end

  private
  def write_tls_config_path_to_default_env_if_present
    tls_config_file = ENV[CONFIG_FILE_ENV_VAR]
    default_env = DefaultEnvFile.new(Environment.instance.vespa_home)
    default_env_file = default_env.file_name
    if File.exist?(default_env_file) and File.writable?(default_env_file) and File.writable?(File.dirname(default_env_file))
      if tls_config_file and File.exist?(tls_config_file) and not ENV[DISABLE_TLS_ENV_VAR]
        default_env.set(CONFIG_FILE_ENV_VAR, tls_config_file, 'fallback')
      else
        default_env.set(CONFIG_FILE_ENV_VAR, nil)
      end
    end
  end

  private
  def get_openssl_ctx_from_env_or_nil
    cfg_file = ENV[CONFIG_FILE_ENV_VAR]
    mode = ENV['VESPA_TLS_INSECURE_MIXED_MODE']
    if not cfg_file or mode == 'plaintext_client_mixed_server'
      puts 'Warning: Vespa TLS is not configured, continuing with insecure connections.'
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

