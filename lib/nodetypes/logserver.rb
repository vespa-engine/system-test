# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

class Logserver < VespaNode

  def initialize(*args)
    super(*args)
  end

  def get_vespalog_helper(reader, args)
    if args[:multinode] || args[:use_logarchive]
      logfiles = Dir.glob("#{Environment.instance.vespa_home}/logs/vespa/logarchive/2*/*/*/*")
      logfiles.each do |logfile|
        reader.call(logfile)
      end
    else
      logfiles = Dir.glob("#{Environment.instance.vespa_home}/logs/vespa/vespa.log-*")
      logfiles.each do |logfile|
        reader.call(logfile)
      end
      reader.call("#{Environment.instance.vespa_home}/logs/vespa/vespa.log")
    end
  end

  def get_vespalog(args={})
    logcontent = ""
    begin
      get_vespalog_helper(-> logfile { logcontent << File.open(logfile).read }, args)
    rescue
      @testcase.output("Expected Exception: No write to vespa.log since last log initilize")
    end
    size = logcontent.length
    chunk = 2*1024*1024
    pos = 0
    while pos*chunk < size
      str = logcontent[pos*chunk, chunk]
      if str.length > chunk
        @testcase.output("Trying to write #{str.length}, but should be capped at: #{chunk}, total data: #{logcontent.length}")
      else
        yield(str)
      end
      pos += 1
    end
  end

  def delete_vespalog
    execute("rm -rf #{Environment.instance.vespa_home}/logs/vespa/*")
  end

  def get_logfile(filename)
    content = ""
    if File.exist?(filename)
      content = File.open(filename).read
    end

    size = content.length
    chunk = 2*1024*1024
    pos = 0
    while pos*chunk < size
      yield(content[pos*chunk, (pos+1)*chunk])
      pos += 1
    end
  end

  # Finds entries in vespa logarchive on the logserver which match _regexp_
  def find_log_matches(regexp, args={})
    logcontent = ""
    get_vespalog_helper(-> logfile { logcontent << read_file_ignore_error(logfile) }, args)

    # scan returns an array of matches
    logcontent.scan(regexp)
  end

  # Asserts that the vespa logarchive on the logserver matches _regexp_, and return the number of matches
  def log_matches(regexp, args={})
    find_log_matches(regexp, args).size
  end

  def read_file_ignore_error(file)
      ret = ""
      begin
        ret = File.open(file).read
      rescue
        # Ignore errors
      end
      ret
  end

end
