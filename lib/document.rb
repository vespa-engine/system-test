# Copyright Vespa.ai. All rights reserved.
require 'json'

class Document
  attr_reader :documentid
  attr_reader :documenttype
  attr_reader :fields

  def self.create_from_json(json, document_type)
    doc = Document.new(document_type, json["id"])
    json["fields"].each do |name, value|
      doc.add_field(name, value)
    end
    doc
  end

  def initialize(documenttype, documentid)
    @fields = Hash.new
    # TODO: Remove when all tests using this class are migrated to json
    @documenttype = documenttype
    @documentid = documentid
  end

  def <=>(other)
    return @documentid<=>other.documentid
  end

  def add_field(name, value)
    @fields[name] = value
    self
  end

  def fields_to_json
    JSON.dump({"fields" => @fields})
  end

  def to_json(operation = :put, in_array = false)
    content = ""
    if operation == :remove
      content = {operation.to_s => @documentid}
    else
      content = {operation.to_s => @documentid, "fields" => @fields}
    end
    JSON.dump(in_array ? [content] : content)
  end

  def write_json(f, operation = :put)
    f.write(to_json(operation))
  end

  def ==(other)
    if (other.nil?)
      return false
    end
    JSON.load(to_json) == JSON.load(other.to_json)
  end

  alias :inspect :to_json
end
