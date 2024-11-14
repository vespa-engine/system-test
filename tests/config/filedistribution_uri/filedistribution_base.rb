# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'app_generator/container_app'

module FileDistributionBase

  def deploy(params)
    deploy_app(create_app(), params)
  end

  def create_app
    ContainerApp.new.
      container(Container.new.
                handler(Handler.new("com.yahoo.vespatest.VersionHandler").
                        bundle("com.yahoo.vespatest.ExtraHitSearcher").
                        binding("http://*/Version")))
  end

end
