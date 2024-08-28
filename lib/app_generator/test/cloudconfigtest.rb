# Copyright Vespa.ai. All rights reserved.

require 'test/unit'
require 'app_generator/config_app'


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


  def test_basic_config_app
    verify('basic_cloudconfig.xml', ConfigApp.new.services_xml)
  end

  def test_hostaliases_app
    verify('hosts_cloudconfig.xml', ConfigApp.new.hosts_xml)
  end
end
