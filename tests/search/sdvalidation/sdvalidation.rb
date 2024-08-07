# Copyright Vespa.ai. All rights reserved.
require 'search_test'

class SDValidation < SearchTest

  def setup
    set_owner("musum")
  end

  def test_sdvalidation    
    # Tests that file name in error message is relative to app package path
    deploy_invalid_sd(selfdir+"invalid_il_expression_name.sd", "invalid_il_expression_name.sd'")

    deploy_invalid_sd(selfdir+"invalid_fieldtype.sd")
    deploy_invalid_sd(selfdir+"invalid_fieldbody.sd")
    deploy_invalid_sd(selfdir+"reserved_fieldname.sd")
    deploy_invalid_sd(selfdir+"bold_nonword.sd")
    deploy_invalid_sd(selfdir+"dynteaser_nonword.sd")
    deploy_invalid_sd(selfdir+"position_conflict.sd")
    deploy_invalid_sd(selfdir+"attribute_properties.sd")
  end

  def test_rank_validation
    set_description("Tests that deploying fails when rank validation fails")
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
