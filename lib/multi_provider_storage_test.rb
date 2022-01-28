# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class MultiProviderStorageTest < VdsTest

  def param_setup(params)
    @params = params
    setup
  end

  def deploy_app(app, deploy_params = {})
    app.provider(@params[:provider]) if @params != nil
    super(app, deploy_params)
  end

  def self.testparameters
    { "PROTON" => { :provider => "PROTON" },
      "DUMMY" => { :provider => "DUMMY" } }
  end

end
