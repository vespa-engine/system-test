# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'app_generator/node_base'
require 'app_generator/chained_setter'
require 'app_generator/admin'
require 'app_generator/binding'
require 'app_generator/clients'
require 'app_generator/config_overrides'
require 'app_generator/container'
require 'app_generator/content'
require 'app_generator/docproc_cluster'
require 'app_generator/docprocs'
require 'app_generator/doc_type_decl'
require 'app_generator/feeder_options'
require 'app_generator/fleet_controller'
require 'app_generator/metrics'
require 'app_generator/node_group'
require 'app_generator/node_group_distribution'
require 'app_generator/qrserver_cluster'
require 'app_generator/qrservers'
require 'app_generator/routing_table'
require 'app_generator/processing'
require 'app_generator/sd_file'
require 'app_generator/search_chains'
require 'app_generator/search_cluster'
require 'app_generator/storage_cluster'
require 'app_generator/xml_helper'
require 'app_generator/persistence_threads'
require 'app_generator/validation_overrides'
require 'app_generator/http'
require 'app_generator/resource_limits'

# App generator.

# The app generator builds an application package for use by
# TestBase's deploy_app() method. The main function of the app
# generator is to create a services.xml file, but it also holds
# pointers to other files and directories used for setting up an
# application, such as schemas.

# See test/test.rb for examples of use.

# An app is set up through a chain of method calls, corresponding
# roughly to the xml elements of services.xml. The exact method
# signatures can be found in the source file, usually defined as
# either a "chained_setter", or "chained_forward".

# A chained_setter is a method that sets a variable, usually with the
# same name as the setter function. As the code in class App below
# illustrates, most setters have the same name.

# A chained_forward statement specifies an object to forward methods
# to, and then a map of method names to be generated and which methods
# they will point to. E.g. App.sd is forwarded to @content.sd

# The largest example at the time of writing is found in the
# search/generic_config test.

class App
  include ChainedSetter

  chained_setter :rules_dir
  chained_setter :components_dir
  chained_setter :search_dir
  chained_setter :num_hosts

  chained_forward :validation_overrides, :validation_override => :validation_override
  chained_forward :rank_files, :rank_expression_file => :push
  chained_forward :cfg_overrides, :config => :add
  chained_forward :content,
                  :qrservers => :qrservers,
                  :storage => :storage,
                  :search => :search,
                  :sd => :sd
  chained_forward "content._qrservers", :qrserver => :qrserver
  chained_forward "content._qrservers.default_qrserver",
                  :search_chain => :search_chain,
                  :search_chains_config => :search_chains_config,
                  :renderer => :renderer,
                  :handler => :handler,
                  :filter => :filter,
                  :processing => :processing
  chained_forward :routing, :routingtable => :table
  chained_forward :admin,
                  :configserver => :configserver,
                  :slobrok => :slobrok,
                  :clustercontroller => :clustercontroller,
                  :logserver => :logserver,
                  :monitoring => :monitoring,
                  :admin_metrics => :metrics
  chained_forward :docprocs, :docproc => :cluster
  chained_forward :clients,
                  :feeder_options => :feeder_options,
                  :load_type => :load_type

  def initialize
    @rank_files = []
    @rules_dir = nil
    @components_dir = nil
    @search_dir = nil
    @num_hosts = 1
    @cfg_overrides = ConfigOverrides.new
    @routing = Routing.new
    @content = Content.new
    @docprocs = DocProcs.new
    @admin = Admin.new
    @clients = Clients.new
    @containers = Containers.new
    @validation_overrides = ValidationOverrides.new
    @legacy_overrides = {}
  end

  def enable_document_api(feeder_options=nil)
    @containers.add(Container.new('doc-api').
                      documentapi(ContainerDocumentApi.new.
                                    feeder_options(feeder_options)).
                      http(Http.new.server(Server.new('default', 19020))))
    return self
  end

  def legacy_override(key, value)
    @legacy_overrides[key] = value
    return self
  end

  def sd_files
    extract_file_names(@content.sd_files)
  end

  def extract_file_names(sd_files)
    sd_files ? (sd_files.map { |sd_file| sd_file.file_name }) : nil
  end

  def container(new_container)
    @containers.add(new_container)
    @content._qrservers().allow_none  = true
    return self
  end

  def admin(admin)
    @admin = admin
    return self
  end

  def deploy_params
    { :rules_dir => @rules_dir,
      :components_dir => @components_dir,
      :search_dir => @search_dir,
      :rank_expression_files => @rank_files,
      :sd_files => extract_file_names(@content.all_sd_files),
      :num_hosts => @num_hosts }
  end

  def header
    "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n" +
      "<services version=\"1.0\">\n"
  end

  def footer
    "</services>\n"
  end

  def legacy_overrides_xml
    return "" if @legacy_overrides.empty?
    res = "  <legacy>\n"
    @legacy_overrides.each {|k,v| res << "  <#{k}>#{v}</#{k}>\n"}
    res <<= "  </legacy>\n"
    return res
  end

  def newline(s)
    s.empty? ? s : s + "\n"
  end

  def services_xml
    if @content._qrservers.implicit_qrserver? && @docprocs.empty?
      # Avoid having a separate docproc cluster if no docprocs
      @content._qrservers.qrserver_list[0].add_default_docproc
      @content.set_indexing_cluster(@content._qrservers.qrserver_list[0].name)
    end
    if @content._qrservers.implicit_qrserver? && !@docprocs.empty?
      @docprocs.set_baseports
    end
    services = header
    services << legacy_overrides_xml
    services << newline(@admin.to_xml("  "))
    services << newline(@routing.to_xml("  "))
    services << newline(@cfg_overrides ? @cfg_overrides.to_xml("  ") : '')
    services << newline(@docprocs.to_xml("  "))
    services << newline(@content.to_xml("  "))
    services << newline(@containers.to_xml("  "))
    services << @clients.to_xml("  ")
    services << footer
  end

  def hosts_xml
    nil
  end

  # Returns a validation-overrides.xml for this application package containing a single override
  # with the given id which is valid through tomorrow
  def validation_overrides_xml    
    @validation_overrides.to_xml()
  end

  def provider(value)
    if value == "PROTON"
      @content.provider(:proton)
    elsif value == "DUMMY"
      @content.provider(:dummy)
    else
      raise "Unknown provider '#{value}' specified"
    end
    self
  end

end
