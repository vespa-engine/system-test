# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class HealthCheckProxyTest < SearchContainerTest

  def setup
    set_owner('bjorncs')
    set_description('Verify that container is able to proxy health checks from http to https')
  end

  def test_server
    container_port = Environment.instance.vespa_web_service_port
    container_port_1 = container_port
    proxy_1_port = container_port + 1
    container_port_2 = proxy_1_port + 1
    proxy_2_port = container_port_2 + 1
    app = ContainerApp.new.container(
        Container.new.
            http(Http.new.
                server(
                    Server.new('https-server', container_port_1)).
                server(
                    Server.new('http-proxy-server-1', proxy_1_port).
                        config(ConfigOverride.new('jdisc.http.connector').
                            add('implicitTlsEnabled', 'false'). # Disable implicit TLS/HTTPS on this port
                            add('healthCheckProxy', ConfigValues.new.add('enable', true).add('port', container_port_1.to_s)))).
                server(
                  Server.new('https-server-proxy-protocol', container_port_2).
                    config(ConfigOverride.new('jdisc.http.connector').
                      add('proxyProtocol', ConfigValues.new.add('enabled', true)))).
                server(
              Server.new('http-proxy-server-2', proxy_2_port).
                config(ConfigOverride.new('jdisc.http.connector').
                  add('implicitTlsEnabled', 'false'). # Disable implicit TLS/HTTPS on this port
                  add('healthCheckProxy', ConfigValues.new.add('enable', true).add('port', container_port_2.to_s))))))
    deploy_app(app)
    start
    container_hostname = vespa.container.values.first.hostname
    response = Net::HTTP.get_response(URI("http://#{container_hostname}:#{proxy_1_port}/status.html"))
    assert_equal(200, response.code.to_i)
    assert_match(Regexp.new('<title>OK</title>'), response.body, 'Could not find expected message in response.')
    assert_equal(container_port_1, response['Vespa-Health-Check-Proxy-Target'].to_i)

    response = https_client.get(container_hostname, container_port_1, '/')
    assert_equal(200, response.code.to_i, 'Root handler should be accessible from the standard port')

    response = Net::HTTP.get_response(URI("http://#{container_hostname}:#{proxy_1_port}/"))
    assert_equal(404, response.code.to_i, 'Root handler should not be accessible from proxy port')

    response = Net::HTTP.get_response(URI("http://#{container_hostname}:#{proxy_2_port}/status.html"))
    assert_equal(200, response.code.to_i)
    assert_match(Regexp.new('<title>OK</title>'), response.body, 'Could not find expected message in response.')
    assert_equal(container_port_2, response['Vespa-Health-Check-Proxy-Target'].to_i)
  end

  def teardown
    stop
  end

end
