# Copyright Vespa.ai. All rights reserved.

require 'set'

# Selects which of the test objects found by the test runner to run, given the names of the tests to run,
# like "Class::test_method". All tests are selected when the names are nil or empty, so a missing list never
# turns into a test run without tests.
class TestSelector

  def self.test_name(test_object, method)
    "#{test_object.class.name}::#{method.to_s}"
  end

  # Returns the selected test objects, as a hash of test object to method like test_objects,
  # and the names to run that match none of the test objects.
  def self.select(test_objects, names_to_run)
    return [test_objects, []] if names_to_run.nil? || names_to_run.empty?

    wanted = names_to_run.to_set
    selected = test_objects.select { |test_object, method| wanted.include?(test_name(test_object, method)) }
    found = selected.map { |test_object, method| test_name(test_object, method) }.to_set
    [selected, (wanted - found).to_a.sort]
  end

end
