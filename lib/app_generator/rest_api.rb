# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/chained_setter'

module AppGenerator

  # Wrapped in a module because there was already a module that had taken the name 'RestApi'.
  class RestApi
    include ChainedSetter

    chained_setter :jersey1

    chained_forward :config, :config => :add
    chained_forward :bundles, :bundle => :push

    def initialize(path)
      @path = path
      @jersey1 = false
      @bundles = []
      @config = ConfigOverrides.new
    end

    def to_xml(indent)
      attrs = {:path => @path}
      # switch attribute name to 'jersey1' when jersey2 has become default
      attrs[:jersey2] = true unless @jersey1

      XmlHelper.new(indent).
          tag("rest-api", attrs).
          to_xml(@bundles).
          to_s
    end
  end

  class Bundle
    include ChainedSetter

    chained_forward :packages, :package => :push

    def initialize(name)
      @name = name
      @packages = []
    end

    def to_xml(indent)
      XmlHelper.new(indent).
          tag("components", :bundle => @name).
          to_xml(@packages).
          to_s
    end
  end

  class Package
    def initialize(name)
      @name = name
    end

    def to_xml(indent)
      XmlHelper.new(indent).
          tag("package").
          content(@name).
          close_tag.
          to_s
    end
  end

end