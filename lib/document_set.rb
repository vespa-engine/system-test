# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class DocumentSet
  attr_reader :documents

  def initialize()
    @documents = []
  end

  def add(document)
    @documents.push(document)
  end

  def to_xml
    rval = ""
    @documents.each do |document|
      rval += document.to_xml + "\n"
    end
    return rval
  end

  def write_json(name)
    write_json(name, :put)
  end

  def write_json(name, operation=:put)
    f = File.open(name, "w")
    f.write(to_json(operation))
    f.close()
  end

  def to_json(operation=:put)
    content = "[\n"
    first = true
    @documents.each do |document|
      if first
        first = false
      else
        content << ",\n"
      end
      content << document.to_json(operation, false)
    end
    content << "\n]\n"
    content
  end

  def write_removes_json(name)
    write_json(name, :remove)
  end

  def write_updates_json(name)
    write_json(name, :update)
  end

end
