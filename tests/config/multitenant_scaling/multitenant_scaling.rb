# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'json'
require 'app_generator/search_app'

class MultiTenantScaling < ConfigTest

  def setup
    super
    set_owner("musum")
    @node = @vespa.nodeproxies.first[1]
    @hostname = @vespa.nodeproxies.first[0]
    #@httpport = 19071
    @tenants = Array.new
  end

  def timeout_seconds
    10*60 * 60
  end

  def NOTYET_test_many_apps
    @node.start_configserver
    delete_tenant_and_its_applications(@hostname, "default")
    heapstart = @node.memusage_rss(@node.get_configserver_pid)
    puts "CONFIGSERVER HEAP START: #{heapstart}"
    #for i in 0..0 # getting about HEAP DELTA: 353 928 000,   35MB per model
    for i in 0..9 # getting about HEAP DELTA:  705 108 000,    7MB per model
      tenant = "t#{i}"
      @tenants << tenant
      create_tenant_and_wait(tenant, @node)
      deploy_10_apps(tenant)
    end
    puts "Waiting for #{@tenants}"
    assert(wait_for_tenants(@node, @tenants))
    heapend = @node.memusage_rss(@node.get_configserver_pid)
    puts "CONFIGSERVER HEAP END: #{heapend}"
    puts "HEAP DELTA: #{heapend - heapstart}"
  end

  def NOTYET_test_many_tiny_apps
    @node.start_configserver
    delete_tenant_and_its_applications(@hostname, "default")
    heapstart = @node.memusage_rss(@node.get_configserver_pid)
    puts "CONFIGSERVER HEAP START: #{heapstart}"
    #for i in 0..999
    for i in 0..0 # getting about HEAP DELTA: 348 900 000, 34.0MB per model
    #for i in 0..2 # getting about HEAP DELTA: 433 680 000,  14.5MB per model
    #for i in 0..4  # getting about HEAP DELTA: 489 024 000 , 9.8MB per model
    #for i in 0..9 # getting about HEAP DELTA: 624 256 000 ,  6.2MB per model
    #for i in 0..99 # getting about HEAP DELTA:  ,  MB per model
      tenant = "t#{i}"
      @tenants << tenant
      create_tenant_and_wait(tenant, @node)
      deploy_10_tiny_apps(tenant)
    end
    puts "Waiting for #{@tenants}"
    assert(wait_for_tenants(@node, @tenants))
    heapend = @node.memusage_rss(@node.get_configserver_pid)
    puts "CONFIGSERVER HEAP END: #{heapend}"
    puts "HEAP DELTA: #{heapend - heapstart}"
  end

  def deploy_10_tiny_apps(tenant)
    for i in 0..9
      app = "a-tiny-#{i}"
      deploy("#{CONFIG_DEPLOY_APP}/app_a", nil, :tenant => tenant, :application_name => app, :skip_create_tenant =>true, :skip_configserver_start => true)
    end
  end

  def deploy_10_apps(tenant)
    for i in 0..9
      app = "a#{i}"
      dir = "#{selfdir}../../search/logicalbold/"
      deploy_app(SearchApp.new.sd("#{dir}/common-different-name-to-doctype.sd").
                     cluster(SearchCluster.new("logical").
                             sd("#{dir}/book.sd").
                             sd("#{dir}/music.sd")).
                     cluster(SearchCluster.new("video").
                             sd("#{dir}/video.sd")),
                 :tenant => tenant, :application_name => app, :skip_create_tenant =>true, :skip_configserver_start => true)
      #deploy("#{CONFIG_DEPLOY_APP}/app_a", nil, :tenant => tenant, :application_name => app, :skip_create_tenant =>true, :skip_configserver_start => true)
    end
  end

  def teardown
    @tenants.each { |tenant|
      # TODO pull up?
      delete_tenant_and_its_applications(@hostname, tenant)
    }
    @node.stop_configserver
    stop
  end

end
