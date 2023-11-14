# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class NodeBase
  class << self
    attr_reader :tag_name
    def tag(t)
      @tag_name = t
    end
  end

  def initialize(params = {})
    @params = params
    @params[:hostalias] ||= "node1"
  end

  def config(config)
    @params[:config] = ConfigOverrides.new unless @params[:config]
    @params[:config].add(config)
    self
  end

  def set_baseport(baseport)
    @params[:baseport] = baseport
  end

  def attribute(name, rename = nil)
    if rename
      return " #{rename}=\"#{@params[name].to_s}\"" if @params[name]
      return ''
    end

    return " #{name}=\"#{@params[name].to_s}\"" if @params[name]
    return ''
  end

  def content(name, indent)
    return @params[name].to_xml(indent + "  ") if @params[name]
    return ''
  end

  def body(indent)
      return ""
  end

  def to_xml_with_distribution_key(indent, tag = self.class.tag_name)
    indent + "<#{tag}" +
    attribute(:hostalias) +
    attribute(:index, "distribution-key") +
    attribute(:baseport) +
    attribute(:capacity) +
    close_tag(indent, tag)
  end

  def to_xml(indent, tag = self.class.tag_name)
    indent + "<#{tag}" +
    attribute(:hostalias) +
    attribute(:index) +
    attribute(:baseport) +
    attribute(:capacity) +
    close_tag(indent, tag)
  end

  def close_tag(indent, tag)
    tag_content = content(:config, indent + "  ")
    tag_content = tag_content + "\n" if tag_content != ''
    tag_content = tag_content + body(indent + "  ")
    return " />\n" if tag_content == ''
    return ">\n" + tag_content +
           indent + "</#{tag}>\n"
  end
end

class SimpleNode < NodeBase
  def initialize(hostalias)
    super(:hostalias => hostalias)
  end
end
