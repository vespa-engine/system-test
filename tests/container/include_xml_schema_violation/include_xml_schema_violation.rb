# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class IncludeXmlSchemaViolation < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that deploy fails on xml errors from included files, and that errors are reported appropriately.")
  end

  def test_include_xml_schema_violation
    begin
      err = deploy(selfdir + "app")
    rescue ExecuteError => e
      err = e.output
      msg = e.message
    end
    puts "Deploy output:"
    puts "message: #{msg}"
    assert_match(/non-zero exit status/, msg, "vespa-deploy prepare should return error")
    assert_match(/deploy.*prepare/, msg, "vespa-deploy prepare should return error")

    puts "output: #{err}"
    assert_match(/Invalid XML according to XML schema, error in schema-violation.xml/, err,
                 "error message did not contain required text")
  end

  def teardown
    stop
  end

end
