# Copyright Vespa.ai. All rights reserved.
require 'document'

class SimpleDocument < Document
  attr_accessor :removetime
  attr_accessor :isremove
  attr_reader :xml

  def initialize(documenttype, documentid, buffer)
    super(documenttype, documentid)
    @xml = buffer
    @isremove = false
  end

  def isRemoved
    return @isremove
  end

  def to_xml
    if !isRemoved
      super
    else
      to_rm_xml
    end
  end

  alias :to_s :to_json
  alias :inspect :to_json
  alias :attributes :fields
end
