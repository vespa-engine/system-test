# -*- coding: utf-8 -*-
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# encoding: utf-8
require 'indexed_only_search_test'

class NGram < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
  end

  def teardown
    stop
  end

  def test_ngram
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => "#{selfdir}/documents.json")

    # Whole word which is in both title and body
    assert_hitcount('query=title:java&type=all', 2)
    assert_hitcount('query=body:java&type=all', 2)
    assert_hitcount('query=default:java&type=all', 2)
    assert_hitcount('query=java&type=all', 2)

    # Whole word in title only
    assert_hitcount('query=title:on&type=all', 2)
    assert_hitcount('query=body:on&type=all', 0)
    assert_hitcount('query=default:on&type=all', 2)
    assert_hitcount('query=on&type=all', 2)

    # Whole word in body only
    assert_hitcount('query=title:scene&type=all', 0)
    assert_hitcount('query=body:scene&type=all', 2)
    assert_hitcount('query=default:scene&type=all', 2)
    assert_hitcount('query=scene&type=all', 2)

    # Substring in body
    assert_hitcount('query=title:opul&type=all', 0)
    assert_hitcount('query=body:opul&type=all', 2)
    assert_hitcount('query=default:opul&type=all', 2)
    assert_hitcount('query=opul&type=all', 2)

    # Substring	across word boundaries in body only
    assert_hitcount('query=title:enefr&type=all', 0)
    assert_hitcount('query=body:enefr&type=all', 1)
    assert_hitcount('query=default:enefr&type=all', 1)
    assert_hitcount('query=enefr&type=all', 1)

    # No lowercasing is done on the input data, so words containing uppercase
    # letters will not match. This is not a problem since ngrams will only be
    # used by CJK languages, where there is no upper/lowercase.
    assert_hitcount('query=title:logging&type=all', 2)
    assert_hitcount('query=body:logging&type=all', 2)
    assert_hitcount('query=default:logging&type=all', 2)
    assert_hitcount('query=logging&type=all', 2)

    # Matching both header and body
    assert_hitcount('query=default:java title:oggingin body:enefr&type=all', 1)

    # Check result fields
    result = search('query=title:abo')
    assert_equal('on/about #Logging in #Java', result.hit[0].field['title'])
    result = search('query=body:opul')
    assert_equal("#Logging in #Java is like that \"Judean P<hi>opul</hi>ar Front\" scene from \"Life of Brian\".",
                 result.hit[0].field['body'])
    result = search('query=large:do')
    assert_equal("<sep />I am not saying that you should never use \"else\" in your code, but when you <hi>do</hi>, you should stop and think about what you are doing, because most of<sep />",
                 result.hit[0].field['large'])

    # CJK
    assert_hitcount_with_timeout(10, "?query=body:古牧区&language=zh-Hans&type=all", 1)
    result = search("?query=body:牧区雪灾救援&language=zh-Hans&type=all")
    assert_equal("\n内蒙古<hi>牧区雪灾救援</hi>困\n  ", result.hit[0].field['body'])
  end

  def test_ngram_external_field
    set_description("Test that using ngram on an external field does not affect the input field")
    deploy_app(SearchApp.new.sd(selfdir + "external.sd"))
    start
    feed_and_wait_for_docs("external", 1, :file => selfdir + "external_doc.json")

    assert_hitcount('query=gram_album:eam&type=all', 1)
    assert_hitcount('query=gram_album:dreams&type=all', 1)
    assert_hitcount('query=album:eam&type=all', 0)
    assert_hitcount('query=album:dreams&type=all', 1)
  end

end
