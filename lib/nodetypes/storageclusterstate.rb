# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class StorageNodeDiskState

  attr_accessor :index, :state, :message

  def initialize(index, state = 'u')
    @index = index
    @state = state
    @message = ''
  end

  def ==(other)
    return index == other.index && state == other.state && message == other.message
  end

  def to_s
    return "    disk." + @index.to_s + ": " + @state.to_s + " (" + message.to_s + ")" 
  end

end

class StorageNodeState

  attr_accessor :type, :index, :state, :message, :diskcount, :capacity, :reliability, :disks

  def initialize(type, index, state = 'u')
    @type = type
    @index = index
    @state = state
    @message = ''
    @capacity = 1.0
    @reliability = 1.0
    @disks = Array.new
  end

  def get_disk_state(index)
    if (index >= @disks.length)
      return StorageNodeDiskState.new(index, 'u')
    end
    return @disks[index]
  end

  def ==(other)
    return type == other.type && index == other.index && state == other.state && message == other.message && capacity == other.capacity && reliability = other.reliability && disks == other.disks
  end

  def disks_not_in_up_state
    @disks.map { |d|
      d.state != 'u' ? d : nil
    }.compact
  end

  def to_s
    retval = "  #{@type}.#{@index}: #{@state} (#{message}) Capacity: #{@capacity}"
    return retval if @disks.empty?

    disks_not_up = disks_not_in_up_state()

    retval << ", disks up: #{@disks.size - disks_not_up.size} of #{@disks.size}"

    return retval if disks_not_up.empty?

    retval << "\n";

    @disks.each { |d| 
      retval << d.to_s + "\n"
    }

    return retval
  end

end

class StorageClusterState

  attr_reader :statestr, :version, :bits, :storage_nodes, :distributor_nodes

  def initialize(testcase, statestr)
    @testcase = testcase
    parse(statestr)
  end

  def parse_state(element, state)
    element.elements.each("states/state") { |s|
      # Only generated states count, since those are the "cluster state"
      if (s.attributes["source"] == "GENERATED")
        state_str = s.attributes["state"]
        if (state_str == "UP")
          state.state = "u"
        elsif (state_str == "DOWN")
          state.state = "d"
        elsif (state_str == "INITIALIZING")
          state.state = "i"
        elsif (state_str == "MAINTENANCE")
          state.state = "m"
        elsif (state_str == "STOPPING")
          state.state = "s"
        elsif (state_str == "RETIRED")
          state.state = "r"
        end
        
        state.message = s.text
        return
      end
    }

    return
  end

  def parse_disks(element, storagenode)
    element.elements.each("partitions/partition") { |p|  
      name = p.attributes["name"]

      if name =~ /disk([0-9]*)/
        disk_index = $1.to_i

        while (storagenode.disks.size < disk_index)
          storagenode.disks.push(StorageNodeDiskState.new(storagenode.disks.size, 'u'))
        end

        state = StorageNodeDiskState.new(disk_index, 'd')
        parse_state(p, state)
        storagenode.disks.push(state)
      end
    }
  end

  def parse_attributes(element, storagenode)
    element.elements.each("attributes/attribute") { |p|  
      name = p.attributes["name"]
      if (name == "capacity") 
        storagenode.capacity = p.text.to_f
      end
    }
  end

  def parse_node(el, index)
      name = el.attributes["name"]

      for i in @storage_nodes.length..(index - 1) do
        @storage_nodes.push(StorageNodeState.new('distributor', i, 'd'))
        @distributor_nodes.push(StorageNodeState.new('storage', i, 'd'))
      end

      if (name == "storage") 
        @storage_nodes[index] = StorageNodeState.new("storage", index)
        parse_state(el, @storage_nodes[index])
        parse_disks(el, @storage_nodes[index])
        parse_attributes(el, @storage_nodes[index])
      elsif (name == "distributor")
        @distributor_nodes[index] = StorageNodeState.new("distributor", index)
        parse_state(el, @distributor_nodes[index])
      end
  end

  def parse_group(element, lastgroup)
    element.elements.each { |el|
      if (el.name == "groups") 
        parse_group(el, nil)
      end

      if (el.name == "group")
        parse_group(el, el.attributes["name"]) 
      end

      if (el.name == "nodes")
        parse_group(el, lastgroup)
      end

      if (el.name == "node")
        parse_node(el, lastgroup.to_i)
      end
    }
  end

  def initializing
    if (@storage_nodes.empty? || @distributor_nodes.empty?)
      return true;
    end
 
    @storage_nodes.each { |n| 
      if (n.state == "i")
        return true
      end
    }

    @distributor_nodes.each { |n| 
      if (n.state == "i")
        return true
      end
    }

    return false
  end

  def ==(other)
    return (@storage_nodes == other.storage_nodes && @distributor_nodes == other.distributor_nodes && version == other.version)
  end

  def parse(statestr)
    #@testcase.output("Parsing cluster state '" + statestr + "'.")
    @statestr = statestr
    global_state = 'u'
    snodes = Array.new
    dnodes = Array.new
    part = 'none'
    version = 0
    bits = 0
    statestr.split(' ').each do |token|
        #@testcase.output("Parsing token '" + token + "'.")
        colon = token.index(':')
        if (colon == nil)
          raise "Invalid token '" + token + "' in cluster state '" +
                statestr + "'."
        end
        key = token.slice(0, colon)
        value = token.slice(colon + 1, token.length - colon - 1)
        #@testcase.output("Parsing key '" + key + "' with value '" +
        #                 value + "'.")
        if (key == 'version')
          version = value.to_i
        end
        if (key == 'bits')
          bits = value.to_i
        end
        if (key == 'cluster')
          global_state = value
          #@testcase.output("Global state is " + global_state)
        end
        if (key == 'distributor')
          part = 'distributor'
          for i in dnodes.length..(value.to_i - 1) do
            dnodes.push(StorageNodeState.new('distributor', i))
            #@testcase.output("Adding distributor " + i.to_s + ". It has " +
            #                 "state " + dnodes[i].state + " to begin with.")
          end
        end
        if (key == 'storage')
          part = 'storage'
          for i in snodes.length..(value.to_i - 1) do
            snodes.push(StorageNodeState.new('storage', i))
            #@testcase.output("Adding storage " + i.to_s + ". It has state " +
            #                 dnodes[i].state + " to begin with.")
          end
        end
        if (key =~ /^\.(\d+)\.s$/)
          #@testcase.output("Found node state of node " + $1.to_s +
          #                 " in part " + part + " being: " + value);
          if (part == 'storage')
            snodes[$1.to_i].state = value
            #@testcase.output("Altering storage " + $1 + " state to " + value)
          else
            dnodes[$1.to_i].state = value
            #@testcase.output("Altering distr. " + $1 + " state to " + value)
          end
        end
        if (key =~ /^\.(\d+)\.c$/)
          #@testcase.output("Found capacity for node " + $1.to_s +
          #                 " in part " + part + " being: " + value);
          if (part == 'storage')
            snodes[$1.to_i].capacity = value.to_i
            #@testcase.output("Altering storage " + $1 + " capacity to " + value)
          else
            dnodes[$1.to_i].capacity = value.to_i
            #@testcase.output("Altering distr. " + $1 + " capacity to " + value)
          end
        end
        if (key =~ /^\.(\d+)\.m$/)
          #@testcase.output("Found message for node " + $1.to_s +
          #                 " in part " + part + " being: " + value);
          if (part == 'storage')
            snodes[$1.to_i].message = value
            #@testcase.output("Altering storage " + $1 + " message to " + value)
          else
            dnodes[$1.to_i].message = value
            #@testcase.output("Altering distr. " + $1 + " message to " + value)
          end
        end
        if (key =~ /^\.(\d+)\.d$/)
          if (part != 'storage')
            raise "Disk count only make sense for storage nodes"
          end
          index = $1.to_i
          for i in 0..(value.to_i - 1) do
            #@testcase.output("Adding disk " + i.to_s + " to storage node " +
            #                 index.to_s)
            snodes[index].disks.push(StorageNodeDiskState.new(i))
          end
        end
        if (key =~ /^\.(\d+)\.d\.(\d+)\.s$/)
            #@testcase.output("Setting disk " + $2 + " of storage node " +
            #                 $1 + " to state " + value)
            snodes[$1.to_i].disks[$2.to_i].state = value
        end
    end
    @global_state = global_state
    @storage_nodes = snodes
    @distributor_nodes = dnodes
    @version = version
    @bits = bits
  end

  def get_global_state
    #@testcase.output("Returning global state '" + @global_state + "'.")
    return @global_state
  end

  def isup(type, index)
    return (get_node_state(type, index).state == "u")
  end

  def get_node_state(type, index)
    if (type == 'storage')
        if (@storage_nodes.length <= index)
            return StorageNodeState.new('storage', index, 'd')
        else
            #@testcase.output("Returning storage " + index.to_s + " state of " +
            #                 @storage_nodes[index].state)
            return @storage_nodes[index]
        end
    else
        if (type != 'distributor')
            raise "Illegal type " + type.to_s
        end
        if (@distributor_nodes.length <= index)
            return StorageNodeState.new('distributor', index, 'd')
        else
            #@testcase.output("Returning distributor " + index.to_s +
            #                 " state of " + @distributor_nodes[index].state)
            return @distributor_nodes[index]
        end
    end
  end

  def to_s
    @statestr
  end

end

class StorageClusterStateV2 < StorageClusterState
  # Generate state from XML from REST.
  def initialize(element)
    @storage_nodes = Array.new
    @distributor_nodes = Array.new
    @bits = 0
    @version = 0

    element.elements.each("cluster") { |cluster|
      cluster.elements.each("groups/group") { |root|
        parse_group(root, nil)

        state = StorageNodeState.new("foo", 0)
        parse_state(root, state)
        @global_state = state.state 

        root.elements.each("attributes/attribute") { |el|
          if (el.attributes.get_attribute("name").to_s == "cluster-state-version")
            @version = el.text.to_i
          end

          if (el.attributes.get_attribute("name").to_s == "distribution-bits")
            @bits = el.text.to_i
          end
        }
      }
    }
#    puts "Parsed from state XML: #{@global_state}, #{@version}, #{@bits}"
  end

  def to_s
    retval = "Cluster(State " + @global_state.to_s + " Version: " + @version.to_s + " Bits: " + @bits.to_s + "\n"
    
    @storage_nodes.each { |s| 
      retval = retval + s.to_s + "\n" 
    }

    @distributor_nodes.each { |s|
      retval = retval + s.to_s + "\n" 
    }

    retval = retval + ")"

    return retval
  end
end
