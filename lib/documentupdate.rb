# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'json'
class Update
  attr_reader :operation, :fieldname, :value_type, :params

  def initialize(op, fieldname, value_type = :single)
    @operation = op
    @fieldname = fieldname
    @value_type = value_type
    @params = Array.new

    validops = ["assign", "add", "remove"]
    if validops.index(@operation) == nil
      raise @operation + " is an invalid operation"
    end

  end

  def params
    @params
  end

  def to_s
    "Update: " + @operation.inspect + " field:" + @fieldname.inspect
  end

  def to_xml
    res = "  <" + @operation + " field=\"" + @fieldname + "\">"
    if @value_type != :array
      res += @params.first.to_s + "</" + @operation + ">\n"
    else
      if @params.size == 0
        res += "</" + @operation + ">\n"
      else
        res += "\n"
        @params.each { | val |
          if val.class == Array
            if val.size == 2
              # val[0] is value
              # val[1] is weight
              res += "    <item weight=\"" + val[1].to_s + "\">" + val[0].to_s + "</item>\n"
            else
              raise "ERROR: Bug in array values"
            end
          else
            res += "    <item>" + val.to_s + "</item>\n"
          end
        }
        res += "  </" + @operation + ">\n"
      end
    end
  end

end


class SimpleAlterUpdate

  attr_reader :value_type, :fieldname, :operation, :params

  def initialize(operation, fieldname, number, key = nil)
    @operation = operation
    @fieldname = fieldname
    @number = number
    @key = key
    @value_type == :single
    @params = [number]
  end

  def to_xml
    res = "  <" + @operation + " field=\"" + @fieldname + "\" by=\"" + @number.to_s + "\""
    if @key == nil
      res += "/>\n"
    else
      res += ">\n"
      res += "    <key>" + @key.to_s + "</key>\n"
      res += "  </" + @operation + ">\n"
    end
    res
  end
end


class DocumentUpdate
  attr_reader :documentid, :documenttype

  def initialize(documenttype, documentid)
    @documenttype = documenttype
    @documentid = documentid
    @updateops = Array.new # Array of Update elements
  end

  def <=>(other)
    return @documentid<=>other.documentid
  end

  # "values" is an array of params or a single value to the specified "operation" on the specified "fieldname" field
  def addOperation(operation, fieldname, values)
    if values.class == Array
      up = Update.new(operation, fieldname, :array)
      values.each { | value |
        up.params.push(value)
      }
    elsif values.class == Hash
      up = Update.new(operation, fieldname, :hash)
      up.params.push(values)
    else
      up = Update.new(operation, fieldname, :single)
      up.params.push(values)
    end
    @updateops.push(up)
  end

  def addSimpleAlterOperation(operation, fieldname, number, key = nil)
    alter = SimpleAlterUpdate.new(operation, fieldname, number, key)
    @updateops.push(alter)
  end

  def to_xml
    ret = "<update documenttype=\"" + @documenttype + "\" documentid=\"" + @documentid + "\">\n"

    if @updateops.size() > 0
      @updateops.each { |value|
         ret += value.to_xml
      }
    end

    ret += "</update>"
    ret
  end

  def write_xml(f)
    f.write(to_xml)
  end

  def fields_to_json
    JSON.dump({"fields" => fields})
  end

  def to_json(operation = :update, in_array = false)
    JSON.dump({"update" => @documentid, "fields" => fields})
  end

  def fields
    fields = {}
    @updateops.each do |u|
      if u.value_type == :array
        fields[u.fieldname] = { u.operation => u.params }
      else
        fields[u.fieldname] = { u.operation => u.params[0] }
      end
    end
    fields
  end

end
