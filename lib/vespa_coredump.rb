# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'tempfile'
require 'shellwords'

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
      ok = `lz4 -d -f < #{corename.shellescape} > #{corename_tmp.shellescape}`
      binline = `gdb -batch --core #{corename_tmp.shellescape}`
      if binline =~ /by `([^\s']+)/
        @stacktrace = `gdb -batch #{$1} #{corename_tmp.shellescape} -x #{f.path} 2>&1`
      end
    rescue
      @stacktrace = "Unable to execute gdb"
    ensure
      File.delete(corename_tmp.shellescape)
      f.unlink
    end
  end

  def save_content
    @stacktrace = IO.read(File.join(@coredir, @corefilename))
  end
end

