# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class BucketCopy
  attr_reader :crc, :docs, :metacount, :bytes, :usedfilesize, :ready, :active
  def initialize(crc, docs, metacount, bytes, usedfilesize, ready, active)
    @crc = crc
    @docs = docs
    @metacount = metacount
    @bytes = bytes
    @usedfilesize = usedfilesize
    @ready = ready
    @active = active
  end
end

class StorageBucketCopy < BucketCopy
  attr_reader :disk, :orphaned
  def initialize(crc, docs, metacount, bytes, usedfilesize, disk, ready, active)
    super(crc, docs, metacount, bytes, usedfilesize, ready, active)
    @disk = disk
    @orphaned = true # Explicitly unset when seen on a distributor
  end

  def mark_as_seen
    @orphaned = false
  end
  def to_s
    return ("StorageBucketCopy(crc=0x#{crc.to_s(16)},docs=#{docs}," +
            "metacount=#{metacount},bytes=#{bytes},usedfilesize="+
            "#{usedfilesize},ready=#{ready},active=#{active}," +
            "disk=#{disk},orphaned=#{orphaned})")
  end
end

class DistributorBucketCopy < BucketCopy
  attr_reader :idx, :trusted, :active
  def initialize(idx, crc, docs, metacount, bytes, usedfilesize, trusted, ready, active)
    super(crc, docs, metacount, bytes, usedfilesize, ready, active)
    @idx = idx
    @trusted = trusted
  end

  def to_s
    return ("DistributorBucketCopy(idx=#{idx},crc=0x#{crc.to_s(16)}," +
            "docs=#{docs},metacount=#{metacount},bytes=#{bytes},usedfilesize="+
            "#{usedfilesize},trusted=#{trusted},ready=#{ready}," +
            "active=#{active})")
  end
end

