#!/usr/bin/env ruby
# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'tmpdir'
require 'optparse'
require 'environment'

require 'maven'

class MavenPopulator
  def initialize(version, m2repo)
    @version = version
    @m2repo = m2repo
  end

  def populate
    Dir.mktmpdir do |path|
      File.open(File.join(path, 'pom.xml'), 'w') do |file|
        file.write(Maven.pom_xml(@version, '', '', {
                                   :groupId => 'com.yahoo.prepopulate',
                                   :artifactId => 'mavenpopulator',
                                   :version => '1-SNAPSHOT',
                                   :name => 'Maven populator'
                                 }))
      end
      m2repo_arg = ''
      m2repo_arg = "-Dmaven.repo.local=#{@m2repo}"
      system("cd #{path} && mvn -B -T1C package #{m2repo_arg}")
    end
  end
end


if __FILE__ == $0
  version = '8-SNAPSHOT'
  m2repo = nil
  o = OptionParser.new
  o.on('-v', '--version VERSION', String, 'Vespa version', String) { |v|
    version = v
  }
  o.on('-r', '--m2repo M2REPO', String, 'M2REPO', String) { |v|
    m2repo = v
  }
  begin
    rest = o.parse!(ARGV)
  rescue
    OptionParser::InvalidOption
    puts o.to_s
    exit 1
  end
  unless rest.empty?
    puts o.to_s
    rest.each do |extra_input|
      puts "Unknown input: #{extra_input}"
    end
    exit 1
  end
  populator = MavenPopulator.new(version, m2repo)
  populator.populate
end
