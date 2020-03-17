# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class SDValidation < SearchTest

  def setup
    set_owner("musum")
  end

  def test_sdvalidation    
    # first one tests that file name in message is relative to app package path
    deploy_invalid_sd(selfdir+"invalid_il_expression_name.sd", "Could not parse sd file 'invalid_il_expression_name.sd'")
    deploy_invalid_sd(selfdir+"invalid_fieldtype.sd")
    deploy_invalid_sd(selfdir+"invalid_fieldbody.sd")
    deploy_invalid_sd(selfdir+"reserved_fieldname.sd")
    deploy_invalid_sd(selfdir+"bold_nonword.sd")
    deploy_invalid_sd(selfdir+"dynteaser_nonword.sd")
    deploy_invalid_sd(selfdir+"position_conflict.sd")
    deploy_invalid_sd(selfdir+"attribute_properties.sd")
  end

  # Tests that we get a proper error message from il parser with line number when il script is invalid
  def test_error_message_invalid_il
    warning_regexp = Regexp.new("Error reported by IL parser: Encountered \" <IDENTIFIER> \"" +
                                "compact_string_to_single_term\"\" at line 5, column 57.")
    begin
      deploy_app(SearchApp.new.sd(selfdir+"invalid_il_expression_name.sd"))
      assert(false)
    rescue ExecuteError => ee
      assert_match(warning_regexp, ee.output)
    end
  end

  # Tests that we get a proper error message from sd parser with line number when sd is invalid
  def test_error_message_invalid_sd
    warning_regexp = Regexp.new("Could not parse sd file 'invalid_sd_construct.sd': Encountered \" \"\\(\" \"\\(\"\" at line 5, column 36")
    begin
      deploy_app(SearchApp.new.sd(selfdir+"invalid_sd_construct.sd"))
      assert(false)
    rescue ExecuteError => ee
      assert_match(warning_regexp, ee.output)
    end
  end

  def test_setlanguage_warning
    warning_regexp = Regexp.new("Preceding text fields that will not have their language set: title uniq_id")

    output = deploy_app(SearchApp.new.sd(selfdir+"setlanguage_warning.sd"))
    assert_match(warning_regexp, output)

    warning_regexp = Regexp.new("Preceding text fields that will not have their language set:")

    output = deploy_app(SearchApp.new.sd(selfdir+"setlanguage_nowarning.sd")
                                     .validation_override("content-type-removal"))
    assert_no_match(warning_regexp, output)

    warning_regexp = Regexp.new("Preceding text fields that will not have their language set:")

    output = deploy_app(SearchApp.new.sd(selfdir+"setlanguage_nowarning_uri.sd")
                                     .validation_override("content-type-removal"))
    assert_no_match(warning_regexp, output)
  end

  def test_position_expression
    deploy_app(SearchApp.new.sd(selfdir+"position_valid.sd"))
  end

  def test_attribute_properties
    # Test that specifying an attribute property for an attribute that is created later
    # in another firld works.
    output = deploy_app(SearchApp.new.sd(selfdir+"attribute_properties_ok.sd"))
  end

  def test_rank_validation
    set_description("Test that rank validation fails deploy application")
    begin
      deploy_app(SearchApp.new.sd(selfdir+"invalid_rank.sd"))
      assert(false)
    rescue ExecuteError => ee
      assert_match(Regexp.new("ERROR: rank profile 'fail1': FAIL"), ee.output)
      assert_match(Regexp.new("ERROR: rank profile 'fail2': FAIL"), ee.output)
    end
  end

  def deploy_invalid_sd(sdname, error_message=nil)
    exception = assert_raise(ExecuteError) {
      deploy_app(SearchApp.new.sd(sdname))
    }
    if error_message
      assert_match(Regexp.new(error_message), exception.output)
    end
  end

  def teardown
    stop
  end

end
