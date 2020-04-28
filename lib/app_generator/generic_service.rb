# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/app'

class GenericServiceNode < NodeBase

  def initialize(host_alias)
    @host_alias = host_alias
  end

  def to_xml(indent)
    XmlHelper.new(indent).tag('node', :hostalias => @host_alias).to_s
  end 

end

class GenericService

  def initialize(name, command)
    @name = name
    @command = command
    @nodes = []
  end

  def node(host_alias)
    @nodes.push(GenericServiceNode.new(host_alias))
    self
  end

  def node_list
    return @nodes unless @nodes.empty?
    return [GenericServiceNode.new('node1')]
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag('service', :name => @name, :command => @command, :version => '1.0').
        to_xml(node_list).to_s # Note: no wrapping <nodes> tag for some reason.
  end

end

class GenericServices
  include ChainedSetter

  chained_forward :services, :service => :push

  def initialize
    @services = []
  end

  def empty?
    @services.empty?
  end

  def to_xml(indent)
    return '' if @services.empty?
    XmlHelper.new(indent).
      to_xml(@services).to_s
  end

end

