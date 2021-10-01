# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'erb'

class Generator

  def initialize
    lib_dir = File.dirname(__FILE__)
    @cmd = "cat #{lib_dir}/gpt-2-webtext-tally.txt | java #{lib_dir}/Words.java"
  end

  # A command which will generate documents from the given template
  def feed_command(template:, count: nil)
    "#{@cmd} feed template '#{template}'#{" count #{count}" if count}"
  end

  # A command which will generate simple or yql queries from the given template.
  def query_command(template:, yql: false, count: nil, parameters: {})
    url_command(template, "/search/?#{yql ? "yql=" : "query="}", count, parameters)
  end

  # A command which will generic URLs from the given template. Path may contain query parameters. 
  def url_command(template:, path:, count: nil, parameters: {})
    query = parameters.map { |k, v| encode(k) + "=" + encode(v) }.join("&")
    query = (path =~ /\?/ ? "&" : "?") + query unless query.empty?
    "#{@cmd} url template '#{template}' prefix '#{path}' suffix '#{query}#{" count #{count}" if count}"
  end

  def encode(object)
    ERB::Util.url_encode(object.to_s)
  end

end

