# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# This module contains methods for managing feeding through a feeder (vespa-feeder or vespa http client).
# There are convenience methods for creating <vespafeed> start and end tags, plus concatenation of feed files.
# The module is included in the NodeServer class, and the public method signatures are implemented
# in NodeServerInterface, which means that the methods are accessible from
# NodeProxy and any subclass of VespaNode.

require 'environment'

module Feeder

  # Creates a temporary feed file using create_tmpfeed and feeds it
  # using feedlocalfile.
  def feed(params={})
    tmpfeed = create_tmpfeed(params)
    feedlocalfile(tmpfeed, params.merge({:deletefeed => true}))
  end

  # Constructs a feed from a _:file_ or _:dir_, and optionally generates
  # <vespafeed> start and end tags based on the values in _params_.
  def create_tmpfeed(params={})
    encoding = params[:encoding]
    skip_feed_tag = params[:skipfeedtag]
    if params[:json]
      skip_feed_tag = true
    end
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
      if not skip_feed_tag
        tmp.write("<?xml version=\"1.0\" encoding=\"#{encoding}\" ?>")
        tmp.write("<vespafeed>\n")
      end
      localfiles.each do |feedfilename|
        if feedfilename.match /[.]gz$/
          IO.popen("zcat #{feedfilename}") do |feed|
            while block = feed.read(50*1024*1024)
              tmp.write(block)
            end
          end
        elsif feedfilename.match /[.]xz$/
          IO.popen("xzcat #{feedfilename}") do |feed|
            while block = feed.read(50*1024*1024)
              tmp.write(block)
            end
          end
        elsif feedfilename.match /[.]bz2$/
          IO.popen("bzcat #{feedfilename}") do |feed|
            while block = feed.read(50*1024*1024)
              tmp.write(block)
            end
          end
        else
          File.open(feedfilename, "r") do |feed|
            while block = feed.read(50*1024*1024)
              tmp.write(block)
            end
          end
        end
      end
      if buffer
        tmp.write(buffer)
      end
      if not skip_feed_tag
        tmp.write("</vespafeed>\n")
      end
    end
    puts "Created #{tmpfeed}"
    tmpfeed
  end

  # Feeds a single file with name _filename_ without any extra generated XML data.
  def feedfile(filename, params={})
    if params[:localfile]
      localfilename = filename
    else
      localfilename = fetchfiles(params.merge({:file => filename})).first
    end
    feedlocalfile(localfilename, params)
  end

  # Writes the feed buffer to a file and feeds it.
  def feedbuffer(buffer, params={})
    tmpfeed = create_tmpfeed(params.merge({:buffer => buffer}))
    feedlocalfile(tmpfeed, params)
  end

  # Pipe the output of _command_ into the feeder binary instead of using an
  # explicit file. The process invoked must have a well-defined lifetime and
  # terminate itself when feeding has completed.
  def feed_stream(command, params={})
    feedercmd = "#{command} | #{testcase.feeder_binary} "
    feedercmd << build_feeder_cmd_params(params)
    execute(feedercmd, params)
  end

  def build_feeder_cmd_params(params, feed_file = nil)
    p = "";
    if params[:verbose]
       p += "--verbose "
    end
    if params[:route]
      p += "--route #{params[:route]} "
    end
    if params[:retrydelay]
      p += "--retrydelay #{params[:retrydelay]} "
    end
    if params[:priority]
      p += "--priority #{params[:priority]} "
    end
    if params[:maxpending]
      p += "--maxpending #{params[:maxpending]} "
      # use mbus dynamic throttling policy
      #    else
      #      p += "--maxpending 32 "
    end
    if params[:timeout]
      p += "--timeout #{params[:timeout]} "
    end
    if params[:validate]
      p += "--validate "
    end
    if params[:trace]
      p += "--trace #{params[:trace]} "
    end

    if params[:client] == :vespa_feeder
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
    end

    if params[:client] == :vespa_http_client
      if params[:host]
        p += "--host #{params[:host]} "
      end
      if params[:port]
        p += "--port #{params[:port]} "
      end
      if params[:num_persistent_connections_per_endpoint]
        p += "--numPersistentConnectionsPerEndpoint #{params[:num_persistent_connections_per_endpoint]} "
      end
      if feed_file
        p += "--file #{feed_file}"
      end
    end

    p
  end


  private
  def vespa_http_client_cmd
    "java -cp #{Environment.instance.vespa_home}/lib/jars/vespa-http-client-jar-with-dependencies.jar com.yahoo.vespa.http.client.runner.Runner "
  end

  # Feeds a file with name _file_name_ using a feeder and returns the output.
  private
  def feedlocalfile(file_name, params={})
    if params[:do_sync]
      execute("sync")
    end
    if !params[:client]
      # Set default feeder to 'vespa-feeder'
      params[:client] = :vespa_feeder
    end
    if params[:client] == :vespa_feeder
      feeder_cmd = "#{testcase.feeder_binary} "
    elsif params[:client] == :vespa_http_client
      feeder_cmd = vespa_http_client_cmd
    else
      raise "Unsupported feed client '#{client}'"
    end

    feeder_cmd << build_feeder_cmd_params(params, file_name)
    feeder_output = execute(feeder_cmd, params)

    execute("cat #{file_name}") if params[:catfeed]
    if params[:deletefeed]
      File.delete(file_name) if File.exist?(file_name)
    end
    feeder_output
  end

end
