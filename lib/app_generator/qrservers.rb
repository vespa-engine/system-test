# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Qrservers
  include ChainedSetter

  attr_reader :default_qrserver
  attr_accessor :allow_none

  chained_setter :jvmargs
  chained_forward :qrservers, :qrserver => :push
  chained_forward :config, :config => :add

  def default_jvmargs= args
    qrserver_list.each do |qrs|
      qrs.jvmargs(args) unless qrs._jvmargs
    end
  end

  def initialize
    @qrservers = []
    @default_qrserver = QrserverCluster.new
    @config = ConfigOverrides.new
    @jvmargs = nil
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
      tag("qrservers", :jvmargs => @jvmargs).
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
