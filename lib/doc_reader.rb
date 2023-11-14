# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'digest/md5'
require 'environment'

class DocReader
  include DRb::DRbUndumped

  def initialize
    @files = []
  end

  def openfile(filename)
    @file = File.open(filename, "r")
  end

  def mtime(filename)
    File.mtime(filename)
  end

  def closefile
    @file.close if not @file.closed?
  end

  def gets
    @file.gets
  end

  def fetch(fname)
    File.open(fname, "r") do |fp|
      while buf = fp.read(1024*4096)
        yield(buf)
      end
    end
    nil
  end

  def read(size)
    @file.read(size)
  end

  # Creates a tar archive containing the file or directory given by the source path.
  # If the source argument is a directory the content of the directory is
  # put directly into the archive without creating a root folder File.basename(source)
  # Returns the path to the tar archive created.
  def archive(source)
    source_name = File.basename(source)
    source_dir = File.dirname(source)
    tar_name = source_name
    if File.directory?(source)
      source_name = "."
      source_dir = source
    end
    randomstring = "%06d" % (rand(1000000)).to_i
    archive = "#{Environment.instance.vespa_home}/tmp/#{tar_name}.#{randomstring}.tar.gz"
    `tar czf #{archive} --directory #{source_dir} #{source_name}`
    archive
  end

  def delete(filename)
    File.delete(filename)
  end

  def size?(filename)
    File.size?(filename)
  end

  def exist?(filename)
    File.exist?(filename)
  end

  def md5(filename)
    return Digest::MD5.digest(filename)
  end

end


#class DocWriter
#  include DRb::DRbUndumped
#
#  def openfile(filename)
#    @file = File.open(filename, "w")
#  end
#
#  def closefile
#    @file.close if not @file.closed?
#  end
#
#  def puts
#    @file.puts
#  end
#
#  def print(part)
#    @file.print(part)
#  end
#
#end

