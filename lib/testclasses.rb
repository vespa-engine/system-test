# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'testcase'

class TestClasses
  def self.each_class(filter=[TestCase])
    ObjectSpace.each_object(Class) do |klass|
      try = false
      filter.each { |superklass| try = true if klass < superklass }

      if try
        yield klass
      end
    end
  end

  def self.test_methods(klass)
    method_names = klass.public_instance_methods(false)

    method_names.delete_if do |name|
      name !~ /^test_/
    end
  end
end
