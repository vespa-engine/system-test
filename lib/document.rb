# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'json'

class Document
  attr_reader :documentid
  attr_reader :documenttype
  attr_reader :fields

  def self.create_from_xml(xml)
    doc = Document.new(xml.attributes["documenttype"], xml.attributes["documentid"])

    xml.elements.each { |elem|
      if (elem.has_elements?)
        val=[]

        elem.each_element { |e|
          if (e.attributes["weight"])
            val.push([e.text, e.attributes["weight"]])
          else
            val.push(e.text)
          end
        }

        doc.add_field(elem.name, val)
      else
        doc.add_field(elem.name, elem.text)
      end
    }
    return doc
  end

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

  def to_put_json(in_array = false)
    if in_array
      JSON.dump([{"put" => @documentid, "fields" => @fields}])
    else
      JSON.dump({"put" => @documentid, "fields" => @fields})
    end
  end

  def xmlQuote(s, isAttr=false)
    r = ""
    s.each_char do |c|
      if c == '&'
        r << "&amp;"
      elsif c == '<'
        r << "&lt;"
      elsif c == '>'
        r << "&gt;"
      elsif isAttr && c == '"'
        r << "&quot;"
      else
        r << c
      end
    end
    return r
  end

  # TODO: Remove when all tests using this class are migrated to json
  def to_xml
    ret = "<document documenttype=\"" + @documenttype +
          "\" documentid=\"" + xmlQuote(@documentid, true) + "\">\n"

    fields.sort.each { | key,value |
      if value.class == Array
        ret << "  <" + key + ">\n"
        if value[0].class == Array
	  value.sort.each { | v |
            ret << "    <item weight=\"" + v[1].to_s + "\">" + xmlQuote(v[0].to_s) + "</item>\n"
          }
        else
	  value.each { | v |
            ret << "    <item>" + xmlQuote(v.to_s) + "</item>\n"
          }
        end
        ret << "  </" + key + ">\n"
      elsif value.class == Hash
        ret << "  <" + key + ">\n"
        value.sort.each { | k, v |
          ret << "    <item><key>#{k}</key><value>#{v}</value></item>\n"
        }
        ret << "  </" + key + ">\n"
      elsif value.class == String or value.is_a? Numeric
        ret << "  <" + key + ">" + xmlQuote(value.to_s) + "</" + key + ">\n"
      elsif value  # Struct
        ret << "  <" + key + ">\n"
        value.each_pair { | name, val |
          ret << "    <#{name}>#{xmlQuote(val)}</#{name}>\n"
        }
        ret << "  </" + key + ">\n"
      else # nil value, eg. <foo/>
        ret << "  <" + key + "/>\n"
      end
    }
    ret << "</document>"
    ret
  end

  def write_xml(f)
    f.write(to_xml)
  end

  def to_rm_xml
    return "<remove documentid=\"" + xmlQuote(@documentid, true) + "\" />"
  end

  def write_rm_xml(f)
    f.write(to_rm_xml)
  end

  def ==(other)
    if (other.nil?)
      return false
    end
    # TODO: change to use to_json
    return to_xml == other.to_xml
  end

  alias :inspect :to_xml
end
