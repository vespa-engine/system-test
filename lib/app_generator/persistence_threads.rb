# Copyright Vespa.ai. All rights reserved.

# Element under content/tuning
class PersistenceThreads

  def initialize(count)
    @count = count
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("persistence-threads", {"count" => @count}).to_s
  end

end
