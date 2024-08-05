# Copyright Vespa.ai. All rights reserved.
module ChainedSetter
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def chained_setter(func_name, var_name = func_name)
      define_method func_name do |value|
        instance_variable_set("@#{var_name}", value)
        self
      end
    end

    def chained_forward(obj, funcs)
      funcs.each do |from, to|
        define_method from do |*value|
          parts = obj.to_s.split(".")
          object = instance_variable_get("@#{parts.first}")
          parts[1..-1].each do |part|
            object = object.send(part)
          end
          object.send(to, *value)
          self
        end
      end
    end
  end
end
