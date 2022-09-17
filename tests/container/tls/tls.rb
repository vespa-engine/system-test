# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'
require 'app_generator/http'
require 'net/http'
require 'net/https'

class TlsTest < ContainerTest

  KEY_FILE = 'cert.key'
  CERT_FILE = 'cert.crt'

  def setup
    set_owner('bjorncs')
    set_description('Test TLS/SSL integration in JDisc')
  end

  def test_tls
    # Deploy a dummy app to get a reference to the container node, which is needed for uploading the certificate
    start(ContainerApp.new.container(Container.new.http(Http.new.server(Server.new('http', '4080')))))
    system("PATH=/opt/vespa-deps/bin:$PATH; openssl req -nodes -x509 -newkey rsa:4096 -keyout #{dirs.tmpdir}#{KEY_FILE} -out #{dirs.tmpdir}#{CERT_FILE} -days 365 -subj '/CN=#{@container.hostname}'", exception: true)
    system("chmod 644 #{dirs.tmpdir}#{KEY_FILE} #{dirs.tmpdir}#{CERT_FILE}")
    @container.copy("#{dirs.tmpdir}#{KEY_FILE}", dirs.tmpdir)
    @container.copy("#{dirs.tmpdir}#{CERT_FILE}", dirs.tmpdir)

    # Deploy app with TLS secured endpoint
    output = deploy(create_tls_secured_app)
    wait_for_reconfig(get_generation(output).to_i)
    response = https_get(@container.hostname, 4443, '/ApplicationStatus')
    assert(response.kind_of?(Net::HTTPSuccess), "Failed fetching /ApplicationStatus with tls: #{response.to_s}")
  end

  def create_tls_secured_app
    ContainerApp.new.container(
        Container.new.
            http(
               Http.new.
                  server(
                      Server.new('http', '4080')).
                  server(
                      Server.new('https', '4443').ssl(
                          Ssl.new(private_key_file = "#{dirs.tmpdir}#{KEY_FILE}", certificate_file = "#{dirs.tmpdir}#{CERT_FILE}", ca_certificates_file=nil, client_authentication='disabled')))))
  end

  def https_get(host, port, path)
    http = Net::HTTP.new(host, port)
    http.verify_mode =  OpenSSL::SSL::VERIFY_PEER
    http.read_timeout = 60
    http.ssl_timeout = 60
    http.ssl_version = :TLSv1_2
    http.use_ssl = true
    http.ca_file = "#{dirs.tmpdir}#{CERT_FILE}"
    http.start do |http|
      http.get(path, {})
    end
  end

  def teardown
    stop
  end
end
