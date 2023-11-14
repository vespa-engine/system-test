# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'

class SimpleDocument < Document
  attr_accessor :lastmodified
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

  alias :to_s :to_xml
  alias :inspect :to_xml
  alias :attributes :fields
end
