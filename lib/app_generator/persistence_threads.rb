# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
