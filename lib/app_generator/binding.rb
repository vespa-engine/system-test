# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class JDiscBinding
  def initialize(binding)
    @binding = binding
  end

  def to_xml(indent)
    XmlHelper.new(indent).tag("binding").content(@binding).to_s
  end
end
