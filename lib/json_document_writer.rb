# Copyright Vespa.ai. All rights reserved.
require 'json'

# Class for writing json documents (put, update) to an io stream.
class JsonDocumentWriter
  private
  def operation(op, doc_id, fields)
    @ios.write(",\n") if !@first
    @ios.write({ op => doc_id, "fields" => fields }.to_json)
    @first = false
  end

  public
  def initialize(ios)
    @ios = ios
    @first = true
    @ios.write("[\n")
  end

  def put(doc_id, fields)
    operation("put", doc_id, fields)
  end

  def update(doc_id, fields)
    operation("update", doc_id, fields)
  end

  def close
    @ios.write("\n]\n")
    @ios.close
  end
end
