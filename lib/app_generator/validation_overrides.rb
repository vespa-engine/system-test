# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'date'

class ValidationOverrides

  def initialize
    @override_id = nil
  end

  # Sets the single validation override this will contain
  def validation_override(override_id)
    @override_id = override_id
  end

  # Returns a validation-overrides.xml for this application package containing a single override
  # with the given id which is valid through tomorrow. If no validation override id is set, the file is empty.
  def to_xml
    overrides =  "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n"
    overrides << "<validation-overrides>\n"
    if @override_id
      overrides << "  <allow until='" + tomorrow() + "'>" << @override_id << "</allow>\n"
    end
    overrides << "</validation-overrides>\n"
  end

  # Returns tomorrows date as an IDO-8601 date string
  def tomorrow()
    Date.today().next_day().to_s
  end

end
