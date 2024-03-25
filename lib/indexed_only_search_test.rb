# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class IndexedOnlySearchTest < SearchTest

  def param_setup(params)
    @params = params
    setup
  end

  def deploy_app(app, deploy_params = {})
    app.search_type(@params[:search_type]) if @params != nil
    super(app, deploy_params)
  end

  def self.testparameters
    { "INDEXED" => { :search_type => "INDEXED" } }
  end

end
