# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class VespaHosts
  def initialize(content)
    @content = content
    @names = []
    doc = REXML::Document.new(content)
    doc.root.each_element("//alias") { |a| @names << a.text }
  end

  def max_hosts
    @names.size
  end

  def generate_reordering(hostlist)
    nodes = {}
    @names.each_index do |i|
      host = hostlist[i % hostlist.size]
      nodes[host] = [] if !nodes.key? host
      nodes[host] << @names[i]
    end
    doc = REXML::Document.new
    doc.add(REXML::XMLDecl.new("1.0", "UTF-8"))
    hosts = doc.add_element("hosts")
    nodes.each_pair do |k, v|
      host = hosts.add_element("host", { "name" => k })
      v.each { |a| host.add_element("alias").text = a }
    end
    str = ""
    doc.write(str, -1)
    str
  end

  def generate_no_reordering(hostlist)
    ignored_hosts ||= []
    substituted_content = ""
    host_counter = 0
    doc = REXML::Document.new(@content)
    doc.elements.each("/hosts/host") do |elem|
      elem.attributes['name'] = hostlist[host_counter]
      host_counter += 1
    end
    str = ""
    doc.write(str, -1)
    str
  end
end
