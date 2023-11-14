# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/app'
require 'app_generator/nocontent'
require 'app_generator/chained_setter'
require 'app_generator/apphost'

# Simple app that is used to test cloudconfig stuff
class CloudconfigApp < App

  chained_setter :host

  def initialize
    super
    @content = NoContent.new
    @host = AppHost.new("localhost", ["node1"])
  end

  def hosts_header
    "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n" +
    "<hosts>\n"
  end

  def hosts_footer
    "</hosts>\n"
  end

  def hosts_xml
    hosts = hosts_header
    hosts << newline(@host.to_xml("  "))
    hosts << hosts_footer
  end
end
