# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class DocProcs
  include ChainedSetter

  chained_forward :clusters, :cluster => :push

  def initialize
    @clusters = []
  end

  def empty?
    @clusters.empty?
  end

  def set_baseports(baseport = 5000)
    port = baseport
    @clusters.each { |cluster|
      cluster.baseport(port)
      port += 10
    }
  end

  def to_xml(indent)
    return '' if @clusters.empty?
    XmlHelper.new(indent).
      tag("docproc", :version => "3.0").
        to_xml(@clusters).to_s
  end

end
