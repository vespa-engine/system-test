# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

  class AdminServer < NodeBase
    tag "adminserver"

    def initialize(hostalias = 'node1')
      super(:hostalias => hostalias)
    end
  end

class Admin
  include ChainedSetter

  chained_setter :adminserver
  chained_setter :metrics
  chained_forward :config, :config => :add

  class LogServer < NodeBase
    tag "logserver"

    def initialize(hostalias)
      super(:hostalias => hostalias)
    end
  end

  class ConfigServer < SimpleNode
    tag "configserver"
  end

  class Slobrok < SimpleNode
    tag "slobrok"
  end

  class ClusterController < SimpleNode
    tag "cluster-controller"
  end

  class ClusterControllers < SimpleNode
      tag "cluster-controllers"
  end

  def initialize
    @config = ConfigOverrides.new
    @configservers = []
    @monitoring = nil
    @metrics = nil
    @slobroks = []
    @logservers = []
    @clustercontrollers = nil
    @adminserver = AdminServer.new
  end

  def configserver(hostalias)
    @configservers.push(ConfigServer.new(hostalias))
  end

  class Monitoring
    def initialize(systemname, interval)
      @systemname = systemname
      @interval = interval
    end

    def to_xml(indent)
      XmlHelper.new(indent).
        tag("monitoring", :systemname => @systemname, :interval => @interval).to_s
    end
  end

  def monitoring(systemname, interval)
    @monitoring = Monitoring.new(systemname, interval)
  end

  def slobrok(hostalias)
    @slobroks.push(Slobrok.new(hostalias))
  end

  def logserver(hostalias)
    @logservers.push(LogServer.new(hostalias))
  end

  def clustercontroller(hostalias)
    if @clustercontrollers == nil
      clustercontrollers(false)
    end
    ctrl = ClusterController.new(hostalias)
    @clustercontrollers.add(ctrl)
    self
  end

  def clustercontrollers(standalone)
    @clustercontrollers = ClusterControllers.new(standalone)
    self
  end

  class ClusterControllers
    def initialize(standalone)
      @standalone = standalone
      @clustercontrollers = []
    end

    def add(clustercontroller)
      @clustercontrollers.push(clustercontroller)
    end

    def to_xml(indent)
      if (@standalone) then
        XmlHelper.new(indent).tag("cluster-controllers", :"standalone-zookeeper" => @standalone).to_xml(@clustercontrollers).close_tag.to_s
      else
        XmlHelper.new(indent).tag("cluster-controllers").to_xml(@clustercontrollers).close_tag.to_s
      end
    end
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("admin", :version => "2.0").
        to_xml(@config).
        to_xml(@adminserver).
        tag("configservers").to_xml(@configservers).close_tag.
        tag("slobroks").to_xml(@slobroks).close_tag.
        to_xml(@logservers).
        to_xml(@monitoring).
        to_xml(@clustercontrollers).
        to_xml(@metrics).to_s
  end
end
