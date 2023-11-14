# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class ConfigValue
  def initialize(key, value)
    @key = key
    if value.respond_to? :to_xml
      @value_obj = value
    else
      @value = value
    end
  end
  def to_xml(indent)
    XmlHelper.new(indent).
      tag(@key).
        to_xml(@value_obj).
        content(@value).to_s
  end
end

class ConfigValues
  include ChainedSetter

  def initialize()
    @values = []
  end
  def add(key, value = nil)
    if key.is_a? ConfigValue and value.nil?
      @values.push(key)
    else
      @values.push(ConfigValue.new(key, value))
    end
    self
  end
  def to_xml(indent="")
    XmlHelper.new(indent).to_xml(@values).to_s
  end
end

class ArrayConfig
  def initialize(name)
    @name = name
    @map = {}
  end
  def add(key, value)
    if !key.kind_of? Integer
      raise "Key must be integer, is #{key.class} ('#{key}')"
    end
    @map[key] = [] unless @map.has_key?(key)
    @map[key].push(value)
    return self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag(@name).
      list_do(@map.keys) { |helper, key|
        helper.tag("item").
          to_xml(@map[key]).close_tag }.to_s
  end
end

class MapConfig
  def initialize(name)
    @name = name
    @map = {}
  end

  def add(key, value)
    @map[key] = value
    return self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag(@name).
      list_do(@map.keys) { |helper, key|
        helper.tag("item", :key => key).
          to_xml(@map[key]).close_tag }.to_s
  end
end

class ModelConfig
  def initialize(name, id, path: nil, url: nil)
    @name = name
    @id = id
    @path = path
    @url = url
    if path.nil? && url.nil?
      raise "path or url must be specified for model config '#{name}','#{id}'"
    end
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag(@name, :"model-id" => @id, :url => @url, :path => @path).close_tag.to_s
  end
end

class ConfigOverride
  include ChainedSetter

  def initialize(name)
    @name = name
    @overrides = []
  end
  def add(key, value = nil)
    if key.is_a? ArrayConfig and value.nil?
      @overrides.push(key)
    elsif key.is_a? MapConfig and value.nil?
      @overrides.push(key)
    elsif key.is_a? ModelConfig and value.nil?
      @overrides.push(key)
    else
      @overrides.push(ConfigValue.new(key, value))
    end
    self
  end
  def to_xml(indent="")
    XmlHelper.new(indent).
      tag("config", :name => @name).
        to_xml(@overrides).to_s
  end
end

class ConfigOverrides
  include ChainedSetter

  chained_forward :overrides, :add => :push
  def initialize()
    @overrides = []
  end
  def to_xml(indent="")
    XmlHelper.new(indent).
      to_xml(@overrides).to_s
  end
end

