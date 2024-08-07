# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

# Test class for providers that survive a restart.
class PersistentProviderTest < VdsTest

  def param_setup(params)
    @params = params
    setup
  end

  def deploy_app(app, deploy_params = {})
    app.provider(@params[:provider]) if @params != nil
    super(app, deploy_params)
  end

  def self.testparameters
    { "PROTON" => { :provider => "PROTON" } }
  end

end
