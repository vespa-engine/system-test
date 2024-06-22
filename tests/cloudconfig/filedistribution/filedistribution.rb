# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'json'
require 'app_generator/container_app'
require 'app_generator/search_app'

# Note: 2 hosts are needed (one for config server, one for vespa app).
# If you want to run this manually you need to add "--configserverhost some_other_host"
class FileDistributionBasic < CloudConfigTest

  def can_share_configservers?
    true
  end

  def setup
    set_owner("musum")
    set_description("Tests file distribution basics")
    @valgrind = false
  end

  def test_filedistribution
    bundle = add_bundle_dir(selfdir + "initial", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'initial')
    compile_bundles(@vespa.nodeproxies.values.first)

    deploy(selfdir+"app", nil, {:bundles => [bundle]})
    start
  end

  # Tests getting a large file (300 Mb) (also verifies file downloaded
  # by checking the file size of the actual file used in handler)
  # Additionally tests filedistribution status API
  def test_filedistribution_large_file
    filesize_in_mb = 300
    filename = filesize_in_mb.to_s + "Mb.txt"
    generate_file(dirs.tmpdir + filename, filesize_in_mb)

    bundle_name = "fileshandler"
    bundle = add_bundle_dir(selfdir + "with_files", bundle_name)
    compile_bundles(@vespa.nodeproxies.values.first)
    app = ContainerApp.new.
      container(Container.new.
                handler(Handler.new("com.yahoo.vespatest.FilesizeHandler").
                        bundle(bundle_name).
                        binding("http://*/filesize").
                        config(ConfigOverride.new("com.yahoo.test.files").
                               add("myFile", filename))))
    deploy_output = deploy_app(app, {:bundles => [bundle], :files => {dirs.tmpdir + filename => filename}})
    start
    container = vespa.container.values.first
    print_filedistribution_status_until_finished(container)
    wait_for_application(container, deploy_output)

    filesize_from_handler = container.http_get2("/filesize").body.to_i
    puts "Handler got file with size #{filesize_from_handler}"
    assert_equal(filesize_in_mb * 1024 * 1024, filesize_from_handler)
  end

  def print_filedistribution_status_until_finished(container)
    puts "File distribution progress:"
    config_server = configserverhostlist[0]
    while true do
      json = container.get_json_over_http("/application/v2/tenant/#{@tenant_name}/application/#{@application_name}/environment/prod/region/default/instance/default/filedistributionstatus",
                                          19071,
                                          config_server)
      status = json['status']
      if status == 'UNKNOWN'
        puts "#{status}: #{json['message']}"
      elsif status == 'IN_PROGRESS' || status == 'FINISHED'
        fileReferences = json['hosts'][0]['fileReferences']
        status_for_host = json['hosts'][0]['status']
        puts "#{status_for_host}, #{fileReferences}"
        break if status == 'FINISHED'
      else
          raise "Unknown status #{status}"
      end
      sleep 0.1
    end
  end

  def generate_file(filename, filesize_in_mb)
    file_size = 0
    one_mb = 1024 * 1024
    string = 'a' * one_mb
    File.open(filename, 'w') do |f|
      while file_size < filesize_in_mb * one_mb
        f.print string
        file_size += string.size
      end
    end
  end

  def teardown
    stop
  end

end
