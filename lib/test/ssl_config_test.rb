# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require 'ssl_config'

class SslConfigTest < Test::Unit::TestCase

  def test_can_generate_certs_on_demand
    Dir.mktmpdir { |dir|
      cfg = SslConfig.new(cert_path: dir)
      assert_equal(false, cfg.cert_path_contains_certs?)
      cfg.generate_host_specific_certs
      assert_equal(true, cfg.cert_path_contains_certs?)

      assert cfg.get_openssl_ca_cert_info.include? 'CA:TRUE' unless RUBY_PLATFORM =~ /darwin/  # Issue with LibreSSL not producing X509 extension output in CA certs
      assert cfg.get_openssl_host_cert_info.include? 'CA:FALSE'
      assert cfg.get_openssl_host_cert_info.include? 'DNS:localhost'
    }
  end

  def test_cert_directory_not_auto_created_if_explicitly_provided
    # It's of course technically _possible_ that this dir exists, but the
    # likelihood is considered acceptably low.
    missing_dir = '/tmp/jahn_teigens_beste_electro_hits/'
    cfg = SslConfig.new(cert_path: missing_dir)
    assert_raise ArgumentError do
      cfg.generate_host_specific_certs
    end
  end

end
