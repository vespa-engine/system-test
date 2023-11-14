# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Bundle
  attr_reader :sourcedir, :name, :params
  attr_accessor :version, :artifact_id, :group_id, :extra_build_plugin_xml, :bundle_plugin_config

  def initialize(sourcedir, name, params={})
    raise ArgumentError.new("sourcedir cannot be nil") unless sourcedir

    @sourcedir = sourcedir
    # Not to be confused with params[:name], ref TODO in vespa_model.rb...
    @name = name
    @artifact_id = params.fetch(:artifact_id, name)
    @version = params.fetch(:version, "1.0.0")
    @group_id = params.fetch(:group_id, "com.yahoo.vespa")
    @final_name = params.fetch(:final_name, nil)
    # params[:name] is used for unique file names for bundles
    # params[:scope] is used to determine the scope of this artifact when
    #     building other bundles
    @params = params
    @extra_build_plugin_xml = params.fetch(:extra_build_plugin_xml, "")
    @bundle_plugin_config = params.fetch(:bundle_plugin_config, "")
  end

  def generate_final_name
    return @final_name if @final_name
    final_version = ""
    final_version = "-#{@version}" if @version
    return "#{name}#{final_version}-deploy"
  end
end
