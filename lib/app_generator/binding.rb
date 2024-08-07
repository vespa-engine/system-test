# Copyright Vespa.ai. All rights reserved.
class JDiscBinding
  def initialize(binding)
    @binding = binding
  end

  def to_xml(indent)
    XmlHelper.new(indent).tag("binding").content(@binding).to_s
  end
end
