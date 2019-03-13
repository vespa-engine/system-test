# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Dispatch
  include ChainedSetter

  chained_forward :groups, :group => :push
  chained_setter :num_dispatch_groups

  def initialize()
    @groups = []
    @num_dispatch_groups = 0
  end

  def to_xml(indent)
    helper = XmlHelper.new(indent)
    if !@groups.empty? || @num_dispatch_groups > 0
      helper.tag("dispatch")
      if !@groups.empty?
        helper.to_xml(@groups)
      elsif @num_dispatch_groups > 0
        helper.tag("num-dispatch-groups").content(@num_dispatch_groups).close_tag
      end
      helper.close_tag
    end
  end

end

class DispatchGroup

  def initialize(nodes)
    @nodes = nodes
  end

  def to_xml(indent)
    XmlHelper.new(indent).tag("group").
      list_do(@nodes) { |helper, node|
      helper.tag("node", :"distribution-key" => node).close_tag}.to_s
  end

end
