# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'openssl'
require 'fileutils'
require 'shellwords'

class SslConfig

  USE_TLS_ENV_VAR_NAME = 'VESPA_SYSTEM_TEST_USE_TLS'
  PATH_OVERRIDE_ENV_VAR_NAME = 'VESPA_SYSTEM_TEST_CERT_PATH'
  USER_HOME_RELATIVE_PATH = '.vespa/system_test_certs'

  attr_reader :cert_path, :use_tls, :tls_config_file
  # _Paths_ to CA and host PEMs/keys.
  attr_reader :ca_cert, :host_cert, :host_private_key

  # cert_path: If set to :default, will use VESPA_SYSTEM_TEST_CERT_PATH environment
  #            variable if present, or a homedir-relative fallback path otherwise.
  #            If not :default, will use the path provided verbatim.
  #            Path will only be auto-created if the homedir-relative path is used.
  def initialize(cert_path: :default)
    @auto_create_path = false

    @user = ENV['USER'] || ENV['SUDO_USER']
    raise ArgumentError.new("No SUDO_USER or USER environment variable set") if @user.nil?

    if cert_path == :default
      cert_path = ENV[PATH_OVERRIDE_ENV_VAR_NAME]
      if cert_path.nil?
        cert_path = fallback_cert_path
        @auto_create_path = true
      end
    else
      raise ArgumentError.new("Cert path cannot be empty") if cert_path.empty?
    end

    @cert_path        = cert_path
    @ca_cert          = cert_file('ca.pem')
    @ca_private_key   = cert_file('ca-root-private.key') # May not exist
    @host_cert        = cert_file('host.pem')
    @host_csr         = cert_file('host.csr') # May not exist
    @host_exts        = cert_file('host_exts.cnf')
    @host_private_key = cert_file('host.key')
    @tls_config_file  = cert_file('tls-config.json')
  end

  def self.tls_enabled?
    'false' != ENV[USE_TLS_ENV_VAR_NAME]
  end

  def user_home_dir
    File.expand_path("~#{@user}")
  end

  def fallback_cert_path
    "#{user_home_dir}/#{USER_HOME_RELATIVE_PATH}"
  end

  def cert_file(file_name)
    "#{@cert_path}/#{file_name}"
  end

  def cert_path_contains_certs?
    File.exists?(@ca_cert) &&
    File.exists?(@host_cert) &&
    File.exists?(@host_private_key)
  end

  def cert_path_contains_config_file?
    File.exists? @tls_config_file
  end

  def run_or_fail(cmd)
    ret = `#{cmd}`
    raise RuntimeError.new("Command #{cmd} failed: exit code #{$?.exitstatus}") if $? != 0
    ret.strip
  end

  def ensure_cert_path_exists
    return if Dir.exists? @cert_path
    # We want to let any auto-created path be owned by the calling user, but we
    # do not dare do this if we're not the ones creating the path in the first place.
    raise ArgumentError.new("Can't auto-create key/cert directory when path explicitly set") if not @auto_create_path
    raise StandardError.new("Can't auto-create non-home relative path") if not @cert_path.end_with? USER_HOME_RELATIVE_PATH
    FileUtils.mkdir_p @cert_path
    FileUtils.chown_R(@user, nil, "#{user_home_dir}/.vespa/")
  end

  def generate_host_specific_certs
    ensure_cert_path_exists

    this_host = run_or_fail("hostname")

    generate_ca_private_key
    self_sign_root_ca_certificate_for this_host
    generate_host_specific_private_key
    generate_host_specific_csr_for this_host
    sign_host_specific_cert_by_root_ca
    generate_vespa_tls_config_file

    cleanup_files_after_key_and_cert_generation
  end

  # We generate our own self-signed Certificate Authority. This CA will
  # sign our host key pair and act as the trusted verifier of connection peers.
  # Note that we use RSA and SHA-256 for all our certs. We will eventually migrate to P-256 elliptic curves
  # once we are no longer depending on curl compiled with NSS.
  def generate_ca_private_key
    run_or_fail("openssl genrsa -out #{@ca_private_key} 2048")
  end

  def self_sign_root_ca_certificate_for(this_host)
    run_or_fail("openssl req -new -x509 -nodes -key #{@ca_private_key} " +
                "-sha256 -out #{@ca_cert} " +
                "-subj '/C=NO/L=Trondheim/O=ACME Vespa/OU=Vespa system test dummy CA root/CN=#{this_host}' " +
                "-days 720")
  end

  def generate_host_specific_private_key
    run_or_fail("openssl genrsa -out #{@host_private_key} 2048")
  end

  def generate_host_specific_csr_for(this_host)
    File.open(@host_exts, 'w') do |f|
      f.syswrite("[systest_extensions]\n" +
                 "basicConstraints       = critical, CA:FALSE\n" +
                 "keyUsage               = critical, digitalSignature, keyAgreement, keyEncipherment\n" +
                 "extendedKeyUsage       = serverAuth, clientAuth\n" +
                 "subjectKeyIdentifier   = hash\n" +
                 "authorityKeyIdentifier = keyid,issuer\n" +
                 "subjectAltName         = @systest_sans\n" +
                 "[systest_sans]\n" +
                 "DNS.1 = localhost\n" +
                 "DNS.2 = #{this_host}\n")
    end
    run_or_fail("openssl req -new -key #{@host_private_key} -out #{@host_csr} " +
                "-subj '/C=NO/L=Trondheim/O=ACME Vespa/OU=Vespa system testing/CN=#{this_host}' " +
                "-sha256")
  end

  def sign_host_specific_cert_by_root_ca
    run_or_fail("openssl x509 -req -in #{@host_csr} " +
                "-CA #{@ca_cert} " +
                "-CAkey #{@ca_private_key} " +
                "-CAcreateserial " +
                "-out #{@host_cert} " +
                "-days 720 " +
                "-extfile '#{@host_exts}' " +
                "-extensions systest_extensions " +
                "-sha256");
  end

  def generate_vespa_tls_config_file
    json = {
      'files' => {
        'ca-certificates' => @ca_cert,
        'certificates'    => @host_cert,
        'private-key'     => @host_private_key
      }
    }.to_json
    File.open(@tls_config_file, 'w'){|f| f.syswrite(json) }
  end

  def cleanup_files_after_key_and_cert_generation
    # We're done with the CSR; it won't be needed again.
    File.unlink(@host_csr)
    File.unlink(@host_exts)

    # Make everything owned by original user
    FileUtils.chown(@user, nil, @ca_private_key)
    FileUtils.chown(@user, nil, @host_private_key)
    FileUtils.chown(@user, nil, @ca_cert)
    FileUtils.chown(@user, nil, @host_cert)
    # Private keys should only be readable by the original user
    File.chmod(0600, @ca_private_key)
    File.chmod(0600, @host_private_key)
  end

  def get_cert_info(cert_path)
    run_or_fail("openssl x509 -in #{cert_path} -text -noout")
  end

  def get_openssl_ca_cert_info
    get_cert_info(@ca_cert)
  end

  def get_openssl_host_cert_info
    get_cert_info(@host_cert)
  end

  def get_existing_cert_dns_san_entries
    raw_sans = run_or_fail("openssl x509 -in #{@host_cert} -text -noout | grep 'DNS:' | head -1")
    raw_sans.split(',').
        map{|s| s.strip }.
        select{|s| s =~ /^DNS:/ }.
        map{|s| s.split(':')[1] }.
        to_a
  end

  def to_drb_openssl_config
    cert_store = OpenSSL::X509::Store.new
    cert_store.add_file @ca_cert
    # IMPORTANT: we currently do _not_ verify actual hostnames against the CN/subjectAltName
    # entries in the certificate itself. This means a single certificate may be used across
    # multiple nodes.
    ssl_config = {
      :SSLCertificate => OpenSSL::X509::Certificate.new(File.read(@host_cert)),
      :SSLPrivateKey => OpenSSL::PKey.read(File.read(@host_private_key)),
      :SSLVerifyMode => OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT,
      :SSLCertificateStore => cert_store
    }
    ssl_config
  end
end
