# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'socket'
require 'nodetypes/storage'
require 'nodetypes/qrs'
require 'bundle'
require 'maven'
require 'yaml'
require 'application_package'
require 'document_api_v1'
require 'environment'

class VespaModel

  attr_reader :nodeproxies, :hostalias, :adminserver, :configservers, :logserver
  attr_reader :qrserver, :storage, :search, :slobrok, :qrs
  attr_reader :metricsproxies
  attr_reader :container, :clustercontrollers, :default_document_api_port, :document_api_v1

  def initialize(testcase, vespa_version=nil)
    @testcase = testcase
    @nodeproxies = {}
    @valgrind_logs_glob = "#{Environment.instance.vespa_home}/tmp/valgrind.*.log.*"
    @qrs_logs_dir = "#{Environment.instance.vespa_home}/logs/vespa/access"
    @sanitizer_logs_dir = "#{Environment.instance.tmp_dir}/sanitizer"
    @deployments = 0
    @bundles = []
    @vespa_version = vespa_version
    @hostalias = {}
    @clustercontrollers = {}
    @default_document_api_port = 19020
    @document_api_v1 = nil
    reset_services
  end

  def reset_services
    @configservers = {}
    @logserver = nil
    @adminserver = nil
    @qrserver = {}
    @container = {}
    @storage = Hash.new {|h,k| h[k] = Storage.new(@testcase, k, self) }
    @search = Hash.new {|h,k| h[k] = Search.new(@testcase, self) }
    @qrs = Hash.new {|h,k| h[k] = Qrs.new(@testcase, self) }
    @metricsproxies = {}
    @slobrok = {}
    @clustercontrollers = {}
    @stop_hooks = []
  end

  def content_node(cluster, index)
    node = nil

    if (@search[cluster] != nil)
      node = @search[cluster].searchnode[index.to_i]
    end

    if (node != nil)
      return node
    end

    return @storage[cluster].storage[index.to_s]
  end

  def stop_content_node(cluster, index, wait_timeout = 60, states = 'dm')
    content_node(cluster, index).stop

    if wait_timeout != 0
      wait_timeout *= 10 if @testcase.valgrind
      @storage[cluster].wait_for_current_node_state("storage", index.to_i, states, wait_timeout)
    end
  end

  def start_content_node(cluster, index, wait_timeout = 60, wait_for_node_up = true)
    content_node(cluster, index).start

    wait_timeout *= 10 if @testcase.valgrind
    if (wait_timeout != 0) && wait_for_node_up
      @storage[cluster].wait_for_current_node_state("storage", index.to_i, 'u', wait_timeout)
    end
  end

  def distributor_node(cluster, index)
    return @storage[cluster].distributor[index.to_s]
  end

  def stop_distributor_node(cluster, index, wait_timeout = 60)
    distributor_node(cluster, index).stop

    if wait_timeout != 0
      wait_timeout *= 10 if @testcase.valgrind
      @storage[cluster].wait_for_current_node_state("distributor", index.to_i, 'sd', wait_timeout)
    end
  end

  def start_distributor_node(cluster, index, wait_timeout = 60, wait_for_node_up = true)
    distributor_node(cluster, index).start

    wait_timeout *= 10 if @testcase.valgrind
    if (wait_timeout != 0) && wait_for_node_up
      @storage[cluster].wait_for_current_node_state("distributor", index.to_i, 'u', wait_timeout)
    end
  end

  def stop_distributor_and_content_node(cluster, index, wait_timeout = 60)
    distributor_node(cluster, index).stop
    content_node(cluster, index).stop

    if wait_timeout != 0
      wait_timeout *= 10 if @testcase.valgrind
      @storage[cluster].wait_for_current_node_state("distributor", index.to_i, 'sd', wait_timeout)
      @storage[cluster].wait_for_current_node_state("storage", index.to_i, 'sdm', wait_timeout)
    end
  end

  def start_distributor_and_content_node(cluster, index, wait_timeout = 60, wait_for_node_up = true)
    distributor_node(cluster, index).start
    content_node(cluster, index).start

    wait_timeout *= 10 if @testcase.valgrind
    if (wait_timeout != 0) && wait_for_node_up
      @storage[cluster].wait_for_current_node_state("distributor", index.to_i, 'u', wait_timeout)
      @storage[cluster].wait_for_current_node_state("storage", index.to_i, 'u', wait_timeout)
    end
  end

  def add_bundle(sourcedir, bundlename, params={})
    if @deployments > 0
      @testcase.output("add_bundle must be called before deploy.")
    end
    bundle = Bundle.new(sourcedir, bundlename, params)
    @bundles.push(bundle)
    bundle
  end

  def clear_bundles()
    @bundles = []
  end

  def init_nodeproxies
    @testcase.hostlist.each do |hostname|
      node_proxy = NodeProxy.new(hostname, @testcase)
      detect_sanitizers(node_proxy)
      @nodeproxies[hostname] = node_proxy
    end
  end

  def resolve_app(application, sdfile, params)
    @testcase.output("Resolving application #{application}")

    tmp_application = create_tmp_application(application)

    vespa_nodes = tmp_application + "/hosts.xml"
    vespa_services = tmp_application + "/services.xml"
    validation_overrides = tmp_application + "/validation-overrides.xml"

    if (not File.exists?(vespa_nodes) and @testcase.use_shared_configservers)
      outf = File.new(vespa_nodes, "w")
      num_hosts = 1
      if (params[:num_hosts])
        num_hosts = params[:num_hosts]
      end
      outf.puts(make_hosts_file(num_hosts))
      outf.close
    end

    if params[:sed_vespa_services]
      @testcase.output("Applying #{params[:sed_vespa_services]} on services.xml")
      tmp_services_xml = tmp_application + "/tmp_services.xml"
      `cat #{vespa_services} | #{params[:sed_vespa_services]} > #{tmp_services_xml} ; mv #{tmp_services_xml} #{vespa_services}`
    end

    if params[:hosts_to_use]
      hostlist = params[:hosts_to_use]
    elsif params[:hostlist]
      hostlist = params[:hostlist]
    else
      hostlist = @testcase.hostlist
    end

    if hostlist.length == 1 and count_vespahosts(vespa_nodes) > 1
      @testcase.output("WARNING: Only one host available (#{hostlist.first}), not " +
                       "substituting hostnames in hosts.xml")
    else
      if File.file?(vespa_nodes)
        substitute_hosts(hostlist, vespa_nodes)
      end
    end

    substitute_sdfile(tmp_application, vespa_services, sdfile) if sdfile
    add_perfmap_agent_to_container_jvm_options(vespa_services) if @testcase.performance?
    create_rules_dir(tmp_application, params[:rules_dir])
    create_components_dir(tmp_application, params[:components_dir])
    create_search_dir(tmp_application, params[:search_dir])
    copy_rank_expression_files(tmp_application, params[:rank_expression_files])
    copy_sd_files(tmp_application, params[:sd_files])

    parse_node_list(vespa_nodes) if File.file?(vespa_nodes)
    @testcase.add_dirty_nodeproxies(@nodeproxies)

    copy_params_files(tmp_application, params)

    applicationbuffer = Dir.glob(tmp_application + "/*").join("\n") + "\n"
    applicationbuffer += "services.xml:\n" + File.open(vespa_services, "r").readlines.join('')
    applicationbuffer += "hosts.xml:\n" + File.open(vespa_nodes, "r").readlines.join('') if File.exists?(vespa_nodes)
    if (File.exists?(validation_overrides))
      applicationbuffer += "validation-overrides.xml:\n" + File.open(validation_overrides, "r").readlines.join('')
    else
      applicationbuffer += "No validation-overrides.xml\n"
    end

    @testcase.output(applicationbuffer)

    if @deployments == 0 and not params[:no_init_logging]
      init_logging
    end
    admin_hostname, config_hostnames = get_admin_and_config_servers(vespa_nodes, vespa_services, hostlist)
    if (@testcase.use_shared_configservers)
      if admin_hostname == ""
        puts "No admin host found, using first host in list"
        admin_hostname = hostlist.first
      end
      @testcase.output("Using config servers: #{@testcase.configserverhostlist.join(', ')}")
      set_addr_configservers(@testcase.configserverhostlist)
    else
      @testcase.output("Using config servers: #{config_hostnames.join(', ')}")
      set_addr_configservers(config_hostnames)
      if not params[:skip_configserver_start] then
        config_hostnames.each do |hostname|
          if @nodeproxies[hostname] == nil
            @testcase.output("Missing nodeproxies entry for: #{hostname}, adding")
            @nodeproxies[hostname] = NodeProxy.new(hostname, @testcase)
          end
          @nodeproxies[hostname].start_configserver
        end
      end
      config_hostnames.each do |hostname|
        if @nodeproxies[hostname] == nil
          @testcase.output("Missing nodeproxies entry for: #{hostname}, adding")
          @nodeproxies[hostname] = NodeProxy.new(hostname, @testcase)
        end
        @nodeproxies[hostname].ping_configserver
      end
    end

    adminserver = get_adminserver(admin_hostname)

    application_package = ApplicationPackage.new(tmp_application, admin_hostname)
    compile_and_add_bundles(adminserver, application_package, params)
    return application_package
  end

  def get_adminserver(hostname)
    adminserver_service_entry = {"servicetype" => "adminserver", "hostname" => hostname}
    return @nodeproxies[hostname].get_service(adminserver_service_entry)
  end

  def get_logserver(hostname)
    logserver_service_entry = {"servicetype" => "logserver", "hostname" => hostname}
    return @nodeproxies[hostname].get_service(logserver_service_entry)
  end

  def deploy(application, sdfile, params)
    resolved_app = resolve_app(application, sdfile, params)
    app_handle = transfer_resolved(resolved_app, params)
    deploy_transfered(app_handle, params)
  end

  def transfer_resolved(application, params)
    # clean logs if this is the first deployment for the testcase
    admin_hostname = application.admin_hostname
    @testcase.output("Deploying application #{application.location} on adminserver #{admin_hostname}")
    @adminserver = get_adminserver(admin_hostname)

    # create logserver service so that we can get the logs even if deployment fails
    @logserver = get_logserver(admin_hostname)

    app_handle = nil
    app_handle = transfer_app_to_adminserver(adminserver, application.location) if not params[:dryrun]
    return app_handle
  end

  def deploy_transfered(app_handle, params)
    # Setup these in case of shared configservers 
    if @testcase.use_shared_configservers
      params = params.merge({:tenant => @testcase.tenant_name}) unless params[:tenant]
      params = params.merge({:application_name => @testcase.application_name()}) unless params[:application_name]
    end
    adminserver = @adminserver
    if not params[:dryrun]
      output = deploy_on_adminserver(adminserver, app_handle, params)
      # Handle case where we get an array with output and timing values back (performance tests)
      deploy_output = output.kind_of?(Array) ? output[0] : output
      config_generation = @testcase.get_generation(deploy_output).to_i

      if not params[:skip_create_model]
        if @testcase.use_shared_configservers && !params[:no_activate]
          adminserver.wait_for_config_activated(@testcase.get_generation(deploy_output).to_i, params)
        end
        create_model(adminserver.get_model_config(params, config_generation))
      end
    end
    @deployments += 1

    @document_api_v1 = DocumentApiV1.new(adminserver.hostname, @default_document_api_port, @testcase)

    return output
  end

  def create_tmp_application(application)
    tmp_application = @testcase.dirs.tmpdir+File.basename(application)
    if File.exists?(tmp_application)
      FileUtils.rm_rf(tmp_application)
    end
    if File.exists?(tmp_application)
      @testcase.output(">>> Unable to properly remove old application")
    end
    FileUtils.cp_r(application, tmp_application)
    FileUtils.chmod_R 0755, tmp_application
    tmp_application
  end

  def copy_params_files(tmp_application, params)
    if params[:files]
      params[:files].each do |from, to|
        @testcase.output("Copying in required file for application " + from + " => " + to)
        dir = File.dirname(to)
        to_dir = tmp_application + "/" + dir
        FileUtils.mkdir_p(to_dir, :verbose => true)
        FileUtils.cp(from, to_dir + '/' + File.basename(to), :verbose => true)
      end
    end
  end

  def compile_and_add_bundles(adminserver, app_package, params={})
    if params[:bundles]
      params[:bundles].each do |bundle|
        app_package.use_bundle(@testcase.dirs.bundledir, bundle)
      end
    else
      compile_bundles(adminserver)
      @bundles.each do |bundle|
        app_package.use_bundle(@testcase.dirs.bundledir, bundle)
      end
    end
  end

  def make_hosts_file(host_count)
    s = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n" +
        "<hosts>\n"
    for i in (1..host_count)
      s += "<host name=\"foo#{i}\">\n" +
           "  <alias>node#{i}</alias>\n" +
           "</host>\n"
      end
    s += "</hosts>\n"
  end

  def compile_bundles(adminserver)
    Maven.compile_bundles(@bundles, @testcase, adminserver, @vespa_version)
  end

  def deploy_generated(applicationbuffer, sdfile, params, hostbuffer, deploymentbuffer, validation_overridesbuffer)
    tmp_application = create_services_xml(applicationbuffer)
    if hostbuffer
      outf = File.new("#{tmp_application}/hosts.xml", "w")
      outf.puts(hostbuffer)
      outf.close
    elsif (params[:num_hosts] && params[:num_hosts] > 1) || @testcase.use_shared_configservers
      outf = File.new("#{tmp_application}/hosts.xml", "w")
      outf.puts(make_hosts_file(params[:num_hosts] || 1))
      outf.close
    end
    if deploymentbuffer
      outf = File.new("#{tmp_application}/deployment.xml", "w")
      outf.puts(deploymentbuffer)
      outf.close
    end
    if validation_overridesbuffer
      outf = File.new("#{tmp_application}/validation-overrides.xml", "w")
      outf.puts(validation_overridesbuffer)
      outf.close
    end
    FileUtils.chmod_R 0755, tmp_application
    deploy(tmp_application, sdfile, params)
  end

  def create_services_xml(applicationbuffer)
    tmp_application = @testcase.dirs.tmpdir+"tmp/generatedapp"
    if File.exists?(tmp_application)
      FileUtils.rm_rf(tmp_application)
    end
    FileUtils.mkdir_p(tmp_application)
    outf = File.new("#{tmp_application}/services.xml", "w")
    outf.puts(applicationbuffer)
    outf.close
    tmp_application
  end

  def deploy_local(appdir, appname, proxy, selfdir, params={})
    tarfile_remote = "sampleapp_proxy.tar"
    tarfile_local = @testcase.dirs.tmpdir+"sampleapp.tar"
    proxy.execute("tar --exclude-vcs --dereference -C #{appdir} -cvf #{tarfile_remote} #{appname}")
    content = proxy.readfile(tarfile_remote)
    File.open(tarfile_local, "w") do |file|
      file.write(content)
    end

    destdir=@testcase.dirs.tmpdir + "apps/"
    @testcase.output("Extracting #{tarfile_local} into #{destdir}")
    puts `mkdir -p #{destdir}; cd #{destdir}; tar xf #{tarfile_local}`
    deploy(destdir+appname, nil, params)
  end

  def create_and_copy_dir(tmp_application, dir_name, src_dir)
    tmp_dir = tmp_application+"/" + dir_name
    FileUtils.mkdir_p(tmp_dir)
    if src_dir
      FileUtils.cp_r(src_dir + "/.", tmp_dir + "/.")
      FileUtils.chmod_R 0755, tmp_application
    end
  end

  def create_rules_dir(tmp_application, rules_dir)
    create_and_copy_dir(tmp_application, "rules", rules_dir)
  end

  def create_components_dir(tmp_application, components_dir)
    create_and_copy_dir(tmp_application, "components", components_dir)
  end

  def create_search_dir(tmp_application, search_dir)
    create_and_copy_dir(tmp_application, "search", search_dir)
  end

  def copy_files(tmp_application, dir, files)
    if files and not files.empty?
      dest_dir = tmp_application + "/" + dir + "/"
      FileUtils.mkdir_p(dest_dir)
      files.each do |file|
        FileUtils.cp(file, dest_dir)
      end
    end
  end

  def copy_rank_expression_files(tmp_application, rank_files)
    copy_files(tmp_application, "schemas", rank_files)
  end

  def copy_sd_files(tmp_application, sd_files)
    copy_files(tmp_application, "schemas", sd_files)
  end

  def add_perfmap_agent_to_container_jvm_options(vespa_services)
    doc = REXML::Document.new(File.new(vespa_services))
    paths = ['services/jdisc/nodes',
             'services/container/nodes']
    paths.each do |path|
      REXML::XPath.each(doc, path) do |e|
        REXML::XPath.each(doc, path + "/jvm") do |e|
          newattr = @testcase.perfmap_agent_jvmarg
          origattr = e.attributes['options']
          newattr += ' ' + origattr if origattr
          e.attributes['options'] = newattr
        end
      end
    end
    File.open(vespa_services, 'w') do |out|
      doc.write(out, -1)
    end
  end

  def substitute_sdfile(application, services, sdfile)
    return if sdfile.empty?

    sddir = application + "/schemas/"
    FileUtils.mkdir_p(sddir)
    Dir.glob(sddir + "*.sd").each {|sd| File.delete(sd)}

    if sdfile.class == Array
      sdfile.each do |sd|
        FileUtils.cp(sd, sddir)
      end
    else # sdfile is not an array, take it as a string
      FileUtils.cp(sdfile, sddir)
    end
  end

  def count_vespahosts(hostfile)
    if File.file?(hostfile)
      hostxml = REXML::Document.new(File.open(hostfile))
      return hostxml.root.elements.size
    else
      # If we do not have a hosts file we want one node
      return 1
    end
  end

  def substitute_hosts(hostlist, vespa_nodes_xmlfile)
    vespa_nodes_xmlcontent = ""
    vespa_substituted_nodes_xmlcontent = ""

    File.open(vespa_nodes_xmlfile, "r") do |file|
      vespa_nodes_xmlcontent = file.read
    end

    vespa_hosts_parser = VespaHosts.new(vespa_nodes_xmlcontent)
    xmlfile_numhosts = count_vespahosts(vespa_nodes_xmlfile)

    if xmlfile_numhosts <= hostlist.length
      # required hosts are <= supplied hosts, do not reorder host aliases
      vespa_substituted_nodes_xmlcontent = vespa_hosts_parser.generate_no_reordering(hostlist)
    else
      raise "Only #{hostlist.length} hosts available from hostlist, #{xmlfile_numhosts} " +
            "hosts required to deploy #{vespa_nodes_xmlfile}"
    end

    File.open(vespa_nodes_xmlfile, "w") do |file|
      file.print(vespa_substituted_nodes_xmlcontent)
    end
    @testcase.output("Hosts: " + hostlist.inspect + "\nXML:\n"+ vespa_substituted_nodes_xmlcontent)
  end

  # Parses _vespa_nodes_ and creates a list of NodeProxy objects that are
  # referenced both from @nodeproxies and @hostalias.
  def parse_node_list(vespa_nodes)
    doc = REXML::Document.new(File.open(vespa_nodes))
    root = doc.root
    root.each_element do |element|
      hostname = element.attributes["name"]
      if not @nodeproxies[hostname]
        puts "No nodeproxy for #{hostname} found during initialization, adding now instead."
        @nodeproxies[hostname] = NodeProxy.new(hostname, @testcase)
      end
      element.each_element("alias") do |host_alias|
        @hostalias[host_alias.text] = @nodeproxies[hostname]
      end
    end
  end

  def get_admin_version(services_root)
    if services_root.elements["admin"]
      services_root.elements["admin"].attribute("version").to_s.chomp
    else
      ""
    end
  end

  def get_admin_and_config_servers(vespa_nodes, services, hostlist)
    if not File.file?(vespa_nodes)
      # If we are without a vespa hosts file, just return the first
      # (and probably only node available)
      @testcase.output("No hosts defined in hosts.xml, using " + hostlist.first + " as admin and config server")
      return [hostlist.first, [hostlist.first]]
    end
    nodes_root = REXML::Document.new(File.open(vespa_nodes)).root
    services_root = REXML::Document.new(File.open(services)).root
    admin_hostname = ""
    admin_alias = ""
    config_hostnames = []
    config_aliases = []

    # In version 3.0 there is no config or admin server explicitly defined
    if get_admin_version(services_root) == "3.0" then
      @testcase.output("Admin version 3.0, using " + hostlist.first + " as admin and config server")
      return [hostlist.first, [hostlist.first]]
    end

    # support both old <configserver> and new <configservers><configserver> syntax
    if services_root.elements["admin/configservers"] then
      configserver_path = "admin/configservers/configserver"
    else
      configserver_path = "admin/configserver"
    end

    services_root.each_element(configserver_path) do |e|
      config_aliases << e.attributes["hostalias"]
    end

    services_root.each_element("admin/adminserver") do |e|
      admin_alias = e.attributes["hostalias"]
    end

    # if no config servers are explicitly defined, the admin server
    # will run a config server
    if config_aliases.empty?
      config_aliases << admin_alias
    end

    # if no admin server is explicitly defined, the first config server
    # will run an admin server
    if admin_alias == ""
      admin_alias = config_aliases.first
    end

    if (config_aliases.empty? and admin_alias == "")
      raise "No config server or admin server defined. Check services.xml"
    end

    nodes_root.each_element("host") do |host|
      host.each_element("alias") do |host_alias|
        if (admin_alias == host_alias.text)
          admin_hostname = host.attributes["name"]
        end
        if (config_aliases.include?(host_alias.text))
          config_hostnames << host.attributes["name"]
        end
      end
    end

    @testcase.output("Using #{admin_hostname} as admin server.\n")
    return [admin_hostname, config_hostnames]
  end

  # Parses model config (json), and generates service objects using create_service.
  def create_model(modelconfig)
    begin
      reset_services
      modelconfig["hosts"].each do |host|
        services = host["services"]
        services.each do |service_entry|
          # setup expected variable names to avoid changing a lot of code at once.
          service_entry["hostname"] = host["name"]
          service_entry["config-id"] = service_entry["configid"]
          service_entry["servicename"] = service_entry["name"]
          service_entry["servicetype"] = service_entry["type"]
          ports_by_tag = {}
          service_entry["ports"].each do |entry|
            entry["tags"].strip.split(" ").each do |tag|
              ports_by_tag[tag] = entry["number"].to_i
            end
          end
          service_entry["ports_by_tag"] = ports_by_tag
          portsonly = service_entry["ports"].map do |entry|
            entry["number"].to_i
          end
          service_entry["ports"] = portsonly

          # index for content nodes are invisible in model config, snoop configid:
          c = service_entry["config-id"]
          match_content1 = Regexp.new('^\w+/search/cluster\.\w+/(\d+)$').match(c)
          match_content2 = Regexp.new('^.\w+/search/(\d+)$').match(c)

          cluster = service_entry["clustername"]
          if match_content1
             service_entry["num"] = match_content1[1].to_i
             feed_destination = "storage/cluster.#{cluster}/storage/*/default"
           elsif match_content2
             service_entry["num"] = match_content2[1].to_i
             feed_destination = "storage/cluster.#{cluster}/storage/*/default"
          else
            feed_destination = nil
          end
          service_entry["feed-destination"] = feed_destination
          create_service(service_entry)
        end
      end
      if @adminserver == nil && @logserver != nil
        @adminserver = get_adminserver(@logserver.hostname)
      end
    rescue => e
        @testcase.output("ERROR #{e} while creating vespa model from JSON: #{modelconfig}")
      raise e
    end
  end

  # Creates a service object based on the _service_ hash, and places it
  # in the appropriate location. All values are subclasses of vespa_node.
  # Note that services belonging to a search cluster are added to @search
  def create_service(service)
    node_handle = @nodeproxies[service["hostname"]]
    if !node_handle
      if @testcase.use_shared_configservers
        @testcase.output("Could not find node '#{service['hostname']}' for service '#{service['servicetype']}' " + "in list of node proxies: (#{@nodeproxies.keys.join(',')}). Ignoring.")
        return
      else
        raise "Could not find node '#{service['hostname']}' for service '#{service['servicetype']}' " + "in list of node proxies: (#{@nodeproxies.keys.join(',')})"
      end
    end

    remote_serviceobject = node_handle.get_service(service)
    if service["servicetype"] == "qrserver"
      clustername = service["clustername"]
      @qrs[clustername].add_service(remote_serviceobject)
      @qrserver[remote_serviceobject.index] = remote_serviceobject
    elsif service["servicetype"] == "container"
      clustername = service["clustername"]
      @qrs[clustername].add_service(remote_serviceobject)
      @container[clustername + '/' + remote_serviceobject.index] = remote_serviceobject
    elsif service["servicetype"] == "container-clustercontroller"
      @clustercontrollers[remote_serviceobject.index] = remote_serviceobject
    elsif service["servicetype"] == "adminserver"
      @adminserver = remote_serviceobject
    elsif service["servicetype"] == "logserver"
      @logserver = remote_serviceobject
    elsif service["clustertype"] == "storage"
      clustername = service["clustername"]
      @storage[clustername].add_service(remote_serviceobject)
    elsif service["clustertype"] == "content"
      clustername = service["clustername"]
      @storage[clustername].add_service(remote_serviceobject)
    elsif service["clustertype"] == "search"
      clustername = service["clustername"]
      @search[clustername].add_service(remote_serviceobject)
    elsif service["servicetype"] == "slobrok"
      @slobrok[remote_serviceobject.index] = remote_serviceobject
    elsif service["servicetype"] == "configserver"
      @configservers[remote_serviceobject.index] = remote_serviceobject
    elsif service["servicetype"] == "metricsproxy-container"
      @metricsproxies[service["hostname"]] = remote_serviceobject
    elsif service["servicetype"] == "logd" or service["servicetype"] == "config-sentinel" or service["servicetype"] == "configproxy"
      # Ignoring these
    else
      puts "Unknown service type #{service['servicetype']}"
    end
  end

  # Returns a fbench service object.
  def create_fbench_service(hostname)
    service_entry = {"servicetype" => "fbench", "hostname" => hostname}
    node_handle = @nodeproxies[hostname]
    node_handle.get_service(service_entry)
  end

  # Deploys _application_ on the adminserver node.
  def transfer_app_to_adminserver(adminserver, application)
    application_name = File.basename(application)
    application_dir = File.dirname(application)
    pid = Process.pid
    @testcase.output("Start tgz creation of #{application_name}")
    `cd #{application_dir}; tar czf #{application_name}_#{pid}.tar.gz #{application_name}`
    application_content = ""
    @testcase.output("Start read of tgz file #{application_name}")
    File.open("#{application_dir}/#{application_name}_#{pid}.tar.gz", 'rb') do |file|
      application_content = file.read
    end
    @testcase.output("Delete temporary tgz file #{application_name}")
    File.delete("#{application_dir}/#{application_name}_#{pid}.tar.gz")
    @testcase.output("Transfer compressed content #{application_name} to adminserver")
    app_handle = adminserver.transfer_app(application_dir, application_name) do |fp|
      application_content.bytes.each_slice(1024*1024) { |slice|
        fp.write(slice.pack('C*'))
      }
    end
    return app_handle
  end

  def deploy_on_adminserver(adminserver, app_handle, params={})
    @testcase.output("Deploy from admin server with remote handle = #{app_handle}")
    adminserver.deploy(app_handle, params)
  end

  def set_addr_configservers(config_hostnames)
    @nodeproxies.each_value do |handle|
      @testcase.output("Set addr_configserver to " + config_hostnames.to_s + " on " + handle.hostname)
      handle.set_addr_configserver(config_hostnames)
    end
  end

  # Checks all nodes for coredumps produced in the time interval of the test.
  def check_coredumps(starttime, endtime)
    coredumps = {}
    @nodeproxies.each_value do |handle|
      node_coredumps = handle.check_coredumps(starttime, endtime)
      if not node_coredumps.empty?
        coredumps[handle.name] = copy_coredumps(handle, node_coredumps)
      end
    end
    coredumps
  end

  def copy_coredumps(node, node_coredumps)
    coredumps = []
    node_coredumps.each do |coredump|
      destdir = @testcase.dirs.coredir
      @testcase.output("Copying coredump from #{coredump.coredir}/#{coredump.corefilename} to #{destdir}")
      node.copy_remote_file_into_local_directory("#{coredump.coredir}/#{coredump.corefilename}", destdir)
      coredumps.push(VespaCoredump.new(destdir, coredump.corefilename, coredump.binaryfilename, coredump.stacktrace))
    end
    coredumps
  end

  # Remove vespa logs, reset valgrind options, remove valgrind logs and start memory monitoring.
  def init_logging
    @nodeproxies.each_value do |handle|
      reset_sanitizers(handle, true)
      reset_valgrind(handle)
      handle.execute("rm -f #{@valgrind_logs_glob}")
      handle.execute("rm -rf #{Environment.instance.vespa_home}/logs/vespa/*")
      handle.start_monitoring
    end
  end

  def detect_sanitizers(handle)
    sanitizers = handle.detect_sanitizers
    @testcase.detected_sanitizers(sanitizers)
  end

  def setup_sanitizers(handle)
    handle.setup_sanitizers if @testcase.has_active_sanitizers
  end

  def reset_sanitizers(handle, cleanup)
    handle.reset_sanitizers(cleanup)
  end

  def setup_valgrind(handle)
    handle.set_bash_variable("VESPA_USE_VALGRIND", @testcase.valgrind) if @testcase.valgrind
    handle.set_bash_variable("VESPA_VALGRIND_OPT", @testcase.valgrind_opt) if @testcase.valgrind_opt
  end

  def reset_valgrind(handle)
      handle.unset_bash_variable("VESPA_USE_VALGRIND")
      handle.unset_bash_variable("VESPA_VALGRIND_OPT")
  end

  # Starts vespa_base on all nodes.
  def start_base
    threadlist = []
    @nodeproxies.each_value do |handle|
      setup_sanitizers(handle)
      setup_valgrind(handle)
      threadlist << Thread.new(handle) do |my_handle|
        my_handle.start_base
      end
    end
    threadlist.each do |thread|
      thread.join
    end
  end

  # Starts vespa_base on all nodes.
  def start
    if @testcase.cmd_args[:nostart]
      @testcase.output("Skipping Vespa start")
    else
      start_base
    end
  end

  # Stop http server on all nodes
  def stop_http_servers(stop_nodes=@nodeproxies)
    threadlist = []
    stop_nodes.each_value do |handle|
      threadlist << Thread.new(handle) do |my_handle|
        my_handle.http_server_stop
      end
    end
    threadlist.each do |thread|
      thread.join
    end
  end

  # Stops vespa_base on all the nodes given by _stopnodes_ (default is _@nodeproxies_).
  def stop_base(stop_nodes=@nodeproxies)
    threadlist = []
    stop_nodes.each_value do |handle|
      reset_sanitizers(handle, false)
      reset_valgrind(handle)
      threadlist << Thread.new(handle) do |my_handle|
        my_handle.stop_base
      end
    end
    threadlist.each do |thread|
      thread.join
    end
  end

  def stop_configservers(stop_nodes=@nodeproxies)
    threadlist = []
    stop_nodes.each_value do |handle|
      threadlist << Thread.new(handle) do |my_handle|
        #my_handle.print_configserver_stack
        my_handle.stop_configserver
      end
    end
    threadlist.each do |thread|
      thread.join
    end
  end

  def backup_log(proxies)
    if @logserver
      @testcase.output("Backing up vespa logs")
      File.open(@testcase.dirs.vespalogdir + "vespa.log", "w") do |file|
        if @testcase.dirty_nodeproxies.length > 1 # have been multinode at least once
          @logserver.get_vespalog(:multinode => true) do |buf|
            file.write(buf)
          end
        else
          @logserver.get_vespalog do |buf|
            file.write(buf)
          end
        end
      end
      save_logfile("#{Environment.instance.vespa_home}/logs/vespa/zookeeper.configserver.0.log")
      save_logfile("#{Environment.instance.vespa_home}/logs/vespa/zookeeper.container-clustercontroller.0.log")
    end
    proxies.each_value do |handle|
      save_qrserver_logfiles(handle) unless @testcase.performance?
    end
    @testcase.output("Logfiles saved")
  end

  def add_stop_hook(hook)
    @stop_hooks << hook
  end

  # Stops vespa_base on all nodes used by the testcase, and stops vespa_config_server
  # on the admin node.
  def stop
    @deployments = 0
    nodes_exceeded_memory_limit = []
    if @testcase.cmd_args[:nostop]
      @testcase.output("Skipping Vespa stop")
    elsif @testcase.cmd_args[:nostop_if_failure] and @testcase.failure_recorded
      @testcase.output("Testcase failed, skipping Vespa stop")
    else
      if @testcase.dirty_nodeproxies.length > 0
        @testcase.output("Stopping vespa on #{@testcase.dirty_nodeproxies.length} node(s)...")
        stop_http_servers
        stop_base(@testcase.dirty_nodeproxies)
        @stop_hooks.each do |hook|
          hook.call(@testcase.dirty_nodeproxies)
        end
        if (not @testcase.use_shared_configservers)
          stop_configservers(@testcase.dirty_nodeproxies)
        end
        @testcase.dirty_nodeproxies.each_value do |handle|
          fail_unblessed_processes(handle)
          if @testcase.dirty_environment_settings
            Environment.instance.reset_environment(handle)
          end
          if not @testcase.leave_loglevels
            reset_logctl(handle)
            @testcase.output("vespa-logctl reset")
          end
          if not @testcase.keep_tmpdir
            handle.remove_tmp_files
            @testcase.output("Temporary files removed")
          end
          highest_memory_during_test = handle.stop_monitoring
          @testcase.output("Memory monitoring stopped")
          if highest_memory_during_test and highest_memory_during_test > @testcase.max_memory * 1024 * 1024 * 1024
            nodes_exceeded_memory_limit << [handle.short_name, highest_memory_during_test]
          end
        end
      end
      if not @testcase.keep_tmpdir
        FileUtils.remove_dir(@testcase.dirs.tmpdir) if File.exists?(@testcase.dirs.tmpdir)
      else
        @testcase.output("Temporary testdir kept as: #{@testcase.dirs.tmpdir}")
      end
      backup_log(@testcase.dirty_nodeproxies)
    end
    if @testcase.valgrind
      @testcase.dirty_nodeproxies.each_value do |handle|
        save_valgrind_logfiles(handle)
      end
    end
    if @testcase.has_active_sanitizers
      @testcase.dirty_nodeproxies.each_value do |handle|
        save_sanitizer_logfiles(handle)
      end
    end
     #if not nodes_exceeded_memory_limit.empty?
       #raise "Test used too much memory on #{nodes_exceeded_memory_limit.join(', ')}"
     #end
  end

  def fail_unblessed_processes(handle)
    if @testcase.running_in_factory?
      unblessed_processes = handle.get_unblessed_processes
      if not unblessed_processes.empty?
        process_output = ""
        unblessed_processes.each do |pid, command|
         process_output += "#{pid} #{command}\n"
        end
        @testcase.add_failure("The following processes were still running after stopping vespa:\n" + process_output)
        handle.kill_unblessed_processes
      end
    end
  end

  def reset_logctl(handle)
    handle.reset_logctl
  end

  def save_logfile(logfilename)
    if @logserver
      saved_filename = "#{@testcase.dirs.vespalogdir}/#{@logserver.name}-#{File.basename(logfilename)}"
      File.open(saved_filename, "w") do |file|
        @logserver.get_logfile(logfilename) do |buf|
          file.write(buf)
        end
      end
    else
      @testcase.output("No logserver, could not get #{logfilename}")
    end
  end

  def save_qrserver_logfiles(handle)
    handle.list_files(@qrs_logs_dir + '/[a-zA-Z]*.[0-9]*').each do |filename|
      File.open(@testcase.dirs.vespalogdir + "#{handle.short_name}-#{File.basename(filename)}", "w") do |file|
        file.write(handle.readfile(filename))
      end
    end
  end

  def save_valgrind_logfiles(handle)
    handle.list_files(@valgrind_logs_glob).each do |filename|
      File.open(@testcase.dirs.valgrindlogdir + "#{handle.short_name}-#{File.basename(filename)}", "w") do |file|
        file.write(handle.readfile(filename))
      end
    end
  end

  def save_sanitizer_logfiles(handle)
    handle.list_files(@sanitizer_logs_dir + '/[a-zA-Z]*.[0-9]*').each do |filename|
      File.open(@testcase.dirs.sanitizerlogdir + "#{handle.short_name}-#{File.basename(filename)}", "w") do |file|
        file.write(handle.readfile(filename))
      end
    end
  end

  # Runs indexing and subscription cleaning scripts on all nodes used by
  # the testcase.
  def clean
    if @testcase.cmd_args[:nostop]
      @testcase.output("Skipping Vespa clean")
    elsif @testcase.cmd_args[:nostop_if_failure] and @testcase.failure_recorded
      @testcase.output("Testcase failed, skipping Vespa clean")
    else
      @testcase.dirty_nodeproxies.each_value do |handle|
        if !@search.empty?
          handle.clean_indexes
        end
      end

      @storage.each_value do |stg|
        stg.clean
      end
    end
    @testcase.dirty_nodeproxies.each_value do |handle|
      handle.cleanup_services
    end
  end

  def to_s
    string_repr = "=== Vespa Model ===\n"
    i = 0
    @nodeproxies.each do |hostname, proxy|
      string_repr += "node #{i}:\n \t name: #{hostname}\n \t proxy: #{proxy}\n"
      i += 1
    end
    @configservers.each do |cfgserver|
      string_repr += cfgserver.to_s + "\n"
    end
    string_repr += @logserver.to_s + "\n"
    @qrserver.each do |qrs|
      string_repr += qrs.to_s + "\n"
    end
    @storage.each do |name, cluster|
      string_repr += "storage[\"#{name}\"]:\n"
      string_repr += cluster.to_s + "\n"
    end
    @search.each do |name, cluster|
      string_repr += "search[\"#{name}\"]:\n"
      string_repr += cluster.to_s + "\n"
    end
    @container.each do |name, cluster|
       string_repr += "container[\"#{name}\"]:\n"
       string_repr += cluster.to_s + "\n"
    end
    string_repr += "==="
    return string_repr
  end

end
