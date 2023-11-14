# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Hits

  def initialize(hits_in)
    @hits = []
    hits_in.each do |fields|
      h = Hit.new
      fields.each do |k, v|
        h.add_field(k, v)
      end
      @hits.push(h)
    end
  end

  def hits
    @hits
  end

  def setcomparablefields(fieldnamearray)
    @hits.each {|h| h.setcomparablefields(fieldnamearray)}
  end

  def to_s
    stringval = ""
    @hits.each do |h|
      stringval += h.to_s + "\n"
    end
    stringval
  end

  def ==(other)
    if other.class == self.class
      return @hits == other.hits
    elsif other.class == @hits.class
      return @hits == other
    else
      return false
    end
  end

end

