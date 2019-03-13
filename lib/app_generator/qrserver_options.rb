# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Cache
  include ChainedSetter

  chained_setter :size

  def initialize(name = nil)
    @cluster_name = name
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("cacheoptions", :cluster => @cluster_name).
        tag("size").content(@size).to_s
  end
end

class QrserverOptions
  include ChainedSetter

  chained_forward :caches, :cache => :push

  def initialize
    @caches = []
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("qrserveroptions").
        to_xml(@caches).
          to_s
  end
end
