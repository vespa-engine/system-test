# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class StreamingSearchTest < SearchTest

  def start(*params)
    super(*params)
    @query_counter = 0
  end

  def param_setup(params)
    @params = params
    setup
  end

  def deploy_app(app, deploy_params = {})
    app.search_type(@params[:search_type]) if @params != nil
    # Override distribution bits to ensure no whole-corpus streaming
    # searches have to visit 64k buckets, but only 256.
    # If there is someone who knows how to do this in a more 'app_generator' way, feel free.
    app.config(ConfigOverride.new('vespa.config.content.fleetcontroller').
               add('ideal_distribution_bits', 8))
    app.config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
               add('minsplitcount', 8))
    super(app, deploy_params)
  end

  def self.testparameters
    { "STREAMING" => { :search_type => "STREAMING" } }
  end

  def apply_timeout_multiplier(params, mult)
    query = params[0]
    # Timeout gets pre-baked into the query string by the framework instead of being a parameter. Not beautiful.
    params[0] = query.gsub(/&timeout=(\d+)/) { |s| "&timeout=#{$1.to_i * mult}" }
  end

  # Wrapping of `search_base` to help avoid initial query timeout issues due to warm-up.
  def search_base(*params)
    apply_timeout_multiplier(params, 6) if @query_counter == 0
    result = super(*params)
    @query_counter += 1
    result
  end

end
