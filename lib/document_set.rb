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

  def to_rm_xml
    rval = ""
    @documents.each do |document|
      rval += document.to_rm_xml + "\n"
    end
    return rval
  end

  def write_vespafeed_xml(name)
    f = File.open(name, "w")
    f.write("<vespafeed>\n")
    @documents.each do |document|
      document.write_xml(f)
      f.write("\n")
    end
    f.write("</vespafeed>\n")
    f.close()
  end

  def write_json(name)
    write_json(name, :put)
  end

  def write_json(name, operation=:put)
    f = File.open(name, "w")
    f.write("[\n")
    first = true
    @documents.each do |document|
      if first
        first = false
      else
        f.write(",\n")
      end
      f.write(document.to_json(operation, false))
    end
    f.write("\n]\n")
    f.close()
  end

  def write_removes_json(name)
    write_json(name, :remove)
  end

  def write_updates_json(name)
    write_json(name, :update)
  end

  def write_xml(name)
    f = File.open(name, "w")
    @documents.each do |document|
      document.write_xml(f)
      f.write("\n")
    end
    f.close()
  end

  def write_rm_xml(name)
    f = File.open(name, "w")
    @documents.each do |document|
      document.write_rm_xml(f)
      f.write("\n")
    end
    f.close()
  end
end
