# Copyright Vespa.ai. All rights reserved.
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
