# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'
require 'search/fieldmatchfeatures/fieldmatchfeatures_base'


class FieldMatchFeatures < IndexedStreamingSearchTest

  include FieldMatchFeaturesBase

  def test_field_match
    set_description("Test the fieldMatch feature")
    deploy_app(SearchApp.new.sd(selfdir + "fieldmatch.sd").enable_document_api)
    start
    feed_and_wait_for_docs("fieldmatch", 23, :file => selfdir + "fieldmatch.xml")
    run_field_match
  end

  def test_field_term_match
    set_description("Test the fieldTermMatch feature")
    deploy_app(SearchApp.new.sd(selfdir + "fieldtermmatch.sd").enable_document_api)
    start
    feed_and_wait_for_docs("fieldtermmatch", 1, :file => selfdir + "fieldtermmatch.xml")

    run_field_term_match

    if !is_streaming
      # test the filter index (b) (does not apply to streaming)
      assert_field_term_match(0, 1000000, 1, "b:a", "b") # we do not have position information -> 1 occ (actual 3)
      assert_field_term_match(1, 1000000, 0, "b:a", "b")
      assert_field_term_match(0, 1000000, 1, "b:a+a", "b")
      assert_field_term_match(1, 1000000, 0, "b:a+a", "b")
      assert_field_term_match(0, 1000000, 0, "b:a+a", "a")
      assert_field_term_match(1, 0,       3, "b:a+a", "a")
    end
  end

  def test_phrase
    set_description("Test fieldMatch feature when using phrase search")
    deploy_app(SearchApp.new.sd(selfdir + "fmphrase.sd").enable_document_api)
    start
    feed_and_wait_for_docs("fmphrase", 1, :file => selfdir + "fmphrase.xml")
    run_phrase_test
  end

end
