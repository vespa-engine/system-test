# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'streaming_search_test'
require 'search/fieldmatchfeatures/fieldmatchfeatures_base'


class FieldMatchFeaturesStreaming < StreamingSearchTest

  def add_streaming_selection_query_parameter
    true
  end

  include FieldMatchFeaturesBase

  def test_struct
    set_description("Test fieldMatch and fieldTermMatch features when using structs with both string and numeric fields")
    deploy_app(SearchApp.new.sd(selfdir + "fmstruct.sd").enable_document_api)
    start
    doc = Document.new("fmstruct", "id:fmstruct:fmstruct:n=1:0").
      add_field("f1", { "sf" => "foo bar baz", "lf" => 1000 }).
      add_field("f2", [ { "sf" => "foo bar baz", "lf" => 1000 },
                        { "sf" => "foo bar", "lf" => 2000 },
                        { "sf" => "baz foo", "lf" => 1000 } ])
    vespa.document_api_v1.put(doc)
    doc = Document.new("fmstruct", "id:fmstruct:fmstruct:n=1:1").
      add_field("f1", { "sf" => "foo foo", "lf" => 1000 }).
      add_field("f2", [ { "sf" => "foo bar baz qux", "lf" => 1000 },
                        { "sf" => "foo bar", "lf" => 2000 },
                        { "sf" => "baz foo", "lf" => 1000 },
                        { "sf" => "qux foo", "lf" => 3000 } ])
    vespa.document_api_v1.put(doc)
    wait_for_hitcount("query=sddocname:fmstruct", 2)

    assert_struct_streaming(1,     1, 1, "f1.lf:1000", "f1.lf", 0)
    assert_struct_streaming(1,     1, 1, "f1.lf:1000", "f1.lf", 1)
    assert_struct_streaming(1, 0.333, 1, "f1.sf:foo",  "f1.sf", 0)
    assert_struct_streaming(1,   0.5, 2, "f1.sf:foo",  "f1.sf", 1)
    assert_struct_streaming(1, 0.333, 2, "f2.lf:1000", "f2.lf", 0)
    assert_struct_streaming(1,  0.25, 2, "f2.lf:1000", "f2.lf", 1)
    assert_struct_streaming(1, 0.143, 3, "f2.sf:foo",  "f2.sf", 0)
    assert_struct_streaming(1,   0.1, 4, "f2.sf:foo",  "f2.sf", 1)
  end

end
