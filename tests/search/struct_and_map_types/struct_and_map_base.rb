# Copyright Vespa.ai. All rights reserved.
module StructAndMapBase

  def assert_same_element_summary_yql(yql, summary, summary_field, exp_summary_field)
    form = [["yql", yql],
            ["summary", summary ],
            ["format", "json" ],
            ["streaming.selection", "true"],
            ["hits", "10"]]
    assert_summary_field(form, summary_field, exp_summary_field)
  end

  def assert_same_element_summary(field, same_element, summary, summary_field, exp_summary_field)
    yql = "select * from sources * where #{field} contains sameElement(#{same_element})"
    assert_same_element_summary_yql(yql, summary, summary_field, exp_summary_field)
  end

  def assert_same_element_single_summary(field, same_element, summary, summary_field, exp_summary_field)
    form = [["yql", "select * from sources * where #{field}.#{same_element}"],
            ["summary", summary ],
            ["format", "json" ],
            ["streaming.selection", "true"],
            ["hits", "10"]]
    assert_summary_field(form, summary_field, exp_summary_field)
  end

  def assert_summary_field(form, summary_field, exp_summary_field)
    encoded_form = URI.encode_www_form(form)
    puts "form is #{encoded_form}"
    result = search("#{encoded_form}")
    puts "result is #{result.xmldata}"
    assert_equal(1, result.hitcount)
    hit = result.hit[0]
    act_summary_field = hit.field[summary_field]
    assert_equal(exp_summary_field, act_summary_field)
  end

end
