# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class StructAndMapGroupingTest < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
    set_description("Test that grouping works on struct and map fields")
  end

  def extract_group(result, group, fields_key_to_extract)
    value = group['value']
    if value && group.key?('fields')
      fields = group['fields']
      if fields.key?(fields_key_to_extract)
        result[group['value']] = fields[fields_key_to_extract]
      end
    end
    if group.key?('children')
      if value
        next_result = Hash.new
	result[value] = next_result
	result = next_result
      end
      grouplists = group['children']
      grouplists.each do | grouplist |
        extract_grouplist(result, grouplist, fields_key_to_extract)
      end
    end
  end

  def extract_grouplist(result, grouplist, fields_key_to_extract)
    grouplist['children'].each do |group|
      extract_group(result, group, fields_key_to_extract)
    end
  end

  def extract_groups_root(json, fields_key_to_extract)
    result = Hash.new
    if !json.nil? && json.kind_of?(Hash)
      if json.key?('root')
        root = json['root']
        if root.key?('children')
          root['children'].each do |group|
            extract_group(result, group, fields_key_to_extract)
          end
        end
      end
    end
    return result
  end

  def check_grouping(select, exp_groups, fields_key_to_extract = "count()")
    form = [["query", "sddocname:test"],
            ["select", select],
            ["hits", "0"],
            ["format", "tiled"],
            ["presentation.format", "json"]]
    encoded_form = URI.encode_www_form(form)
    result = search("/?#{encoded_form}")
    puts "result is #{result.xmldata}"
    json = result.json
    groups = extract_groups_root(json, fields_key_to_extract)
    puts "result groups are #{groups}"
    assert_equal(exp_groups, groups)
  end

  def create_app
    SearchApp.new.sd(selfdir + "grouping/test.sd").threads_per_search(1)
  end

  def test_struct_and_map_grouping
    deploy_app(create_app)
    start
    feed_and_wait_for_docs('test', 3, :file => selfdir + "grouping/docs.json")
    nan = if is_streaming then 0 else -2147483648 end
    check_grouping("all(group(int_single) each(output(count())))", {"10"=>2,"#{nan}"=>1})
    check_grouping("all(group(int_array) each(output(count())))", {"10"=>2,"20"=>1})
    check_grouping("all(group(elem_array.weight) each(output(count())))", {"10"=>2,"20"=>1})
    check_grouping("all(group(elem_map.key) each(output(count())))", {"@bar"=>1, "@foo"=>2})
    check_grouping("all(group(elem_map.value.weight) each(output(count())))", {"10"=>2, "20"=>1})
    check_grouping("all(group(elem_map{\"@foo\"}.weight) each(output(count())))", if is_streaming then {"10"=>2} else {"10"=>2,"#{nan}"=>1} end)
    check_grouping("all(group(str_int_map.key) each(output(count())))", {"@bar"=>2, "@foo"=>2})
    check_grouping("all(group(str_int_map.value) each(output(count())))", {"10"=>1, "20"=>2, "30"=>1})
    if is_streaming
        check_grouping("all(group(str_int_map{\"@foo\"}) each(output(count())))", {"10"=>1, "20"=>1})
        check_grouping("all(group(str_str_map{\"@foo\"}) each(output(count())))", {"@bar"=>1, ""=>1})
        check_grouping("all(group(str_int_map.key) each(output(sum(str_int_map.value))))", {"@bar"=>80, "@foo"=>80}, "sum(str_int_map.value)")
        check_grouping("all(group(str_int_map.key) each(group(str_int_map.value) each(output(sum(str_int_map.value)))))",
		       {"@bar"=>{"10"=>30, "20"=>80, "30"=>50},
	                "@foo"=>{"10"=>30, "20"=>80, "30"=>50}},
	               "sum(str_int_map.value)")
        check_grouping("all(group(str_int_map.key) each(group(strcat(str_int_map.key,str_int_map.value)) each(output(sum(str_int_map.value)))))",
		       {"@bar"=>{"@foo@bar1020"=>30, "@foo@bar2030"=>50},
	                "@foo"=>{"@foo@bar1020"=>30, "@foo@bar2030"=>50}},
	               "sum(str_int_map.value)")
    else
        check_grouping("all(group(str_int_map{\"@foo\"}) each(output(count())))", {"10"=>1, "20"=>1, "#{nan}"=>1})
        check_grouping("all(group(str_str_map{\"@foo\"}) each(output(count())))", {"@bar"=>1, ""=>2})
        check_grouping("all(group(str_int_map.key) each(output(sum(str_int_map.value))))", {"@bar"=>50, "@foo"=>30}, "sum(str_int_map.value)")
        check_grouping("all(group(str_int_map.key) each(group(str_int_map.value) each(output(sum(str_int_map.value)))))",
		       {"@bar"=>{"20"=>20, "30"=>30},
	                "@foo"=>{"10"=>10, "20"=>20}},
	               "sum(str_int_map.value)")
        check_grouping("all(group(str_int_map.key) each(group(strcat(str_int_map.key,str_int_map.value)) each(output(sum(str_int_map.value)))))",
		       {"@bar"=>{"@bar20"=>20, "@bar30"=>30},
	                "@foo"=>{"@foo10"=>10, "@foo20"=>20}},
	               "sum(str_int_map.value)")
    end
    check_grouping("all(group(\"my_group\") each(output(sum(str_int_map{\"@foo\"}))))", {"my_group"=>nan+30}, "sum(str_int_map{\"@foo\"})")
    unless is_streaming
      check_grouping("all(group(elem_map{attribute(key1)}.weight) each(output(count())))", {"10"=>2, "#{nan}"=>1})
      check_grouping("all(group(elem_map{attribute(key2)}.weight) each(output(count())))", {"20"=>1, "#{nan}"=>2})
      check_grouping("all(group(elem_map{attribute(key3)}.weight) each(output(count())))", {"#{nan}"=>3})
    end
  end

  def teardown
    stop
  end
end
