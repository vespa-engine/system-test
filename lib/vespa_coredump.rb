# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'tempfile'
require 'shellwords'
require 'open3'

class VespaCoredump
  attr_reader :coredir, :corefilename, :binaryfilename, :stacktrace

  def initialize(dir, filename, binary, stacktrace=nil)
    @coredir = dir
    @corefilename = filename
    @binaryfilename = binary

    if stacktrace == nil
      if filename =~ /^hs_err/
        save_content
      else
        save_stacktrace
      end
    else
      @stacktrace = stacktrace
    end
  end

  def save_stacktrace
    f = Tempfile.new("gdb.script")
    f.write("bt\n")
    f.write("thread apply all bt\n")
    f.close
    corename = File.join(@coredir, @corefilename)
    corename_tmp = corename + ".core"
    begin
      if corename.end_with?("lz4")
        out, err, status = Open3.capture3("lz4 -d -f < #{corename.shellescape} > #{corename_tmp.shellescape}")
        raise err if ! status
        corename = corename_tmp
      end
      binline, err, status = Open3.capture3("gdb -batch --core #{corename.shellescape}")
      raise err if ! status
      if binline =~ /by `([^\s']+)/
        @stacktrace, err, status = Open3.capture3("gdb -batch #{$1} #{corename.shellescape} -x #{f.path} 2>&1")
        raise err if ! status
      end
    rescue StandardError => e
      coredir_listing, err, status = Open3.capture3("ls -la #{coredir.shellescape}")
      @stacktrace = "Unable generate stacktrace with gdb for #{corename}. Contents of core dump directory:\n#{coredir_listing}\nException: #{e}\n"
    ensure
      File.delete(corename_tmp.shellescape) if File.exist?(corename_tmp.shellescape)
      f.unlink
    end
  end

  def save_content
    @stacktrace = IO.read(File.join(@coredir, @corefilename))
  end
end
