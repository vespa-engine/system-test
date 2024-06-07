# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# This module contains methods for managing feeding through a feeder (vespa-feeder or vespa http client).
# The module is included in the NodeServer class, and the public method signatures are implemented
# in NodeServerInterface, which means that the methods are accessible from
# NodeProxy and any subclass of VespaNode.

require 'environment'
require 'data_generator'

module Feeder

  # Creates a temporary feed file using create_tmpfeed and feeds it
  # using feed_stream.
  def feed(params={})
    if params[:template]
      feed_generated(params)
    else
      feed_stream_file(params[:file], params)
    end
  end

  def decompressfile(cmd, source, handler)
    IO.popen("#{cmd} #{source}") do |feed|
      handler.handle(feed)
    end
  end

  def catfile(source, handle)
    decompressfile(select_cat(source), source, handle)
  end

  class Writer

    def initialize(dest)
      @destination = dest
    end
    def handle(stream)
      while block = stream.read(50*1024*1024)
        @destination.write(block)
      end
    end
  end

  # Constructs a feed from a _:file_ or _:dir_
  def create_tmpfeed(params={})
    encoding = params[:encoding]
    buffer = params[:buffer]

    if not encoding
        encoding = "utf-8"
    end

    localfiles = []
    if params[:dir] or params[:file]
      localfiles = fetchfiles(params)
    end
    timestamp = Time.new.to_i
    randomstring = "%04d" % (rand*10000).to_i
    tmpfeed = "#{Environment.instance.vespa_home}/tmp/tmpfeed#{timestamp}-#{randomstring}"
    File.open(tmpfeed, "w") do |tmp|
      localfiles.each do |feedfilename|
        catfile(feedfilename, Writer.new(tmp))
      end
      if buffer
        tmp.write(buffer)
      end
    end
    puts "Created #{tmpfeed}"
    params[:deletefeed] = true
    tmpfeed
  end

  def fetch_to_localfile(filename, params={})
    if params[:testdata_url]
      return fetchfile(filename)
    elsif params[:localfile]
      return filename
    else
      return create_tmpfeed(params)
    end
  end

  # Feeds a single file with name _filename_ without any extra generated XML data.
  def feedfile(filename, params={})
    params = params.merge(:file => filename)
    feed_stream_file(filename, params)
  end

  # Writes the feed buffer to a file and feeds it.
  def feedbuffer(buffer, params={})
    tmpfeed = create_tmpfeed(params.merge({:buffer => buffer}))
    feed_stream_file(tmpfeed, params.merge({:file => tmpfeed, :localfile => true}))
  end

  # Runs a Java program to generate feed from a template.
  def feed_generated(params={})
    feed_stream(DataGenerator.new.feed_command(template: params[:template], count: params[:count]), params)
  end

  # Pipe the output of _command_ into the feeder binary instead of using an
  # explicit file. The process invoked must have a well-defined lifetime and
  # terminate itself when feeding has completed.
  def feed_stream_file(filename, params={})
    file = fetch_to_localfile(filename, params)
    command = select_cat(file)
    feeder_output = feed_stream("#{command} #{file}", params)
    if params[:deletefeed]
      File.delete(file) if File.exist?(file)
    end
    feeder_output
  end

  def feed_stream(command, params)
    if params[:do_sync]
      execute("sync")
    end
    if !params[:client]
      params[:client] = testcase.default_feed_client
    end
    if !params[:stderr]
      params[:stderr] = :true
    end

    feeder = select_feeder(params)
    feedercmd = "#{command} | #{feeder} "
    feedercmd << build_feeder_cmd_params(params)
    execute(feedercmd, params)
  end

  def build_feeder_cmd_params(params, feed_file = nil)
    p = ""

    if params[:verbose]
      p += "--verbose "
    end
    if params[:route]
      p += "--route #{params[:route]} "
    end
    if params[:timeout]
      p += "--timeout #{params[:timeout]} "
    end
    if params[:trace]
      p += "--trace #{params[:trace]} "
    end

    if params[:client] == :vespa_feeder
      if params[:priority]
        p += "--priority #{params[:priority]} "
      end
      if params[:maxpending]
        p += "--maxpending #{params[:maxpending]} "
      end
      if params[:validate]
        p += "--validate "
      end
    end

    if params[:client] == :vespa_feeder
      if params[:nummessages]
        p += "--nummessages #{params[:nummessages]} "
      end
      if params[:numthreads]
        p += "--numthreads #{params[:numthreads]} "
      end
      if params[:numconnections]
        p += "--numconnections #{params[:numconnections]} "
      end
      if params[:mode]
        p += "--mode #{params[:mode]} "
      end
      if params[:requesttimeout]
        raise "requesttimeout no longer exists"
      end
      if params[:maxfeedrate]
        p += "--maxfeedrate #{params[:maxfeedrate]} "
      end
      if params[:compress]
        p += "--compress #{params[:compress]} "
      end
      if feed_file
        p += feed_file
      end
    elsif params[:client] == :vespa_feed_perf
      if params[:maxpending]
        p += "--maxpending #{params[:maxpending]} "
      end
      if params[:nummessages]
        p += "--nummessages #{params[:nummessages]} "
      end
      if params[:numthreads]
        p += "--numthreads #{params[:numthreads]} "
      end
      if params[:numconnections]
        p += "--numconnections #{params[:numconnections]} "
      end
      if params[:mode]
        p += "--mode #{params[:mode]} "
      end
      if feed_file
        p += feed_file
      end
    elsif params[:client] == :vespa_feed_client
      if feed_file
        p += "--file #{feed_file} "
      else
        p += "--stdin "
      end
      if params[:log_config]
        p += "--log-config #{params[:log_config]} "
      end
      if params[:numconnections]
        p += "--connections #{params[:numconnections]} "
      end
      if params[:compression]
        p += "--compression #{params[:compression]} "
      end
      if params[:max_streams_per_connection]
        p += "--max-streams-per-connection #{params[:max_streams_per_connection]} "
      end
      if params[:mode] == "benchmark"
        p += "--benchmark "
      end
      if params[:show_all]
        p += "--show-all "
      end
      if params[:silent]
        p += "--silent "
      end
      unless params[:ignore_errors]
        p += "--show-errors "
      end
      port = params[:port] || Environment.instance.vespa_web_service_port
      host = params[:host] || Environment.instance.vespa_hostname
      uri_scheme = if params[:disable_tls] then "http" else "https" end
      p += "--endpoint #{uri_scheme}://#{host}:#{port}/ "
      unless params[:disable_tls]
        p += vespa_feed_client_tls_options
      end
    end
    p
  end

  private
  def vespa_feed_client_tls_options
    raise "Global TLS configuration required" unless @tls_env.tls_enabled?
    p = "--disable-ssl-hostname-verification --certificate #{@tls_env.certificate_file} "
    p += "--private-key #{@tls_env.private_key_file} --ca-certificates #{@tls_env.ca_certificates_file} "
    p
  end

  private
  def select_cat(filename)
    if filename.match /[.]gz$/
      return "zcat"
    elsif filename.match /[.]xz$/
      return "xzcat"
    elsif filename.match /[.]bz2$/
      return "bzcat"
    elsif filename.match /[.]zst$/
      return "zstdcat"
    elsif filename.match /[.]lz4$/
      return "lz4cat"
    end
    return "cat"
  end

  private
  def select_feeder(params)
    if params[:client] == :vespa_feed_client
      return "vespa-feed-client "
    elsif params[:client] == :vespa_feeder
      return "vespa-feeder --abortondataerror no --abortonsenderror no"
    elsif params[:client] == :vespa_feed_perf
      return "vespa-feed-perf"
    else
      raise "Unsupported feed client '#{client}'"
    end
  end

end
