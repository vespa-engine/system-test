# Copyright Vespa.ai. All rights reserved.

require 'assertionfailederror'
require 'backtracefilter'
require 'tensor_result'

module Assertions

  # The assertion upon which all other assertions are
  # based. Passes if the block yields true.
  public
  def assert_block(message="assert_block failed.") # :yields:
    _wrap_assertion do
      if (! yield)
        raise AssertionFailedError.new(message.to_s)
      end
    end
  end

  # Passes if boolean is true.
  public
  def assert(boolean, message=nil)
    _wrap_assertion do
      assert_block("assert should not be called with a block.") { !block_given? }
      assert_block(build_message(message, "<?> is not true.", boolean)) { boolean }
    end
  end

  def get_index_of_next_equal_to(array, element, first)
    while (first < array.length)
      if (array[first] == element)
        return first;
      end
      first += 1
    end
    return nil
  end

  # Create a string with textual diff between two objects whose string
  # representation is a set of lines
  def diff(a, b)
    output = Array.new
    expected = a.to_s.split("\n", -1);
    actual = b.to_s.split("\n", -1);
    i = 0
    j = 0
    while (i < expected.length || j < actual.length)
      if (i >= expected.length)
        output.push("+ " + actual[j])
        j += 1
      elsif (j >= actual.length)
        output.push("- " + expected[i])
        i += 1
      elsif (expected[i] == actual[j])
        output.push("  " + expected[i])
        i += 1
        j += 1
      else
        next_actual = get_index_of_next_equal_to(actual, expected[i], j + 1)
        next_expected = get_index_of_next_equal_to(expected, actual[j], i + 1)
        if (next_actual == nil)
            output.push("- " + expected[i])
            i += 1
        elsif (next_expected == nil || next_expected - i > next_actual - j)
            output.push("+ " + actual[j])
            j += 1
        else
            output.push("- " + expected[i])
            i += 1
        end
      end
    end
    return output.join("\n")
  end

  # Passes if expected == actual. Note that the ordering of
  # arguments is important, since a helpful error message is
  # generated when this one fails that tells you the values
  # of expected and actual.
  public
  def assert_equal(expected, actual, message=nil)
    if (expected.to_s.include?("\n") && actual.to_s.include?("\n"))
      diff = " Diff:\n" + diff(expected, actual)
    end
    full_message = build_message(message, <<EOT, expected, actual)
<?> expected but was
<?>.
EOT
    if (!(expected == actual) && diff != nil)
        puts diff
    end
    assert_block(full_message) { expected == actual }
  end

  # Passes if the JSON parsed value of expected string is
  # equal to the JSON parsed value of actual.
  def assert_json_string_equal(expected, actual)
      assert_equal(JSON.parse(expected), JSON.parse(actual))
  end

  # Converts parsed canonical tensors to objects and compares
  def assert_tensors_equal(expected, actual)
      exp = TensorResult.new(expected)
      act = TensorResult.new(actual)
      assert_equal(exp, act, "Tensors should be equal: Expected #{exp} != Actual #{act}")
  end

  private
  def _check_exception_class(args)
    args.partition do |klass|
      next if klass.instance_of?(Module)
      assert(Exception >= klass, "Should expect a class of exception, #{klass}")
      true
    end
  end

  private
  def _expected_exception?(actual_exception, exceptions, modules)
    exceptions.include?(actual_exception.class) or
      modules.any? {|mod| actual_exception.is_a?(mod)}
  end

  # Passes if block raises one of the given exceptions.
  public
  def assert_raise(*args)
    _wrap_assertion do
      if Module === args.last
        message = ""
      else
        message = args.pop
      end
      exceptions, modules = _check_exception_class(args)
      expected = args.size == 1 ? args.first : args
      actual_exception = nil
      full_message = build_message(message, "<?> exception expected but none was thrown.", expected)
      assert_block(full_message) do
        begin
          yield
        rescue Exception => actual_exception
          break
        end
        false
      end
      full_message = build_message(message, "<?> exception expected but was\n?", expected, actual_exception)
      assert_block(full_message) {_expected_exception?(actual_exception, exceptions, modules)}
      actual_exception
    end
  end

  # Alias of assert_raise. Will be deprecated in 1.9, and removed in 2.0.
  public
  def assert_raises(*args, &block)
    assert_raise(*args, &block)
  end

  # Passes if object.class == klass.
  public
  def assert_instance_of(klass, object, message="")
    _wrap_assertion do
      assert_equal(Class, klass.class, "assert_instance_of takes a Class as its first argument")
      full_message = build_message(message, <<EOT, object, klass, object.class)
<?> expected to be an instance of
<?> but was
<?>.
EOT
      assert_block(full_message){object.instance_of?(klass)}
    end
  end

  # Passes if object.nil?.
  public
  def assert_nil(object, message="")
    assert_equal(nil, object, message)
  end

  # Passes if object.kind_of?(klass).
  public
  def assert_kind_of(klass, object, message="")
    _wrap_assertion do
      assert(klass.kind_of?(Module), "The first parameter to assert_kind_of should be a kind_of Module.")
      full_message = build_message(message, "<?>\nexpected to be kind_of\\?\n<?> but was\n<?>.", object, klass, object.class)
      assert_block(full_message){object.kind_of?(klass)}
    end
  end

  # Passes if object.respond_to?(method) is true.
  public
  def assert_respond_to(object, method, message="")
    _wrap_assertion do
      full_message = build_message(nil, "<?>\ngiven as the method name argument to #assert_respond_to must be a Symbol or #respond_to\\?(:to_str).", method)

      assert_block(full_message) do
        method.kind_of?(Symbol) || method.respond_to?(:to_str)
      end
      full_message = build_message(message, <<EOT, object, object.class, method)
<?>
of type <?>
expected to respond_to\\?<?>.
EOT
      assert_block(full_message) { object.respond_to?(method) }
    end
  end

  # Passes if string =~ pattern.
  public
  def assert_match(pattern, string, message="")
    _wrap_assertion do
      pattern = case(pattern)
                when String
                  Regexp.new(Regexp.escape(pattern))
                else
                  pattern
                end
      full_message = build_message(message, "<?> expected to be =~\n<?>.", string, pattern)
      assert_block(full_message) { string =~ pattern }
    end
  end

  # Passes if not string =~ pattern.
  public
  def assert_no_match(pattern, string, message="")
    _wrap_assertion do
      pattern = case(pattern)
                when String
                  Regexp.new(Regexp.escape(pattern))
                else
                  pattern
                end
      full_message = build_message(message, "<?> expected to be not =~\n<?>.", string, pattern)
      assert_block(full_message) { string =~ pattern ? false : true }
    end
  end

  # Passes if actual.equal?(expected) (i.e. they are the
  # same instance).
  public
  def assert_same(expected, actual, message="")
    full_message = build_message(message, <<EOT, expected, expected.__id__, actual, actual.__id__)
<?>
with id <?> expected to be equal\\? to
<?>
with id <?>.
EOT
    assert_block(full_message) { actual.equal?(expected) }
  end

  # Compares the two objects based on the passed
  # operator. Passes if object1.__send__(operator, object2)
  # is true.
  public
  def assert_operator(object1, operator, object2, message="")
    _wrap_assertion do
      full_message = build_message(nil, "<?>\ngiven as the operator for #assert_operator must be a Symbol or #respond_to\\?(:to_str).", operator)
      assert_block(full_message){operator.kind_of?(Symbol) || operator.respond_to?(:to_str)}
      full_message = build_message(message, <<EOT, object1, AssertionMessage.literal(operator), object2)
<?> expected to be
?
<?>.
EOT
      assert_block(full_message) { object1.__send__(operator, object2) }
    end
  end

  # Passes if block does not raise an exception.
  public
  def assert_nothing_raised(*args)
    _wrap_assertion do
      if Module === args.last
        message = ""
      else
        message = args.pop
      end
      exceptions, modules = _check_exception_class(args)
      begin
        yield
      rescue Exception => e
        if ((args.empty? && !e.instance_of?(AssertionFailedError)) ||
            _expected_exception?(e, exceptions, modules))
          assert_block(build_message(message, "Exception raised:\n?", e)){false}
        else
          raise
        end
      end
      nil
    end
  end

  # Always fails.
  public
  def flunk(message="Flunked")
    assert_block(build_message(message)){false}
  end

  # Passes if !actual.equal?(expected).
  public
  def assert_not_same(expected, actual, message="")
    full_message = build_message(message, <<EOT, expected, expected.__id__, actual, actual.__id__)
<?>
with id <?> expected to not be equal\\? to
<?>
with id <?>.
EOT
    assert_block(full_message) { !actual.equal?(expected) }
  end

  # Passes if expected != actual.
  public
  def assert_not_equal(expected, actual, message="")
    full_message = build_message(message, "<?> expected to be != to\n<?>.", expected, actual)
    assert_block(full_message) { expected != actual }
  end

  # Passes if !object.nil?.
  public
  def assert_not_nil(object, message="")
    full_message = build_message(message, "<?> expected to not be nil.", object)
    assert_block(full_message){!object.nil?}
  end


  UncaughtThrow = {NameError => /^uncaught throw \`(.+)\'$/,
    ThreadError => /^uncaught throw \`(.+)\' in thread /} #`

  # Passes if block throws symbol.
  public
  def assert_throws(expected_symbol, message="", &proc)
    _wrap_assertion do
      assert_instance_of(Symbol, expected_symbol, "assert_throws expects the symbol that should be thrown for its first argument")
      assert_block("Should have passed a block to assert_throws."){block_given?}
      caught = true
      begin
        catch(expected_symbol) do
          proc.call
          caught = false
        end
        full_message = build_message(message, "<?> should have been thrown.", expected_symbol)
        assert_block(full_message){caught}
      rescue NameError, ThreadError => error
        if UncaughtThrow[error.class] !~ error.message
          raise error
        end
        full_message = build_message(message, "<?> expected to be thrown but\n<?> was thrown.", expected_symbol, $1.intern)
        flunk(full_message)
      end
    end
  end

  # Passes if block does not throw anything.
  public
  def assert_nothing_thrown(message="", &proc)
    _wrap_assertion do
      assert(block_given?, "Should have passed a block to assert_nothing_thrown")
      begin
        proc.call
      rescue NameError, ThreadError => error
        if UncaughtThrow[error.class] !~ error.message
          raise error
        end
        full_message = build_message(message, "<?> was thrown when nothing was expected", $1.intern)
        flunk(full_message)
      end
      assert(true, "Expected nothing to be thrown")
    end
  end

  # Passes if expected_float and actual_float are equal
  # within delta tolerance.
  public
  def assert_in_delta(expected_float, actual_float, delta, message="")
    _wrap_assertion do
      {expected_float => "first float", actual_float => "second float", delta => "delta"}.each do |float, name|
        assert_respond_to(float, :to_f, "The arguments must respond to to_f; the #{name} did not")
      end
      assert_operator(delta, :>=, 0.0, "The delta should not be negative")
      full_message = build_message(message, <<EOT, expected_float, actual_float, delta)
<?> and
<?> expected to be within
<?> of each other.
EOT
      assert_block(full_message) { (expected_float.to_f - actual_float.to_f).abs <= delta.to_f }
    end
  end

  # Passes if the method sent returns a true value.
  public
  def assert_send(send_array, message="")
    _wrap_assertion do
      assert_instance_of(Array, send_array, "assert_send requires an array of send information")
      assert(send_array.size >= 2, "assert_send requires at least a receiver and a message name")
      full_message = build_message(message, <<EOT, send_array[0], AssertionMessage.literal(send_array[1].to_s), send_array[2..-1])
<?> expected to respond to
<?(?)> with a true value.
EOT
      assert_block(full_message) { send_array[0].__send__(send_array[1], *send_array[2..-1]) }
    end
  end

  public
  def build_message(head, template=nil, *arguments)
    template &&= template.chomp
    return AssertionMessage.new(head, template, arguments)
  end

  private
  def _wrap_assertion
    @_assertion_wrapped ||= false
    unless (@_assertion_wrapped)
      @_assertion_wrapped = true
      begin
        add_assertion
        return yield
      ensure
        @_assertion_wrapped = false
      end
    else
      return yield
    end
  end

  # Called whenever an assertion is made.
  private
  def add_assertion
  end

  # Select whether or not to use the prettyprinter. If this
  # option is set to false before any assertions are made, the
  # prettyprinter will not be required at all.
  public
  def self.use_pp=(value)
    AssertionMessage.use_pp = value
  end

  class AssertionMessage
    @use_pp = true
    class << self
      attr_accessor :use_pp
        end

    class Literal
      def initialize(value)
        @value = value
      end

      def inspect
        @value.to_s
      end
    end

    class Template
      def self.create(string)
        parts = (string ? string.scan(/(?=[^\\])\?|(?:\\\?|[^\?])+/m) : [])
        self.new(parts)
      end

      attr_reader :count

      def initialize(parts)
        @parts = parts
        @count = parts.find_all{|e| e == '?'}.size
      end

      def result(parameters)
        raise "The number of parameters does not match the number of substitutions." if(parameters.size != count)
        params = parameters.dup
        @parts.collect{|e| e == '?' ? params.shift : e.gsub(/\\\?/m, '?')}.join('')
      end
    end

    def self.literal(value)
      Literal.new(value)
    end

    include BacktraceFilter

    def initialize(head, template_string, parameters)
      @head = head
      @template_string = template_string
      @parameters = parameters
    end

    def convert(object)
      case object
      when Exception
        <<EOM.chop
Class: <#{convert(object.class)}>
Message: <#{convert(object.message)}>
---Backtrace---
#{filter_backtrace(object.backtrace).join("\n")}
---------------
EOM
      else
        if(self.class.use_pp)
          begin
            require 'pp'
          rescue LoadError
            self.class.use_pp = false
            return object.inspect
          end unless(defined?(PP))
          PP.pp(object, '').chomp
        else
          object.inspect
        end
      end
    end

    def template
      @template ||= Template.create(@template_string)
    end

    def add_period(string)
      (string =~ /\.\Z/ ? string : string + '.')
    end

    def to_s
      message_parts = []
      if (@head)
        head = @head.to_s
        unless(head.empty?)
          message_parts << head
        end
      end
      tail = template.result(@parameters.collect{|e| convert(e)})
      message_parts << tail unless(tail.empty?)
      message_parts.join("\n")
    end
  end
end
