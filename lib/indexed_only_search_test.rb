# Copyright Vespa.ai. All rights reserved.
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
