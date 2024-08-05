# Copyright Vespa.ai. All rights reserved.

require 'test/unit'
require 'app_generator/storage_app'


class StorageAppGenTest < Test::Unit::TestCase

  def file(name)
    File.dirname(__FILE__) + "/#{name}"
  end

  def create_default
    StorageApp.new.enable_document_api.default_cluster.sd("sd").provider("PROTON")
  end

  def create_default_with_doctype
    StorageApp.new.enable_document_api.default_cluster.sd("sd").provider("PROTON").
      doc_type("sd2", "sd2.foo == bar")
  end

  def create_advanced_configoverride
    StorageApp.new.enable_document_api.default_cluster.sd("sd").provider("PROTON").
            config(ConfigOverride.new("metricsmanager").
                add(ArrayConfig.new("consumers").
                    add(0, ConfigValue.new("name", "myconsumer")).
                    add(0, ArrayConfig.new("tags").
                        add(0, "logdefault"))))
  end

  def create_advanced_configoverride2
    snapshots = ArrayConfig.new("periods")
                           .add(0, 10)
                           .add(1, 60)
                           .add(2, 300)
    StorageApp.new.enable_document_api.default_cluster.sd("sd").provider("PROTON").
            config(ConfigOverride.new("metricsmanager").
                add("snapshot", snapshots))

  end

  def verify(expect, app)
    actual_file = file(expect + '.actual')
    File.open(actual_file, 'w') do |f|
      f.puts app.services_xml
    end
    assert(system("diff -u #{file(expect)} #{actual_file}"))
  end

  def test_default_storage_content
    verify('storageapp_default_storage_content.xml',
           create_default.provider("PROTON").
           final_redundancy(3))
  end

  def test_default_storage_content_streaming
    verify('storageapp_default_storage_content_streaming.xml',
           create_default.streaming.provider("PROTON"))
  end

  def test_default_storage_content_explicit_doctype_decls
    verify('storageapp_default_storage_content_explicit_doctype_decls.xml',
           create_default_with_doctype.provider("PROTON"))
  end

  def test_storage_content_with_thread_config
    verify('storageapp_storage_content_with_thread_config.xml',
           create_default.provider("PROTON").
           final_redundancy(3).
           persistence_threads(PersistenceThreads.new(7)))
  end

  def test_default_proton
    verify('storageapp_default_proton.xml', create_default.provider("PROTON"))
  end

  def test_default_dummy
    verify('storageapp_default_dummy.xml', create_default.provider("DUMMY"))
  end

  def test_complex_configoverride
    verify('storageapp_configoverride.xml', create_advanced_configoverride)
  end

  def test_complex_configoverride2
    verify('storageapp_configoverride2.xml', create_advanced_configoverride2)
  end

end
