# Copyright Vespa.ai. All rights reserved.
require 'date'

class ValidationOverrides

  attr_reader :has_overrides

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

  def has_overrides
    @override_id
  end

end
