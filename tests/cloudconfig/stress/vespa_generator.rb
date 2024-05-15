# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# Generator for services.xml

require 'environment'

class VespaAppGenerator

  def initialize(num_containers, num_content_nodes, document_types)
    @num_containers = num_containers
    @num_content_nodes = num_content_nodes
    @document_types = document_types
  end

  def header
     "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n" +
     "<services version=\"1.0\">\n"
  end

  def footer
    "</services>\n"
  end

  def admin
      "<admin version=\"2.0\">\n" +
      "  <adminserver hostalias=\"node1\" />\n" +
      "</admin>\n"
  end

  def container_http
    http = ""
    0.upto(@num_containers - 1) { |i|
      http += "    <server id=\"server#{i}\" port=\"#{Environment.instance.vespa_web_service_port + i*10}\" />\n"
    }
    http
  end

  def content_nodes
    content = ""
    @num_content_nodes.times do |n|
      content += "      <node hostalias=\"node1\" distribution-key=\"#{n}\" />\n"
    end
    content
  end

  def document_types
    documents = "  <documents>\n"
    @document_types.each do |document_type|
      documents += "    <document type='#{document_type}' mode='index'/>\n"
    end
    documents + "  </documents>\n"
  end

  def jdisc
    search =
    "<container version=\"1.0\">\n" +
    "  <document-api />\n" +
    "  <search />\n" +
    "  <nodes>\n" +
    "    <node hostalias=\"node1\"/>\n" +
    "  </nodes>\n" +
    "  <http>\n" +
    container_http +
    "  </http>\n" +
    "</container>\n"
  end

  def content
    search =
    "<content version=\"1.0\">\n" +
    "  <redundancy>1</redundancy>\n" +
    document_types +
    "  <nodes>\n" +
    content_nodes +
    "    </nodes>\n" +
    "</content>\n"
  end

  def generate_services(output)
    f = File.new(output, "w")
    f.puts(header)
    f.puts(admin)
    f.puts(jdisc)
    f.puts(content)
    f.puts(footer)
    f.close
  end

end
