# Copyright Vespa.ai. All rights reserved.
require 'rest_api'
require 'test_base'

module NodesRestApi
  include RestApi

  HTTP_HEADERS = {'Content-Type' =>'application/json'}
  DEFAULT_SERVER_HTTPPORT = 19071
  DEFAULT_FLAVOR = "medium"

  def add_nodes(nodes, hostname, flavor=DEFAULT_FLAVOR, port=DEFAULT_SERVER_HTTPPORT)
    url = "#{nodes_api_uri_base(hostname, port)}/node"
    body = []
    nodes.each_with_index do |node, index|
      ip = "127.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}"
      body << { "hostname" => "#{node}", "ipAddresses" => [ip], "openStackId" => "#{index}", "flavor" => "#{flavor}", "type" => "tenant"}
    end
    response = http_request_post(URI(url), {:body => body.to_json, :headers => HTTP_HEADERS})
    puts response.body
  end

  def dirty_nodes(nodes, hostname, port=DEFAULT_SERVER_HTTPPORT)
    move_nodes(nodes, 'dirty', hostname, port)
  end

  def ready_nodes(nodes, hostname, port=DEFAULT_SERVER_HTTPPORT)
    move_nodes(nodes, 'ready', hostname, port)
  end

  def nodes_api_uri_base(hostname, port=DEFAULT_SERVER_HTTPPORT)
    "http://#{hostname}:#{port}/nodes/v2"
  end

  private

  def move_nodes(nodes, to_state, hostname, port)
    base_url = "#{nodes_api_uri_base(hostname, port)}/state/#{to_state}/"
    nodes.each do |node|
      response = http_request_put(URI(base_url) + node, {:headers => HTTP_HEADERS})
      puts response.body
    end
  end

end
