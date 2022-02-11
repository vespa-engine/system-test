# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Qrservers
  include ChainedSetter

  attr_reader :default_qrserver
  attr_accessor :allow_none

  chained_setter :jvm_options
  chained_forward :qrservers, :qrserver => :push
  chained_forward :config, :config => :add

  def default_jvm_options= args
    qrserver_list.each do |qrs|
      qrs.jvm_options(args) unless qrs._jvm_options
    end
  end

  def initialize
    @qrservers = []
    @default_qrserver = QrserverCluster.new
    @config = ConfigOverrides.new
    @jvm_options = nil
    @allow_none = false
  end

  def qrserver_list
    @qrservers.empty? ? [@default_qrserver] : @qrservers
  end

  def implicit_qrserver?
    @qrservers.empty? && !allow_none
  end

  def to_xml(indent)
    if @allow_none and @qrservers.empty? then
      return ""
    end
    XmlHelper.new(indent).
      tag("qrservers", :jvm_options => @jvm_options).
      to_xml(@config).
      to_xml(@processing).
      to_xml(qrserver_list).to_s
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
