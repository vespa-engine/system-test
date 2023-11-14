# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/mocks/mock_qrserver'

class MockVespaModel < VespaModel
  def initialize
    super("unittest")
    @service_entry = {}
    @service_entry["ports"] = ["0", "1"]
    @service_entry["ports_by_tag"] = {}
    @service_entry["ports_by_tag"]["query"] = "0"
    @service_entry["ports_by_tag"]["rpc"] = "1"
    @qrserver["0"] = MockQrserver.new(@service_entry)
  end
end
