# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class CharEncoding < IndexedSearchTest

  def setup
    set_owner('bratseth')
    set_description("Text character encoding, for data that does not 'normalize' accents")
    deploy_app(SearchApp.new.sd(selfdir+'music.sd'))
    start
  end

  def check_q(query, filename)
    query = query + "&hits=100"
    assert_result(query , selfdir + filename, 'surl', [ 'surl' ])
  end

  def test_char_encoding
    feed_and_wait_for_docs('music', 10000, :file => SEARCH_DATA+'music.10000.json')

    common()
    if is_streaming
      streaming()
    else
      indexed()
    end

  end
  def common
    puts "Query: Searching for 'walküre'"
    check_q('query=walk%c3%bcre', 'walkure_u_umlaut.result.json')

    puts "Query: Searching for 'WALKÜRE'"
    check_q('query=WALK%C3%9CRE', 'walkure_u_umlaut.result.json')


  end

  def indexed
    puts "Query: Searching for 'walkuere'"
    assert_hitcount('query=walkuere', 0)

    puts "Query: Searching for 'espana'"
    check_q('query=espana', 'espana_n.result.json')

    puts "Query: Searching for 'españa'"
    check_q('query=espa%c3%b1a', 'espana_n_tilde.result.json')

    puts "Query: Searching for 'ESPAÑA'"
    check_q('query=ESPA%C3%91A', 'espana_n_tilde.result.json')

    puts "Query: Searching for 'francois'"
    check_q('query=francois', 'francois_c.result.json')

    puts "Query: Searching for 'françois'"
    check_q('query=fran%c3%a7ois', 'francois_c_cedilla.result.json')

    puts "Query: Searching for 'FRANÇOIS'"
    check_q('query=FRAN%C3%87OIS', 'francois_c_cedilla.result.json')

  end

  def streaming
    puts "Query: Searching for 'walkuere'"
    assert_hitcount('query=walkuere', 3)

    puts "Query: Searching for 'espana'"
    check_q('query=espana', 'espana_n.streaming.result.json')

    puts "Query: Searching for 'españa'"
    check_q('query=espa%c3%b1a', 'espana_n.streaming.result.json')

    puts "Query: Searching for 'ESPAÑA'"
    check_q('query=ESPA%C3%91A', 'espana_n.streaming.result.json')

    puts "Query: Searching for 'francois'"
    check_q('query=francois', 'francois_c.streaming.result.json')

    puts "Query: Searching for 'françois'"
    check_q('query=fran%c3%a7ois', 'francois_c.streaming.result.json')

    puts "Query: Searching for 'FRANÇOIS'"
    check_q('query=FRAN%C3%87OIS', 'francois_c.streaming.result.json')

  end


  def teardown
    stop
  end

end
