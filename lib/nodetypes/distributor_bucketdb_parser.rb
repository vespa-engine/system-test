# Copyright Vespa.ai. All rights reserved.

class DistributorBucketDBParser

  # Convert distributor bucket db status page /distributor?page=buckets
  # into a hash of information
  def parse(status_page)
    result = Hash.new
    status_page.split(/\n/).each { |line|
      if (line !~ /^\s*BucketId\(0x([0-9a-f]+)\)\s*:\s*(.*)$/)
        next
      end
      result[$1] = parseNodeArray($2)
    }
    return result
  end

  # Helper function to parse
  def parseNodeArray(node_spec)
    nodes = Hash.new
    node_spec.split(/\), node\(/).each { |node|
        if (node =~ /^\[node\((.*)$/)
          node = $1
        elsif (node =~ /^(.*)\)\]<br>$/)
          node = $1;
        end
        node =~ /^idx=(\d+),(.*)$/ or die "Failed to parse node info #{node}"
        nodes[$1.to_i] = parseNodeInfo($2)
    }
    return nodes
  end

  # Helper function to parse
  def parseNodeInfo(node_data)
    info = Hash.new
    #puts node_data
    node_data.split(/,/).each { |data|
        data =~ /^(.*?)=(.*)$/ or die "Invalid data #{data} seen"
        parseData(info, $1, $2)
    }
    return info
  end

  # Helper function to parse
  def parseData(result, type, data)
    if (type == "crc")
      if (data =~ /^0x(.*)$/)
        data = $1
      end
    elsif (type == "docs")
      data =~ /^(\d+)\/(\d+)$/ or die "Invalid doc entry #{data}"
      result["unique_docs"] = $1.to_i
      result["meta_entries"] = $2.to_i
      return
    elsif (type == "bytes")
      data =~ /^(\d+)\/(\d+)$/ or die "Invalid bytes entry #{data}"
      result["unique_docs_size"] = $1.to_i
      result["utilized_file_size"] = $2.to_i
      return
    elsif (type == "trusted" || type == "active" || type == "ready")
      result[type] = (data =~ /^true$/i ? true : false)
      return
    end
    result[type] = data
  end

  class Matcher
    def countBucket(bucket)
      return true
    end
    def countNode(bucket, node)
      return true
    end
    def countProperty(bucket, node, property)
      return true
    end
    def countPropertyValue(bucket, node, name, val)
      return true
    end
  end

  def count_instances_matching(bucketdb_hash, matcher)
    count = 0
    bucketdb_hash.each { |bucket, nodelist|
      if (!matcher.countBucket(bucket))
        next
      end
      nodelist.each { |node, properties|
        if (!matcher.countNode(bucket, node))
          next
        end
        properties.each { |name, val|
          if (!matcher.countProperty(bucket, node, name))
            next
          end
          if (matcher.countPropertyValue(bucket, node, name, val))
            count += 1
          end
        }
      }
    }
    return count
  end
end
