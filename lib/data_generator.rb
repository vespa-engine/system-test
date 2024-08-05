# Copyright Vespa.ai. All rights reserved.

require 'erb'

class DataGenerator

  def initialize
    lib_dir = File.dirname(__FILE__)
    @cat = "cat #{lib_dir}/gpt-2-webtext-tally.txt"
    @run = "java #{lib_dir}/DataGenerator.java"
  end

  # A command which digests the output of a prior command, computing word frequencies.
  def digest_command(command:, cutoff: nil)
    "#{command} | #{@run} digest#{" cutoff #{cutoff}" if cutoff}"
  end

  # A command which will generate documents from a template. Template output may contain
  # characters [a-zA-Z0-9_.'-], all of which should be permissible as part of, e.g., JSON.
  def feed_command(template:, count: nil, data: nil)
    "#{data or @cat} | #{@run} feed template #{shell_quoted(template)}#{" count #{count}" if count}"
  end

  # A command which will generate simple or yql queries from a template.
  def query_command(template:, yql: false, count: nil, parameters: {}, data: nil)
    url_command(template: template, path: "/search/?#{yql ? "yql=" : "query="}", count: count, parameters: parameters, data: data)
  end

  # A command which will generaet generic URLs from a template.
  # Since the template output is URL-encoded, it will _either_ be part of the URL path,
  # when this contains no query part, _or_ be a parameter key _or_ value; see query_command.
  def url_command(template:, path:, count: nil, parameters: {}, data: nil)
    query = parameters.map { |k, v| encode(k) + "=" + encode(v) }.join("&")
    query = (path =~ /\?/ ? "&" : "?") + query unless query.empty?
    "#{data or @cat} | #{@run} url template #{shell_quoted(template)} prefix #{shell_quoted(path)} suffix #{shell_quoted(query)}#{" count #{count}" if count}"
  end

  def shell_quoted(arg_to_single_quote)
    "'#{arg_to_single_quote.gsub(/'/, "'\"'\"'")}'"
  end

  def encode(object)
    ERB::Util.url_encode(object.to_s)
  end

end

