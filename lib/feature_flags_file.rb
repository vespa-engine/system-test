# Copyright Vespa.ai. All rights reserved.

require 'fileutils'
require 'thread'

# This class handles access to the feature flags for vespa
# system tests. Tests that change feature flags should not
# use a shared config server.

class FeatureFlagsFile

  attr_reader :file_name

  def initialize(vespa_home)
    @file_name = "#{vespa_home}/var/vespa/flag.db"
    @file_name_orig = "#{@file_name}.orig"
    @mutex = Mutex.new
  end

  def restore
    @mutex.synchronize do
      if File.exist?(@file_name_orig)
        file_name_new = "#{@file_name}.new"
        FileUtils.cp(@file_name_orig, file_name_new)
        File.rename(file_name_new, @file_name)
      end
    end
  end

  def backup(force)
    @mutex.synchronize do
      if !File.exist?(@file_name_orig) || force
        unless File.exist?(@file_name)
          file_name_new = "#{@file_name}.new"
          json = {'flags' => []}
          File.write(file_name_new, JSON.pretty_generate(json) + "\n")
          File.rename(file_name_new, @file_name)
        end
        file_name_orig_new = "#{@file_name_orig}.new"
        FileUtils.cp(@file_name, file_name_orig_new)
        File.rename(file_name_orig_new, @file_name_orig)
      end
    end
  end

  def set(id, rules)
    return if id.nil?
    file_name_new = "#{@file_name}.new"
    newflags = []
    @mutex.synchronize do
      if File.exist?(@file_name)
        json = JSON.parse(File.read(@file_name))
      else
        json = {'flags' => []}
      end
      flags = json['flags']
      flags.each do |flag|
        next if flag['rules'].nil? || flag['id'].nil?
        newflags.push(flag) unless id == flag['id']
      end
      newflags.push({'id' => id, 'rules' => rules}) unless rules.nil?
      json['flags'] = newflags
      File.write(file_name_new, JSON.pretty_generate(json) + "\n")
      File.rename(file_name_new, @file_name)
    end
  end

end
