# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class ApplicationPackage
  attr_reader :location

  def initialize(location)
    @location = location
    FileUtils.mkdir_p(@location)
  end

  def use_bundle(bundle_dir, bundle)
    bundle_destination = @location + "/components/" + bundle.generate_final_name + '.jar'
    FileUtils.mkdir_p(File.dirname(bundle_destination))
    FileUtils.cp(Maven.bundle_file_path(bundle_dir, bundle), bundle_destination)
  end

  # Plain copy of a ready-made bundle from a location to the components dir
  def use_system_bundle(bundle_dir, bundle_name)
    bundle_destination = @location+ "/components/" + bundle_name
    FileUtils.mkdir_p(File.dirname(bundle_destination))
    FileUtils.cp(bundle_dir + bundle_name, bundle_destination)
  end

  def use_bundles(bundle_dir, bundles)
    bundles.each { | bundle|
      use_bundle(bundle_dir, bundle)
    }
  end

  def write_services_xml(services_content)
    File.open(@location + "/services.xml", "w:utf-8") { | file |
      file.puts('<?xml version="1.0" encoding="utf-8" ?>')
      file.puts(services_content)
    }
  end
end
