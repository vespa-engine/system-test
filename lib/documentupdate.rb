# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'json'
class Update
  attr_reader :operation, :fieldname, :value_type, :params

  def initialize(op, fieldname, value_type = :single)
    @operation = op
    @fieldname = fieldname
    @value_type = value_type
    @params = Array.new

    validops = ["assign", "add", "remove", "decrement", "divide", "increment", "multiply"]
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

  # 'values' is:
  # * a single value
  # * an array of params
  # * hash (for weighted sets and structs)
  # to be used for the 'operation' on the 'fieldname' field
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

  def fields_to_json
    JSON.dump({"fields" => fields})
  end

  def to_json(operation = :update, in_array = false)
    JSON.dump({"update" => @documentid, "fields" => fields})
  end

  def fields
    arithmetic_operations = ['decrement', 'divide', 'increment', 'multiply']
    fields = {}
    @updateops.each do |u|
      if u.value_type == :array
        fields[u.fieldname] = { u.operation => u.params }
      else
        values = u.params[0]
        if values.class == Hash and arithmetic_operations.include? u.operation
          fields[u.fieldname] = { 'match' => { 'element' => values.each_key.first, u.operation => values.values.first } }
        else
          fields[u.fieldname] = { u.operation => values }
        end
      end
    end
    fields
  end

end
