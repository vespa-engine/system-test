# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Hits

  def initialize(hits_in)
    @hit = []
    hits_in.each do |fields|
      h = Hit.new
      fields.each do |k, v|
        h.add_field(k, v)
      end
      @hit.push(h)
    end
  end

  def hit
    @hit
  end

  def setcomparablefields(fieldnamearray)
    @hit.each {|h| h.setcomparablefields(fieldnamearray)}
  end

  def to_s
    stringval = ""
    @hit.each do |h|
      stringval += h.to_s + "\n"
    end
    stringval
  end

  def ==(other)
    if other.class == self.class
      return @hit == other.hit
    elsif other.class == @hit.class
      return @hit == other
    else
      return false
    end
  end

end

