# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'json'
require 'tenant_rest_api'
require 'environment'

class Adminserver < VespaNode
  include TenantRestApi

  def initialize(*args)
    super(*args)
  end

  def transfer_app(application_dir, application_name, &block)
    FileUtils.mkdir_p(application_dir)
    app_path = "#{application_dir}/#{application_name}"
    File.open("#{app_path}.tar.gz", "w") do |file|
      block.call(file)
    end

    FileUtils.remove_dir(app_path) if File.exist?(app_path)
    execute("tar xzf #{app_path}.tar.gz " \
            "--directory #{application_dir}")
    return app_path
  end

  def deploy(app_path, params={})
    debug = (params[:nodebug] ? '' : '-d')
    force = (params[:force] ? '-f' : '')
    deploy_http(app_path, params)
  end

  def deploy_http(app_dir, params={})
    cmd = "vespa-deploy"
    if params[:force]
      cmd += " -f"
    end
    if params[:timeout]
      timeout = params[:timeout]
      timeout *= VALGRIND_TIMEOUT_MULTIPLIER if @valgrind
      cmd += " -t #{timeout}"
    elsif @valgrind
      cmd += " -t 60"
    end
    if params[:tenant]
      if not params[:skip_create_tenant]
        create_tenant_and_wait(params[:tenant], get_httpaddr_configserver.split("//")[1].split(":")[0])
      end
      cmd += " -e #{params[:tenant]}"
    end
    if params[:application_name]
      cmd += " -a #{params[:application_name]}"
    end
    if params[:instance]
      cmd += " -i #{params[:instance]}"
    end
    if params[:hosted_vespa]
      cmd += " -H"
    end
    if params[:rotations]
      cmd += " -R #{params[:rotations]}"
    end

    if params[:from_url]
      cmd += " -F #{params[:from_url]}"
    end

    if params[:vespa_version]
      cmd += " -V #{params[:vespa_version]}"
    end

    # Need to see stderr when deploy fails
    params = params.merge({:stderr => true})

    if params[:separate_upload_and_prepare]
      upload_start = Time.now
      execute("#{cmd} upload #{app_dir}", params)
      prepare_start = Time.now
      out = execute("#{cmd} prepare", params)
    else
      upload_start = Time.now
      prepare_start = upload_start
      out = execute("#{cmd} prepare #{app_dir}", params)
    end
    activate_start = Time.now
    unless params[:no_activate] then
      out += execute("#{cmd} activate", params)
    end
    deploy_finished = Time.now
    if params[:collect_timing]
      [out, (prepare_start - upload_start).to_f, (activate_start - prepare_start).to_f, (deploy_finished - activate_start).to_f]
    else
      out
    end
  end

  def get_httpaddr_configserver
    execute("vespa-print-default configservers_http 2>/dev/null", :noecho => true).chomp.split(" ")[0]
  end

  def wait_for_config_activated(expected_generation, params={})
    url = get_application_instance_url(params)
    generation = -1
    iterations = 0
    while iterations < 100 do
      result = http_request_get(URI(url), {})
      if result.code.to_i == 200 
        json = JSON.parse(result.body)
        generation = json["generation"].to_i
        break unless (generation != expected_generation)
      else
        puts "Unable to get config generation: #{result.inspect}, retrying"
      end
      iterations += 1
      sleep 0.1
    end

    if (generation != expected_generation)
      if (generation == -1)
        raise "Did not get expected generation #{expected_generation}, got response code #{result.code.to_i} from request #{url}, response body: #{json}"
      else
        raise "Did not get expected generation #{expected_generation}, got generation #{generation}"
      end
    end
  end

  def get_config_instance_url(params={})
    get_instance_url("config/v2", params)
  end

  def get_application_instance_url(params={})
    get_instance_url("application/v2", params)
  end

  def get_instance_url(prefix, params={})
    serverhost = get_httpaddr_configserver
    tenant = "default"
    application = "default"
    environment = "prod"
    region = "default"
    instance = "default"
    if params[:tenant]
      tenant = params[:tenant]
    end
    if params[:application_name]
      application = params[:application_name]
    end
    if params[:environment]
      environment = params[:environment]
    end
    if params[:region]
      region = params[:region]
    end
    if params[:instance]
      instance = params[:instance]
    end
    "#{serverhost}/#{prefix}/tenant/#{tenant}/application/#{application}/environment/#{environment}/region/#{region}/instance/#{instance}"
  end

  def get_model_config(params={}, required_config_generation)
    url = get_config_instance_url(params) + "/cloud.config.model?requiredGeneration=#{required_config_generation}"
    iterations = 0
    result = nil
    while iterations < 250 do
      result = http_request_get(URI(url), {})
      if result.code.to_i == 200
        break
      else
        puts "Unable to get model config: #{result.inspect}, retrying"
      end
      iterations += 1
      sleep 0.1
    end
    if result.code.to_i != 200
      raise "Unable to get model config: #{result.inspect}"
    end
    JSON.parse(result.body)
  end

  def get_addr_configserver
    execute("vespa-print-default configservers_rpc 2>/dev/null", :noecho => true).chomp
  end

end
