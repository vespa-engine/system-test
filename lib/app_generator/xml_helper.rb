# Copyright Vespa.ai. All rights reserved.
# Allow sorting of symbols, to get a deterministic order of attributes.
class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end

def var_if(predicate, var)
  var if predicate
end

class XmlHelper
  def initialize(indent)
    @indent = indent
    @open_tags = [Tag.new(:known_elephant)]
  end

  class Tag
    attr_accessor :content

    def initialize(tag, attrs = {})
      @tag = tag
      @content = ''
      @attrs = Hash.new
      attrs.each do |key, value|
        if value.respond_to? :gsub
          v = value.dup
          v.gsub!("&", "&amp;" )
          v.gsub!("\"", "&quot;" )
          v.gsub!("'", "&apos;" )
          v.gsub!("<", "&lt;" )
          v.gsub!(">", "&gt;" )
          v.gsub!("\n", "&#10;" )
          @attrs[key] = v
        else
          @attrs[key] = value
        end
      end
    end

    def open_tag
      s = "<#{@tag}"
      @attrs.sort.each do |name, value|
        s += " #{name}=\"#{value}\"" unless value.nil?
      end
      s += " /" if @content == ''
      s += ">"
    end

    def close_tag
      "</#{@tag}>"
    end

    def to_xml(indent)
      s = indent + open_tag
      if @content != ''
        if @content.chomp == @content
          s += @content + close_tag
        else
          s += "\n" +
               @content +
               indent + close_tag
        end
      end
      s += "\n"
    end
  end

  class TagIfContent < Tag
    alias :super_to_xml :to_xml

    def attrs_empty
      @attrs.each do |name, value|
        return nil unless value.nil?
      end
    end

    def to_xml(indent)
      return '' if @content == '' && attrs_empty
      super_to_xml(indent)
    end
  end

  def close_tag
    @indent = @indent[1..-2]
    xml = @open_tags.pop.to_xml(@indent)
    @open_tags.last.content += xml
    self
  end

  def tag_always(tag, attrs = {})
    @indent += "  "
    @open_tags.push(Tag.new(tag, attrs))
    self
  end

  def tag(tag, attrs = {})
    @indent += "  "
    @open_tags.push(TagIfContent.new(tag, attrs))
    self
  end

  def to_xml(obj, to_xml_func = :to_xml)
    if obj.is_a? Array
      obj.each do | entry |
        to_xml(entry, to_xml_func)
      end
    elsif obj.respond_to? to_xml_func
      @open_tags.last.content += obj.send(to_xml_func, @indent)
    else
      @open_tags.last.content += obj.to_s if obj
    end
    self
  end

  def list_do(list, &func)
    list.each do |entry|
      yield(self, entry)
    end
    self
  end

  def call(&func)
    content(func.call(@indent).to_s)
  end

  def content(content)
    @open_tags.last.content += content.to_s unless content.nil?
    self
  end

  def to_s
    return @open_tags.first.content if @open_tags.size == 1
    close_tag.to_s
  end
end
