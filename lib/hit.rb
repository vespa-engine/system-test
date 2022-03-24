# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Hit

  attr_reader :field
  attr_writer :comparablefields

  def initialize(xmlelement = nil)
    @field = {}
    @comparablefields = nil
    if xmlelement
      if xmlelement.instance_of?(REXML::Element)
        read_xml(xmlelement)
      elsif xmlelement.instance_of?(Hash)
        read_hash(xmlelement)
      else
        parse_xml(xmlelement)
      end
    end
  end

  def parse_xml(xmldata)
    @xml = REXML::Document.new(xmldata).root
    read_xml(@xml)
  end

  def array_sort_cmp(a, b)
    if a.instance_of?(Hash)
      return 0 if b.instance_of?(Hash)
      return -1
    end
    return 1 if b.instance_of?(Hash)
    (a!= nil and b!= nil) ? (a<=> b) : -1
  end

  def parse_structfield(field)
    if field.elements["item"] != nil
      items = []
      field.each_element("item") do |item|
        items.push(parse_item(item))
      end
      return items.sort { |a, b| array_sort_cmp(a, b) }
    else
      return field.text
    end
  end

  def parse_item(item)
    if item.elements["struct-field"] != nil
      fields = {}
      item.each_element("struct-field") do |field|
        fields[field.attribute("name").to_s] = parse_structfield(field)
      end
      return fields
    elsif item.attributes["weight"] != nil
      return item.text + "(" + item.attributes["weight"].to_s + ")"
    else
      return item.text
    end
  end

  def read_hash(e)
    add_field("relevancy", e['relevance'])
    add_field("documentid", e['id'])
    add_field("source", e['source']) if e.key?('source')
    if e.key?('fields')
      e['fields'].each { |f| add_field(f.first, f.last) }
    end
  end

  def read_xml(xmlelement)
     xmlelement.each_element("field") do |e|
      fieldname = e.attribute("name").to_s
      fieldvalue = e.children.join("").to_s

      if fieldname == 'summaryfeatures' and fieldvalue[0] == '{'
        sf = JSON.parse(fieldvalue)
        add_field(fieldname, sf)
      elsif fieldname == 'rankfeatures' and fieldvalue[0] == '{'
        rf = JSON.parse(fieldvalue)
        add_field(fieldname, rf)
      elsif e.elements["item"] != nil
        items = []
        e.each_element("item") do |item|
          items.push(parse_item(item))
        end
        add_field(fieldname, items)
      else
        add_field(fieldname, fieldvalue)
      end

    end
  end

  def to_xml
    if (@xml == nil)
      @xml= REXML::Element.new("hit")
      @xml.add_attribute("relevancy", @relevancy)
      @xml.add_attribute("source", @source)
      @field.each_key { |key|
        elem = REXML::Element.new("field")
        elem.add_attribute("name", key)
        elem.add_text(@field[key].to_s)
        @xml.add_element(elem)
      }
    end

    return @xml
  end

  def add_field(fieldname, fieldvalue)
    if fieldvalue.instance_of?(Array)
      items = fieldvalue.sort {|a, b| array_sort_cmp(a, b) }
      fieldvalue = items
    end
    if fieldname == 'summaryfeatures' && fieldvalue.instance_of?(Hash)
      fieldvalue.delete('vespa.summaryFeatures.cached')
    end
    @field[fieldname] = fieldvalue
  end

  def comparable_fields
    comp_fields = field
    if @comparablefields
      comp_fields = fields(@comparablefields)
    else
      comp_fields.delete("relevancy")
      comp_fields.delete("documentid")
      comp_fields.delete_if {|key,value| key =~ /^[as]_\d+$/ and value == ""}
      comp_fields.delete_if {|key,value| key =~ /summaryfeatures/ and value == ""}
    end
    return comp_fields
  end

  def fields(filter)
    filtered_fields = field
    filtered_fields.each_key { |k|
      if filter.index(k) == nil
        filtered_fields.delete(k)
      end
    }
    filtered_fields
  end

  def setcomparablefields(fieldnamearray)
    @comparablefields = fieldnamearray
  end

  def to_s
    stringval = ""
    content = @field.sort
    content.each do |e|
      stringval += "#{e[0]}: #{e[1]} "
    end
    stringval.chop
  end

  def inspect
    to_s
  end

  def ==(other)
    if other.class != self.class
      return false
    end
    if (@comparablefields)
      return Resultset.approx_cmp(fields(@comparablefields), other.fields(@comparablefields), "field")
    else
      return Resultset.approx_cmp(comparable_fields, other.comparable_fields, "field")
    end
  end

end

