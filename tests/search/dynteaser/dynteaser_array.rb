# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class DynTeaserArrayTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_dynteaser_array
    set_description("Test dynamic teaser support on array of string fields")
    # Explicit use OpenNlpLinguistics to get the same results between public and internal system test runs.
    deploy_app(SearchApp.new.sd(selfdir + "dynteaser_array/test.sd").
               indexing_cluster("my-container").
               container(Container.new("my-container").
                         search(Searching.new).
                         docproc(DocumentProcessing.new).
                         component(Component.new("com.yahoo.language.opennlp.OpenNlpLinguistics"))))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "dynteaser_array/docs.json")

    run_test_case("\"schema\"", schema_teaser)
    run_test_case("\"syntax\"", syntax_teaser)
    if is_streaming
      run_test_case("({substring:true}\"chem\")", chem_substring_teaser)
    end
  end

  def schema_teaser
    is_streaming ?
      ["A <hi>schema</hi> defines a document type and what we want to compute over it. This is the<sep />particular meaning. This is the third sentence without any particular meaning. <hi>Schemas</hi> are stored in files named the same as the <hi>schema</hi>, with the ending sd, in<sep />",
       "This documents the syntax and content of <hi>schemas</hi>, document types and fields. This is the first sentence without any particular meaning. This is the second sentence without any<sep />"] :
      ["A <hi>schema</hi> defines a document type and what<sep />third sentence without any particular meaning. <hi>Schemas</hi> are stored in files<sep />",
       "This documents the syntax and content of <hi>schemas</hi>, document types and fields. This is the first sentence without any<sep />"]
  end

  def syntax_teaser
    is_streaming ?
      ["A schema defines a document type and what we want to compute over it. This is the first sentence without any particular meaning. This is the second sentence without any particular meaning. This is the third sentence without any particular meaning. Schemas<sep />",
       "This documents the <hi>syntax</hi> and content of schemas, document types and fields. This is the first sentence without any particular meaning. This is the second<sep />"] :
      ["A schema defines a document type and what we want to compute over it. This is the first sentence without any particular meaning. This is the second sentence without any particular meaning<sep />",
       "This documents the <hi>syntax</hi> and content of schemas, document types and fields. This<sep />"]
  end

  def chem_substring_teaser
    ["A s<hi>chem</hi>a defines a document type and what we want to compute over it. This is the<sep />particular meaning. This is the third sentence without any particular meaning. S<hi>chem</hi>as are stored in files named the same as the s<hi>chem</hi>a, with the ending sd<sep />",
     "This documents the syntax and content of s<hi>chem</hi>as, document types and fields. This is the first sentence without any<sep />third sentence without any particular meaning. This is a reference, see s<hi>chem</hi>as for an overview. Find an example at the end."]
  end

  def run_test_case(query_term, exp_teaser)
    assert_teaser_field("content_1", query_term, "content_1", "default", exp_teaser)
    assert_teaser_field("content_2", query_term, "content_2_dyn", "my_sum", exp_teaser)
  end

  def assert_teaser_field(query_field, query_term, summary_field, summary, exp_teaser)
    form = [["yql", "select * from sources * where #{query_field} contains #{query_term}"],
            ["summary", summary ],
            ["streaming.selection", "true"]]
    query = URI.encode_www_form(form)
    result = search(query)
    assert_hitcount(result, 1)
    act_teaser = result.hit[0].field[summary_field]
    assert_equal(exp_teaser, act_teaser, "Unexpected teaser for field '#{summary_field}' using query '#{query_field}:#{query_term}'")
  end

  def teardown
    stop
  end

end
