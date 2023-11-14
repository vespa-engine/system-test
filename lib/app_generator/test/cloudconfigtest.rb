# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test/unit'
require 'app_generator/cloudconfig_app'


class CloudconfigGenTest < Test::Unit::TestCase

  def file(name)
    File.join(File.dirname(__FILE__), "#{name}")
  end

  def verify(expect, actual)
    File.open(file(expect + '.actual'), 'w') do |f|
      f.puts actual
    end
    assert(system("diff -u #{file expect + '.actual'} #{file expect}"))
  end


  def test_basiccloudconfig_app
    verify('basic_cloudconfig.xml', CloudconfigApp.new.services_xml)
  end

  def test_hostaliases_app
    verify('hosts_cloudconfig.xml', CloudconfigApp.new.hosts_xml)
  end
end
