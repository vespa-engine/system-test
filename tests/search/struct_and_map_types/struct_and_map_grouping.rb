# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class StructAndMapGroupingTest < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
    set_description("Test that grouping works on struct and map fields")
  end

  def extract_groups(json)
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
                      if fields.key?('count()')
                        result[group['value']] = fields['count()']
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

  def check_grouping(select, exp_groups)
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
    groups = extract_groups(json)
    puts "result groups are #{groups}"
    assert_equal(exp_groups, groups)
  end

  def create_app
    SearchApp.new.sd(selfdir + "grouping/test.sd")
  end

  def test_struct_and_map_grouping
    deploy_app(create_app)
    start
    feed_and_wait_for_docs('test', 1, :file => selfdir + "grouping/docs.json", :json => true)
    check_grouping("all(group(int_single) each(output(count())))", {"10"=>1})
    check_grouping("all(group(int_array) each(output(count())))", {"10"=>1,"20"=>1})
    check_grouping("all(group(elem_array.weight) each(output(count())))", {"10"=>1,"20"=>1})
    check_grouping("all(group(elem_map.key) each(output(count())))", {"@bar"=>1, "@foo"=>1})
    check_grouping("all(group(elem_map.value.weight) each(output(count())))", {"10"=>1, "20"=>1})
    check_grouping("all(group(elem_map{\"@foo\"}.weight) each(output(count())))", {"10"=>1})
    unless is_streaming
      check_grouping("all(group(elem_map{attribute(key1)}.weight) each(output(count())))", {"10"=>1})
      check_grouping("all(group(elem_map{attribute(key2)}.weight) each(output(count())))", {"20"=>1})
      check_grouping("all(group(elem_map{attribute(key3)}.weight) each(output(count())))", {"-2147483648"=>1})
    end
  end

  def teardown
    stop
  end
end
