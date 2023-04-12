# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class StructAndMapGroupingTest < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
    set_description("Test that grouping works on struct and map fields")
  end

  def extract_groups(json, fields_key_to_extract)
    result = Hash.new
    if !json.nil? && json.kind_of?(Hash)
      if json.key?('root')
        root = json['root']
        if root.key?('children')
          root['children'].each do |e|
            if e.key?('children')
              e['children'].each do |grouplist|
                if grouplist.key?('children')
                  grouplist['children'].each do |group|
                    if group.key?('value') && group.key?('fields')
                      fields = group['fields']
                      if fields.key?(fields_key_to_extract)
                        result[group['value']] = fields[fields_key_to_extract]
                      end
                    end
                  end
                end
              end
            end
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
            ["presentation.format", "json"],
            ["streaming.selection", "true"]]
    encoded_form = URI.encode_www_form(form)
    result = search("/?#{encoded_form}")
    puts "result is #{result.xmldata}"
    json = result.json
    groups = extract_groups(json, fields_key_to_extract)
    puts "result groups are #{groups}"
    assert_equal(exp_groups, groups)
  end

  def create_app
    SearchApp.new.sd(selfdir + "grouping/test.sd")
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
    check_grouping("all(group(str_int_map{\"@foo\"}) each(output(count())))", if is_streaming then {"10"=>1, "20"=>1} else {"10"=>1, "20"=>1, "#{nan}"=>1} end)
    check_grouping("all(group(str_int_map.key) each(output(sum(str_int_map.value))))", {"@bar"=>80, "@foo"=>80}, "sum(str_int_map.value)")
    check_grouping("all(group(str_str_map{\"@foo\"}) each(output(count())))", if is_streaming then {"@bar"=>1, ""=>1} else {"@bar"=>1, ""=>2} end)
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
