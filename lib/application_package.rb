# Copyright Vespa.ai. All rights reserved.
class ApplicationPackage
  attr_reader :location
  attr_reader :admin_hostname

  def initialize(location, admin_hostname)
    @location = location
    FileUtils.mkdir_p(@location)
    @admin_hostname = admin_hostname
  end

  def use_bundle(bundle_dir, bundle)
    bundle_destination = @location + "/components/" + bundle.generate_final_name + '.jar'
    FileUtils.mkdir_p(File.dirname(bundle_destination))
    FileUtils.cp(Maven.bundle_file_path(bundle_dir, bundle), bundle_destination)
  end

end
