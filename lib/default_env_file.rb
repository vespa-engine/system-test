# Copyright Vespa.ai. All rights reserved.

require 'fileutils'
require 'thread'

class DefaultEnvFile

  attr_reader :file_name

  def initialize(vespa_home)
    @file_name = "#{vespa_home}/conf/vespa/default-env.txt"
    @file_name_orig = "#{@file_name}.orig"
    @mutex = Mutex.new
  end

  def restore_original
    @mutex.synchronize do
      if File.exist?(@file_name_orig)
        file_name_new = "#{@file_name}.new"
        FileUtils.cp(@file_name_orig, file_name_new)
        File.rename(file_name_new, @file_name)
      end
    end
  end

  def backup_original(force)
    @mutex.synchronize do
      if File.exist?(@file_name) && (!File.exist?(@file_name_orig) || force)
        file_name_orig_new = "#{@file_name_orig}.new"
        FileUtils.cp(@file_name, file_name_orig_new)
        File.rename(file_name_orig_new, @file_name_orig)
      end
    end
  end

  def set(name, value, action='override')
    file_name_new = "#{@file_name}.new"
    @mutex.synchronize do
      lines = IO.readlines(@file_name)
      wfile = File.open(file_name_new, "w")
      lines.each do |line|
        chompedline = line.chomp
        splitline = chompedline.split(" ", 3)
        if splitline[1] != name
          wfile.write("#{chompedline}\n")
        end
      end
      if !value.nil?
        wfile.write("#{action} #{name} #{value}\n")
      end
      wfile.close
      File.rename(file_name_new, @file_name)
    end
  end

end
