# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Qrservers
  include ChainedSetter

  attr_reader :default_qrserver
  attr_accessor :allow_none

  chained_setter :jvmoptions
  chained_forward :qrservers, :qrserver => :push
  chained_forward :config, :config => :add

  def default_jvm_options= args
    qrserver_list.each do |qrs|
      qrs.jvmoptions(args) unless qrs._jvm_options
    end
  end

  def initialize
    @qrservers = []
    @default_qrserver = QrserverCluster.new
    @config = ConfigOverrides.new
    @jvmoptions = nil
    @allow_none = false
  end

  def qrserver_list
    @qrservers.empty? ? [@default_qrserver] : @qrservers
  end

  def implicit_qrserver?
    @qrservers.empty? && !allow_none
  end

  def to_container_xml(indent)
    if @allow_none and @qrservers.empty? then
      return ""
    end
    XmlHelper.new(indent).
      to_xml(@config).
      to_xml(@processing).
      to_xml(qrserver_list, :to_container_xml).to_s
  end


end
