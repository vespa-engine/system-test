# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class IndexedStreamingSearchTest < SearchTest

  def param_setup(params)
    @params = params
    setup
  end

  def deploy_app(app, deploy_params = {})
    app.search_type(@params[:search_type]) if @params != nil
    # Override distribution bits to ensure no whole-corpus streaming
    # searches have to visit 64k buckets, but only 256.
    app.config(ConfigOverride.new('vespa.config.content.fleetcontroller').
               add('ideal_distribution_bits', 8))
    app.config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
               add('minsplitcount', 8))

    super(app, deploy_params)
  end

  def is_streaming
    @params[:search_type] == "STREAMING"
  end

  def add_streaming_selection_query_parameter
    is_streaming
  end

  def self.testparameters
    { "STREAMING" => { :search_type => "STREAMING" },
      "ELASTIC" => { :search_type => "ELASTIC" } }
  end

end
