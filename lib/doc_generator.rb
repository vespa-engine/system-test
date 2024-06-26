# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'documentupdate'

class IntegerGenerator
  def IntegerGenerator.rand_array(min_int, max_int, size)
    retval = []
    size.times do
      retval.push(min_int + rand(max_int - min_int))
    end
    return retval
  end

  def IntegerGenerator.rand_unique_array(min_int, max_int, size)
    retval = []
    checkval = Hash.new
    size.times do
      int = min_int + rand(max_int - min_int)
      while checkval.include?(int)
        int = min_int + rand(max_int - min_int)
      end
      retval.push(int)
      checkval[int] = true
    end
    return retval
  end
end

class StringGenerator

  Caval = "a"[0].ord
  Cazrange = "z"[0].ord + 1 - "a"[0].ord

  def StringGenerator.rand_string(min_len, max_len)
    len = (min_len >= max_len ? min_len : min_len + rand(max_len - min_len))
    string = []
    len.times do
      string.push(Caval + rand(Cazrange))
    end
    return string.pack("c*")
  end

  def StringGenerator.rand_array(min_len, max_len, size)
    retval = []
    size.times do
      retval.push(rand_string(min_len, max_len))
    end
    return retval
  end

  def StringGenerator.rand_unique_array(min_len, max_len, size)
    retval = []
    checkval = Hash.new
    size.times do
      string = rand_string(min_len, max_len)
      while checkval.include?(string)
        string = rand_string(min_len, max_len)
      end
      retval.push(string)
      checkval[string] = true
    end
    return retval
  end
end

class DocumentUpdateGenerator
  def initialize(doc_type, doc_ids, fields, operation = "assign")
    @doc_type = doc_type
    @doc_ids = doc_ids
    @fields = fields
    @doc_updates = []
    @operation = operation
  end

  def generate
    @doc_ids.each do |id|
      update = DocumentUpdate.new(@doc_type, id)
      @fields.each do |field_data|
        value_count = field_data.value_count.next
        field_data.values.set_pos(rand(field_data.values.size))
        if field_data.collection == "singleval"
          update.addOperation(@operation, field_data.name, field_data.values.next)
        else
          values = []
          value_count.times do
            values.push(field_data.values.next)
          end
          update.addOperation(@operation, field_data.name, values)
        end
      end
      @doc_updates.push(update)
    end
  end

  def to_xml
    retval = ""
    @doc_updates.each do |update|
      retval += update.to_json
      retval += "\n"
    end
    return retval
  end

  def write(file)
    @doc_updates.each do |update|
      file.write(update.to_json + "\n")
    end
  end
end

class DocumentGenerator
  def initialize(doc_type, doc_ids, fields)
    @doc_type = doc_type
    @doc_ids = doc_ids
    @fields = fields
    @documents = []
  end

  def generate
    @doc_ids.each do |id|
      document = Document.new(@doc_type, id)
      @fields.each do |field_data|
        value_count = field_data.value_count.next
        field_data.values.set_pos(rand(field_data.values.size))
        if field_data.collection == "singleval"
          document.add_field(field_data.name, field_data.values.next)
        else
          if field_data.collection == "arrayval"
	    arr = []
            value_count.times do
              arr.push(field_data.values.next)
            end
            document.add_field(field_data.name, arr)
          elsif field_data.collection == "weightedsetval"
            ws = []
            value_count.times do
               ws.push(field_data.values.next)
            end
            document.add_field(field_data.name, ws)
          end
        end
      end
      @documents.push(document)
    end
  end

  def to_json
    retval = ""
    @documents.each do |document|
      retval += document.to_json
      retval += "\n"
    end
    return retval
  end

  def write(file)
    @documents.each do |document|
      file.write(document.to_json + "\n")
    end
  end
end

class UniqueArray
  attr_reader :uniques

  def initialize(values)
    @values = values
    @uniques = []
    reset(0)
  end
  def reset(idx)
    @uniques.clear
    @values.each do |elem|
      @uniques.push([elem, 0])
    end
    @idx = idx
  end
  def set_pos(idx)
    @idx = idx
    @idx = 0 if @idx >= @uniques.size
  end
  def size
    @uniques.size
  end
  def next
    retval = @uniques[@idx][0]
    @uniques[@idx][1] = @uniques[@idx][1] + 1
    @idx = @idx + 1
    @idx = 0 if @idx == @uniques.size
    return retval
  end
end

class ValueCount
  def initialize(min, max)
    @min = min
    @max = max
  end
  def next
    return @min + rand(@max - @min)
  end
end

if __FILE__ == $0
  Struct.new("FieldData", :name, :type, :collection, :values, :value_count)
  strings = ["one", "two", "three", "four", "five"]
  weighted = [["one", 1], ["two", 2], ["three", 3], ["four", 4], ["five", 5]]
  uniques = []
  uniques.push(UniqueArray.new(strings))
  uniques.push(UniqueArray.new(strings))
  uniques.push(UniqueArray.new(weighted))

  fields = []
  fields.push(Struct::FieldData.new("yahoo", "stringval", "singleval", uniques[0], ValueCount.new(1, 2)))
  fields.push(Struct::FieldData.new("ubuntu", "stringval", "arrayval", uniques[1], ValueCount.new(1, 5)))
  fields.push(Struct::FieldData.new("vespa", "stringval", "weightedsetval", uniques[2], ValueCount.new(1, 5)))

  doc_ids = []
  for i in 0...5
    doc_ids.push("docid#{i}")
  end

  d = DocumentUpdateGenerator.new("generator", doc_ids, fields)
  d.generate
  puts d.to_json

  puts "\nDocumentGenerator:\n\n"
  dg = DocumentGenerator.new("generator", doc_ids, fields)
  dg.generate
  puts dg.to_json

  uniques.each do |unique|
    puts "unique:"
    unique.uniques.each do |value|
      puts value[0].to_s + " - " + value[1].to_s
    end
  end

  5.times do
    puts StringGenerator.rand_string(1, 2)
  end
  puts StringGenerator.rand_unique_array(1, 5, 5)
  puts IntegerGenerator.rand_unique_array(-100, 100, 5)
end
