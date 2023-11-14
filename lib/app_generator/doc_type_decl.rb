# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class DocumentTypeDecl
  attr_reader :type, :selection
  def initialize(type, selection)
    @type = type
    @selection = selection
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("document", :type => @type, :selection => @selection).close_tag.
      to_s
  end
end
