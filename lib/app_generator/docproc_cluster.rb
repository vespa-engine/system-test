# Copyright Vespa.ai. All rights reserved.
class DocumentProcessor < Processor
  def initialize(id, after=nil, before=nil, klass=nil, bundle=nil)
    super(id, after, before, klass, bundle)
  end

  def to_xml(indent="")
    return dump_xml(indent, "documentprocessor")
  end
end


