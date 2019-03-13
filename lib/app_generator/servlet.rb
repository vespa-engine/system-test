# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/chained_setter'

module AppGenerator

  class Servlet
    include ChainedSetter

    chained_setter :klass
    chained_setter :config
    chained_setter :bundle
    chained_setter :path
    chained_setter :servlet_config

    def initialize(id)
      @id = id
      @config = ConfigOverrides.new
      @paths = []
    end

    def to_xml(indent="")
      dump_xml(indent)
    end

    def dump_xml(indent="", tagname="servlet")
      XmlHelper.new(indent).
          tag(tagname,
              :id => @id,
              :bundle => @bundle,
              :class => @klass).
            to_xml(@config).
            to_xml(@servlet_config).
            tag("path").content(@path).to_s
    end
  end

  class ServletConfig
    include ChainedSetter

    def initialize()
      @overrides = []
    end
    def add(key, value = nil)
      @overrides.push(ConfigValue.new(key, value))
      self
    end
    def to_xml(indent="")
      XmlHelper.new(indent).
          tag("servlet-config").
          to_xml(@overrides).to_s
    end
  end

end

